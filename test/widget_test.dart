import 'package:flutter_test/flutter_test.dart';
import 'package:karirin/data/mock_data.dart';
import 'package:karirin/data/models.dart';
import 'package:karirin/logic/interview.dart';
import 'package:karirin/logic/match_score.dart';

void main() {
  group('Match Score (Persamaan 1)', () {
    test('Rani vs Staf Administrasi Keuangan = 80 (Tabel 2.4)', () {
      final r = computeMatch(jobById('j1'), raniProfile);
      expect(r.sw, 0.75);
      expect(r.st, 0.5);
      expect(r.sp, 1);
      expect(r.se, 1);
      expect(r.sl, 1);
      expect(r.total, closeTo(80, 1e-9));
      expect(r.category, MatchCategory.high);
      expect(r.missingWajib, ['Pelaporan Keuangan']);
    });

    test('mastering Pelaporan Keuangan raises the score to 92,5', () {
      final p = raniProfile.copyWith(skills: [...raniProfile.skills, 'Pelaporan Keuangan']);
      expect(fmt(computeMatch(jobById('j1'), p).total), '92,5');
    });

    test('experience counts internships and organisations at half weight', () {
      // j3 asks 1 year in "data"; Rani has no data experience.
      expect(computeMatch(jobById('j3'), raniProfile).se, 0);
      // j5 asks 1 year in "keuangan": 6/2 + 12/2 = 9 of 12 months.
      final r = computeMatch(jobById('j5'), raniProfile);
      expect(r.relevantMonths, 9);
      expect(r.se, 0.75);
    });

    test('ranking is sorted by score, highest first', () {
      final ranked = rankJobs(jobs, raniProfile);
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].result.total >= ranked[i].result.total, isTrue);
      }
    });

    test('skill gap is ordered by score impact', () {
      final job = jobById('j1');
      final gap = skillGap(job, computeMatch(job, raniProfile));
      expect(gap.map((g) => g.skill), ['Pelaporan Keuangan', 'Software Akuntansi']);
      expect(gap.first.gain, 12.5);
      expect(gap.last.gain, 7.5);
    });
  });

  test('skill names are normalised', () {
    expect(normalizeSkill(' ms excel '), 'Microsoft Excel');
    expect(normalizeSkill('Word'), 'Microsoft Word');
    expect(normalizeSkill('SQL'), 'SQL');
  });

  test('categories follow the 75 / 50 thresholds', () {
    expect(MatchCategory.of(75), MatchCategory.high);
    expect(MatchCategory.of(74.9), MatchCategory.mid);
    expect(MatchCategory.of(50), MatchCategory.mid);
    expect(MatchCategory.of(49.9), MatchCategory.low);
  });

  test('interview rubric keeps every aspect within 0–25', () {
    for (final q in interviewJ1) {
      final s = gradeAnswer(q.better);
      for (final (_, v) in s.aspects) {
        expect(v, inInclusiveRange(0, 25));
      }
      expect(s.total, s.relevansi + s.struktur + s.kejelasan + s.bukti);
    }
    // A concrete STAR answer with numbers scores higher than a vague one.
    expect(gradeAnswer(interviewJ1[1].better).total, greaterThan(gradeAnswer('Saya bekerja keras.').total));
  });

  test('five questions per session: 3 behavioural + 2 technical', () {
    for (final j in jobs) {
      final qs = questionsFor(j);
      expect(qs.length, 5);
      expect(qs.where((q) => q.type == 'Perilaku').length, 3);
      expect(qs.where((q) => q.type == 'Teknis').length, 2);
    }
  });

  test('EduLevel parses labels', () {
    expect(EduLevel.fromLabel('D3'), EduLevel.d3);
  });
}
