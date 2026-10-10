// AI output validation, prompts and fallbacks, with recorded-style Gemini responses (no network).
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/data/backend.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/data/repositories/auth_repository.dart';
import 'package:karirin/data/repositories/interview_repository.dart';
import 'package:karirin/data/repositories/profile_repository.dart';
import 'package:karirin/data/repositories/providers.dart';
import 'package:karirin/data/repositories/user_repository.dart';
import 'package:karirin/logic/cover_letter.dart';
import 'package:karirin/logic/interview.dart';
import 'package:karirin/logic/match_score.dart';
import 'package:karirin/services/ai/ai_parsing.dart';
import 'package:karirin/services/ai/ai_service.dart';
import 'package:karirin/services/ai/prompts.dart';
import 'package:karirin/services/cv_storage.dart';
import 'package:karirin/state/app_state.dart';
import 'package:karirin/state/session.dart';

/// A response shaped like what Gemini returns for Rani's CV, with the usual imperfections.
const _raniJson = '''
```json
{
  "name": "  Rani   Lestari ",
  "level": "s1",
  "major": "Manajemen",
  "school": "Universitas Banyumas Raya",
  "city": "Purwokerto",
  "skills": ["MS Excel", "Akuntansi Dasar", "pembukuan", "excel", "Komunikasi", ""],
  "exps": [
    {"title": "Magang Staf Keuangan", "org": "KSP Sejahtera Bersama", "type": "magang", "months": 6, "field": "keuangan", "desc": "membantu pencatatan transaksi harian"},
    {"title": "Bendahara HIMA", "org": "", "type": "relawan", "months": 9999, "field": "olahraga", "desc": ""},
    {"title": "", "org": "Tanpa judul", "type": "kerja", "months": 3}
  ]
}
```''';

class _FailingAi implements AiService {
  const _FailingAi();

  @override
  Future<Profile> extractProfile(CvFile cv, {required List<Skill> catalog}) async => throw AiFailure.quota;

  @override
  Future<AnswerScore> gradeAnswer({required Job job, required InterviewQuestion question, required String answer}) async =>
      throw AiFailure.network;

  @override
  Future<GeneratedLetter> generateLetter({required Job job, required Profile profile, required LetterTone tone, required int variant}) async =>
      throw AiFailure.invalid;
}

class _FakeAi extends OfflineAiService {
  _FakeAi(this.profile);
  final Profile profile;
  int calls = 0;

  @override
  Future<Profile> extractProfile(CvFile cv, {required List<Skill> catalog}) async {
    calls++;
    return profile;
  }
}

class _MemoryCv extends CvStorage {
  List<int>? saved;
  bool deleted = false;

  @override
  Future<void> save(List<int> bytes, String extension) async => saved = bytes;

  @override
  Future<void> delete() async => deleted = true;
}

