import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/data/catalog_extra.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/data/repositories/application_repository.dart';
import 'package:karirin/data/repositories/job_repository.dart';
import 'package:karirin/data/repositories/profile_repository.dart';
import 'package:karirin/logic/match_score.dart';

void main() {
  group('serialisasi Firestore', () {
    test('lowongan kembali utuh dan skornya sama', () {
      for (final j in jobs) {
        final back = Job.fromMap(j.id, j.toMap());
        expect(back.toMap(), j.toMap());
        expect(computeMatch(back, raniProfile).total, computeMatch(j, raniProfile).total);
      }
      // Proposal Tabel 2.4 survives the round trip.
      expect(computeMatch(Job.fromMap('j1', jobs.first.toMap()), raniProfile).total, 80);
    });

    test('profil kembali utuh, termasuk pengalaman', () {
      final back = Profile.fromMap(raniProfile.toMap());
      expect(back.toMap(), raniProfile.toMap());
      expect(back.exps.first.type, ExperienceType.magang);
    });

    test('nilai enum yang tidak dikenal memakai cadangan, bukan crash', () {
      final m = {...jobs.first.toMap(), 'mode': 'luar-angkasa', 'eduMin': null};
      final j = Job.fromMap('x', m);
      expect(j.mode, WorkMode.kantor);
      expect(j.eduMin, EduLevel.smaSmk);
    });

    test('katalog skill memuat semua skill lowongan dan sinonim Excel', () {
      final names = {for (final s in skillCatalog) s.name};
      for (final j in jobs) {
        expect(names.containsAll([...j.wajib, ...j.tambahan]), isTrue, reason: j.id);
      }
      final excel = skillCatalog.firstWhere((s) => s.name == 'Microsoft Excel');
      expect(excel.id, 'microsoft-excel');
      expect(excel.synonyms, contains('MS Excel'));
      expect(Skill.fromMap(excel.toMap()).resource?.title, resources['Microsoft Excel']!.title);
    });
  });

  test('katalog tambahan: id unik, skill tercatat, ada lowongan TKJ untuk Bayu', () {
    final all = [...jobs, ...extraJobs];
    expect({for (final j in all) j.id}, hasLength(all.length));
    final names = {for (final s in buildSkillCatalog(all, {...resources, ...extraResources})) s.name};
    for (final j in extraJobs) {
      expect(names.containsAll([...j.wajib, ...j.tambahan]), isTrue, reason: j.id);
      expect(j.wajib, isNotEmpty);
      expect(j.tambahan, isNotEmpty, reason: 'St dibagi jumlah skill tambahan');
      expect(Job.fromMap(j.id, j.toMap()).toMap(), j.toMap());
    }
    expect(extraJobs.where((j) => j.eduFields.contains('Teknik Komputer dan Jaringan') || j.wajib.contains('Perakitan PC')), isNotEmpty);
  });

  group('repository mock', () {
    test('lowongan dan skill tersedia', () async {
      const repo = MockJobRepository();
      expect(await repo.fetchJobs(), hasLength(jobs.length));
      expect(await repo.fetchSkills(), isNotEmpty);
    });

    test('profil: null sampai disimpan, terpisah per pengguna, dapat dihapus', () async {
      final repo = MockProfileRepository();
      expect(await repo.fetch('u1'), isNull);
      await repo.save('u1', raniProfile, learned: ['Pelaporan Keuangan']);
      await repo.save('u2', raniProfile.copyWith(name: 'Orang Lain'));
      final stored = await repo.fetch('u1');
      expect(stored?.profile.name, 'Rani Lestari');
      expect(stored?.learned, ['Pelaporan Keuangan']);
      await repo.delete('u1');
      expect(await repo.fetch('u1'), isNull);
      expect((await repo.fetch('u2'))?.profile.name, 'Orang Lain');
    });

    test('lamaran: tambah di atas, ubah, hapus', () async {
      final repo = MockApplicationRepository({'u1': initialApplications});
      final a = initialApplications.first;
      await repo.upsert(
        'u1',
        const JobApplication(id: 'baru', title: 'Admin Gudang', company: 'CV Berkah Logistik', status: AppStage.dikirim, date: '9 Okt'),
      );
      await repo.upsert('u1', a.copyWith(status: AppStage.diterima));
      await repo.delete('u1', 'a4');
      final list = await repo.watch('u1').first;
      expect(list.first.id, 'baru');
      expect(list.firstWhere((x) => x.id == a.id).status, AppStage.diterima);
      expect(list.any((x) => x.id == 'a4'), isFalse);
      expect(await repo.watch('u2').first, isEmpty);
    });
  });
}
