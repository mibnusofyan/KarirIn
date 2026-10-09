import '../data/mock_data.dart';
import '../data/models.dart';

/// Rubric result for one answer: four aspects, 0–25 each (proposal 2.2.1, AI Interview Coach).
class AnswerScore {
  const AnswerScore({
    required this.relevansi,
    required this.struktur,
    required this.kejelasan,
    required this.bukti,
    required this.good,
    required this.improve,
  });

  final int relevansi, struktur, kejelasan, bukti;
  final String good;
  final String improve;

  int get total => relevansi + struktur + kejelasan + bukti;

  List<(String, int)> get aspects => [
    ('Relevansi', relevansi),
    ('Struktur STAR', struktur),
    ('Kejelasan', kejelasan),
    ('Bukti konkret', bukti),
  ];
}

class AnsweredQuestion {
  const AnsweredQuestion(this.question, this.score);
  final InterviewQuestion question;
  final AnswerScore score;
}

const _improve = {
  'Relevansi': 'Fokuskan jawaban langsung pada pertanyaan yang diajukan.',
  'Struktur STAR': 'Susun jawaban dengan pola STAR: jelaskan situasi, tugasmu, aksi yang kamu ambil, lalu hasilnya.',
  'Kejelasan': 'Gunakan kalimat yang lebih lengkap agar pewawancara mudah mengikuti alurnya.',
  'Bukti konkret': 'Tambahkan bukti konkret seperti angka, jumlah, atau hasil yang terukur.',
};
const _good = {
  'Relevansi': 'Jawabanmu menjawab inti pertanyaan.',
  'Struktur STAR': 'Alur ceritamu runtut dari situasi ke hasil.',
  'Kejelasan': 'Bahasamu jelas dan mudah dipahami.',
  'Bukti konkret': 'Kamu menyertakan angka yang membuat jawaban meyakinkan.',
};

const focusByAspect = {
  'Relevansi': 'Fokus berikutnya: jawab inti pertanyaan di kalimat pertama.',
  'Struktur STAR': 'Fokus berikutnya: susun cerita dengan pola Situasi, Tugas, Aksi, Hasil.',
  'Kejelasan': 'Fokus berikutnya: gunakan kalimat yang lebih lengkap dan runtut.',
  'Bukti konkret': 'Fokus berikutnya: sertakan angka atau hasil terukur di setiap cerita.',
};

/// Offline heuristic grader used by the prototype. In production this is the
/// Gemini-backed `gradeAnswer` Cloud Function returning the same JSON shape.
AnswerScore gradeAnswer(String answer) {
  final t = answer.toLowerCase();
  final w = t.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  const starWords = ['saat', 'ketika', 'waktu', 'diminta', 'tugas', 'tanggung jawab', 'saya ', 'hasil', 'sehingga', 'akhirnya', 'setelah'];
  final star = starWords.where(t.contains).length;
  final hasNumber = RegExp(r'\d').hasMatch(t);

  final rel = (10 + (w < 60 ? w : 60) / 4).round().clamp(0, 25);
  final str = (6 + star * 3).clamp(0, 25);
  final jel = (w < 8 ? 10 : 15 + ((w / 12).round() < 8 ? (w / 12).round() : 8)).clamp(0, 25);
  final buk = hasNumber ? (18 + (w > 50 ? 5 : 2)).clamp(0, 25) : (w > 30 ? 13 : 8);

  final asp = [('Relevansi', rel), ('Struktur STAR', str), ('Kejelasan', jel), ('Bukti konkret', buk)];
  final lo = ([...asp]..sort((a, b) => a.$2.compareTo(b.$2))).first.$1;
  final hi = ([...asp]..sort((a, b) => b.$2.compareTo(a.$2))).first.$1;
  return AnswerScore(relevansi: rel, struktur: str, kejelasan: jel, bukti: buk, good: _good[hi]!, improve: _improve[lo]!);
}

/// Five questions built from the job description: 3 behavioural + 2 technical.
List<InterviewQuestion> questionsFor(Job job) {
  if (job.id == 'j1') return interviewJ1;
  InterviewQuestion tech(String s) => InterviewQuestion(
    type: 'Teknis',
    text: 'Bagaimana kamu menerapkan $s dalam pekerjaan sebagai ${job.title}?',
    demo: 'Saya menggunakan $s saat magang untuk membantu pekerjaan harian tim.',
    better:
        'Saat magang, saya menggunakan $s untuk menyelesaikan tugas rutin tim. Saya menyusun langkah kerja yang jelas dan memeriksa hasilnya dua kali. Hasilnya, waktu pengerjaan turun dari 2 jam menjadi 1 jam dan kesalahan input berkurang.',
  );
  return [
    interviewJ1[0].withText(
      'Ceritakan pengalaman saat kamu harus menyelesaikan banyak tugas dengan tenggat yang berdekatan. Bagaimana kamu mengaturnya?',
    ),
    interviewJ1[1].withText('Ceritakan saat kamu menemukan kesalahan dalam pekerjaan. Apa yang kamu lakukan untuk memperbaikinya?'),
    interviewJ1[2],
    tech(job.wajib.first),
    tech(job.wajib.last),
  ];
}

/// Average of each aspect across answered questions.
AnswerScore averageScore(List<AnsweredQuestion> items) {
  int avg(int Function(AnswerScore) f) => (items.fold(0, (a, r) => a + f(r.score)) / items.length).round();
  final s = AnswerScore(
    relevansi: avg((s) => s.relevansi),
    struktur: avg((s) => s.struktur),
    kejelasan: avg((s) => s.kejelasan),
    bukti: avg((s) => s.bukti),
    good: '',
    improve: '',
  );
  return s;
}