void main() {
  group('validasi keluaran AI', () {
    test('profil dari CV: pagar kode, normalisasi, duplikat, enum dan rentang tidak valid', () {
      final p = parseExtractedProfile(decodeJsonObject(_raniJson), catalog: skillCatalog, source: ProfileSource.cvPdf);
      expect(p.name, 'Rani Lestari');
      expect(p.level, EduLevel.s1);
      expect(p.skills, ['Microsoft Excel', 'Akuntansi Dasar', 'Pembukuan', 'Komunikasi']);
      expect(p.exps, hasLength(2), reason: 'pengalaman tanpa judul dibuang');
      expect(p.exps[1].type, ExperienceType.kerja);
      expect(p.exps[1].months, 600);
      expect(p.exps[1].field, 'umum');
      expect(p.exps[1].org, '-');
      expect(p.modes, [WorkMode.kantor]);
      // Rani's extracted profile scores like the curated one on j1 (proposal Tabel 2.4: 80).
      expect(computeMatch(jobs.first, p).total, 80);
    });

    test('CV kosong atau bukan JSON ditolak dengan pesan yang jelas', () {
      expect(() => parseExtractedProfile({'name': '', 'skills': []}, catalog: skillCatalog, source: ProfileSource.cvPdf), throwsA(AiFailure.unreadable));
      expect(() => decodeJsonObject('Maaf, saya tidak bisa membaca berkas ini.'), throwsA(AiFailure.invalid));
      expect(() => decodeJsonObject('[1, 2]'), throwsA(AiFailure.invalid));
      expect(() => decodeJsonObject(null), throwsA(AiFailure.invalid));
    });

    test('nilai rubrik dibatasi 0–25; umpan balik kosong memakai kalimat rubrik', () {
      final s = parseGrade({'relevansi': 30, 'struktur': -4, 'kejelasan': '18', 'bukti': 12.6, 'good': '', 'improve': '  ', 'better': 'pendek'});
      expect([s.relevansi, s.struktur, s.kejelasan, s.bukti], [25, 0, 18, 13]);
      expect(s.good, strengthByAspect['Relevansi']);
      expect(s.improve, focusByAspect['Struktur STAR']);
      expect(s.better, isNull, reason: 'contoh terlalu pendek diganti contoh bawaan pertanyaan');
      expect(s.offline, isFalse);
    });

    test('surat ditolak bila terlalu pendek atau salah perusahaan', () {
      final job = jobs.first;
      final good = coverLetter(job, raniProfile, LetterTone.formal, 0);
      expect(parseLetter({'surat': good}, job: job), good);
      expect(() => parseLetter({'surat': 'Halo'}, job: job), throwsA(AiFailure.invalid));
      expect(() => parseLetter({'surat': good.replaceAll(job.company, 'PT Lain')}, job: job), throwsA(AiFailure.invalid));
    });
  });

  group('prompt', () {
    test('ekstraksi memuat daftar skill baku dan bidang yang diizinkan', () {
      final p = extractProfilePrompt(skillCatalog);
      expect(p, contains('Microsoft Excel'));
      expect(p, contains(jobFields.join(', ')));
    });

    test('penilaian memuat lowongan, pertanyaan, jawaban, rubrik, dan larangan diskriminatif', () {
      final p = gradeAnswerPrompt(job: jobs.first, question: 'Ceritakan…', questionType: 'Perilaku', answer: 'Saya menyusun rekap kas.');
      expect(p, allOf(contains(jobs.first.title), contains('Ceritakan…'), contains('Saya menyusun rekap kas.'), contains('STAR'), contains('agama')));
    });

    test('surat formal memakai tanggal hari itu dan hanya fakta profil', () {
      final p = generateLetterPrompt(job: jobs.first, profile: raniProfile, tone: LetterTone.formal, variant: 2, today: DateTime(2026, 10, 10));
      expect(p, allOf(contains('Purwokerto, 10 Oktober 2026'), contains('KSP Sejahtera Bersama'), contains('jangan mengarang'), contains('Variasi ke-2')));
      expect(formatDateId(DateTime(2026, 1, 5)), '5 Januari 2026');
    });
  });

  group('cadangan saat AI gagal', () {
    final job = jobs.first;
    const ai = ResilientAiService(_FailingAi());

    test('penilaian jatuh ke heuristik dan diberi label offline', () async {
      final s = await ai.gradeAnswer(job: job, question: interviewJ1.first, answer: interviewJ1.first.demo);
      expect(s.offline, isTrue);
      expect(s.total, gradeAnswer(interviewJ1.first.demo).total);
      expect(s.toMap()['gradedBy'], 'offline');
    });

    test('surat jatuh ke templat dan diberi label offline', () async {
      final l = await ai.generateLetter(job: job, profile: raniProfile, tone: LetterTone.ringkas, variant: 1);
      expect(l.offline, isTrue);
      expect(l.text, coverLetter(job, raniProfile, LetterTone.ringkas, 1));
    });

    test('ekstraksi CV tidak berpura-pura berhasil', () async {
      final cv = CvFile(bytes: Uint8List(4), mimeType: 'application/pdf', source: ProfileSource.cvPdf);
      await expectLater(ai.extractProfile(cv, catalog: skillCatalog), throwsA(AiFailure.quota));
    });
  });

  group('alur Firebase dengan AI palsu', () {
    late ProviderContainer c;
    late _FakeAi ai;
    late _MemoryCv cvs;
    late MockInterviewRepository interviews;
    final auth = MockAuthRepository();

    setUp(() async {
      session.value = SessionStatus.loading;
      ai = _FakeAi(raniProfile.copyWith(name: '', source: ProfileSource.cvPhoto));
      cvs = _MemoryCv();
      interviews = MockInterviewRepository();
      c = ProviderContainer(
        overrides: [
          backendProvider.overrideWithValue(Backend.firebase),
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(MockUserRepository()),
          profileRepositoryProvider.overrideWithValue(MockProfileRepository()),
          interviewRepositoryProvider.overrideWithValue(interviews),
          aiServiceProvider.overrideWithValue(ai),
          cvStorageProvider.overrideWithValue(cvs),
        ],
      );
      c.read(appProvider);
      await pumpEventQueue();
      c.read(appProvider.notifier).setSignupName('Rani L');
      await auth.register(name: 'Rani L', email: 'rani@contoh.id', password: 'rahasia123');
      await pumpEventQueue();
    });

    tearDown(() => c.dispose());

    test('CV terbaca: profil dari AI, nama kosong diisi nama daftar, berkas disalin ke perangkat', () async {
      final n = c.read(appProvider.notifier);
      final bytes = Uint8List.fromList([1, 2, 3]);
      n.setPendingCv(CvFile(bytes: bytes, mimeType: 'image/jpeg', source: ProfileSource.cvPhoto));
      expect(n.hasPendingCv, isTrue);
      await n.extractPendingCv();
      await pumpEventQueue();
      final st = c.read(appProvider);
      expect(st.profile.name, 'Rani L');
      expect(st.profile.source, ProfileSource.cvPhoto);
      expect(st.hasCv, isTrue);
      expect(cvs.saved, bytes);
      expect(n.hasPendingCv, isFalse);
    });

    test('tanpa CV yang dipilih, ekstraksi gagal dengan pesan', () async {
      await expectLater(c.read(appProvider.notifier).extractPendingCv(), throwsA(isA<AiFailure>()));
      expect(ai.calls, 0);
    });

    test('sesi selesai tersimpan; hapus berkas CV menghapus salinan di perangkat', () async {
      final n = c.read(appProvider.notifier);
      final results = [for (final q in interviewJ1) AnsweredQuestion(q, gradeAnswer(q.demo), answer: q.demo)];
      n.saveInterviewResults(results);
      n.deleteCv();
      await pumpEventQueue();
      expect(interviews.sessions.values.single.single, hasLength(5));
      expect(results.first.toMap()['answer'], interviewJ1.first.demo);
      expect(cvs.deleted, isTrue);
    });
  });

  test('pertanyaan dari Firestore dibaca utuh dan jenisnya dibatasi', () {
    final q = InterviewQuestion.fromMap({'type': 'Aneh', 'text': 'Ceritakan tentang dirimu.', 'better': 'Saya…'});
    expect(q.type, 'Perilaku');
    expect(q.demo, '');
    expect(InterviewQuestion.fromMap(interviewJ1[3].toMap()).toMap(), interviewJ1[3].toMap());
  });
}
