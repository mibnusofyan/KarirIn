// Prompts for each AI task (proposal 3.1.3): one prompt per task, JSON output only, low temperature for
// extraction and grading. Kept free of Firebase types so they can be read and tested on their own.
import '../../data/models.dart';
import '../../logic/cover_letter.dart';
import '../../logic/match_score.dart';
import 'ai_parsing.dart';

String extractProfilePrompt(List<Skill> catalog) =>
    '''
Kamu membaca CV seorang pencari kerja di Indonesia dan mengubahnya menjadi data terstruktur.

Aturan:
- Ambil hanya informasi yang tertulis di CV. Jangan menebak atau menambah data. Isi string kosong bila tidak ada.
- name: nama lengkap pemilik CV.
- level: pendidikan tertinggi. "smaSmk" untuk SMA/SMK/MA/sederajat, "d3" untuk D1–D4 atau diploma, "s1" untuk S1 ke atas.
- major: jurusan atau program studi pendidikan tertinggi. school: nama sekolah/kampusnya.
- city: kota domisili bila tertulis.
- skills: keterampilan kerja (hard skill dan soft skill) yang tertulis. Bila sama maknanya dengan salah satu nama baku berikut, tulis persis nama bakunya: ${catalog.map((s) => s.name).join(', ')}.
- exps: pengalaman kerja, magang/PKL, dan organisasi. type "kerja" untuk pekerjaan (termasuk paruh waktu), "magang" untuk magang/PKL, "organisasi" untuk organisasi/kepanitiaan. months: lama dalam bulan (perkirakan dari rentang tanggal; 0 bila tidak diketahui). field: salah satu dari ${jobFields.join(', ')}. desc: satu kalimat aktivitas utama dalam huruf kecil tanpa titik di akhir, diawali kata kerja (contoh: "membantu pencatatan transaksi harian").
''';

String gradeAnswerPrompt({required Job job, required String question, required String questionType, required String answer}) =>
    '''
Kamu adalah pewawancara profesional yang melatih pencari kerja muda di Indonesia. Nilai satu jawaban latihan wawancara.

Lowongan: ${job.title} di ${job.company}
Deskripsi: ${job.desc}
Keterampilan wajib: ${joinId(job.wajib)}
Jenis pertanyaan: $questionType
Pertanyaan: $question

Jawaban kandidat:
"""
$answer
"""

Rubrik, masing-masing 0–25:
- relevansi: seberapa langsung jawaban menjawab pertanyaan dan relevan dengan lowongan.
- struktur: seberapa runtut mengikuti pola STAR (Situasi, Tugas, Aksi, Hasil).
- kejelasan: bahasa jelas, kalimat lengkap, mudah diikuti.
- bukti: ada contoh konkret, angka, atau hasil terukur.

Tulis dalam Bahasa Indonesia yang ramah dan menyemangati, sapa kandidat dengan "kamu":
- good: satu kalimat tentang hal yang sudah baik dari jawaban ini.
- improve: satu kalimat saran paling penting untuk memperbaiki jawaban ini.
- better: versi jawaban yang lebih baik, 60–120 kata, sudut pandang orang pertama ("saya"), memakai pola STAR. Gunakan hanya fakta dari jawaban kandidat; bila butuh angka atau detail yang tidak disebut, tulis penanda dalam kurung siku seperti [jumlah].
Jangan menilai atau mengomentari agama, suku, status pernikahan, kesehatan, usia, atau penampilan.
''';

String generateLetterPrompt({required Job job, required Profile profile, required LetterTone tone, required int variant, required DateTime today}) {
  final r = computeMatch(job, profile);
  final exps = profile.exps.map((e) => '- ${e.title} di ${e.org} (${e.months} bulan)${e.desc.isEmpty ? '' : ': ${e.desc}'}').join('\n');
  final format = tone == LetterTone.formal
      ? 'Surat formal lengkap: baris pertama "${profile.city.isEmpty ? job.city : profile.city}, ${formatDateId(today)}", lalu "Kepada Yth." dan "Tim Rekrutmen ${job.company}", "di ${job.city}", salam pembuka "Dengan hormat,", 3–4 paragraf isi, penutup "Hormat saya," dan nama.'
      : 'Surat ringkas untuk dikirim lewat email atau pesan: sapaan "Yth. Tim Rekrutmen ${job.company},", 2 paragraf pendek, penutup "Salam," dan nama. Maksimal 120 kata.';
  return '''
Tulis surat lamaran kerja dalam Bahasa Indonesia yang baik dan benar.

Pelamar: ${profile.name}, ${profile.level.label} ${profile.major}${profile.school == '-' ? '' : ' dari ${profile.school}'}
Keterampilan yang sesuai dengan lowongan: ${joinId([...r.matchedWajib, ...r.matchedTambahan])}
Pengalaman:
${exps.isEmpty ? '- (belum ada pengalaman kerja; tonjolkan kemauan belajar dan keterampilan)' : exps}

Lowongan: ${job.title} di ${job.company}, ${job.city}
Deskripsi: ${job.desc}

Format: $format
Aturan: gunakan hanya fakta di atas, jangan mengarang pengalaman, angka, atau sertifikat. Sebutkan bahwa CV terlampir. Tanpa tanda kurung siku atau isian kosong.
Variasi ke-$variant: gunakan kalimat pembuka dan susunan kalimat yang berbeda dari variasi lain.
''';
}
