import '../data/models.dart';
import 'match_score.dart';

enum LetterTone { formal, ringkas }

/// Template-based cover letter used by the prototype. In production the
/// `generateLetter` Cloud Function asks Gemini for the same personalised text.
/// [seed] alternates the opening sentence when the user taps "Buat ulang".
String coverLetter(Job job, Profile p, LetterTone tone, int seed) {
  final r = computeMatch(job, p);
  final matched = [...r.matchedWajib, ...r.matchedTambahan].take(3).toList();
  final sk = matched.isEmpty ? 'administrasi' : joinId(matched);
  final e = p.exps.isEmpty ? null : p.exps.first;
  final expLine = e != null && e.desc.isNotEmpty
      ? 'Selama ${e.title.toLowerCase()} di ${e.org}, saya ${e.desc}.'
      : 'Saya terbiasa bekerja teliti, tepat waktu, dan cepat mempelajari hal baru.';
  final open = seed.isEven
      ? 'Saya ${p.name}, lulusan ${p.level.label} ${p.major}, bermaksud melamar posisi ${job.title} di ${job.company}.'
      : 'Melalui surat ini, saya ${p.name} mengajukan lamaran untuk posisi ${job.title} di ${job.company}.';

  if (tone == LetterTone.ringkas) {
    return 'Yth. Tim Rekrutmen ${job.company},\n\n$open Saya menguasai $sk. $expLine\n\n'
        'CV saya terlampir. Terima kasih atas waktu dan pertimbangannya.\n\nSalam,\n${p.name}';
  }
  return '${p.city}, 8 Oktober 2026\n\nKepada Yth.\nTim Rekrutmen ${job.company}\ndi ${job.city}\n\nDengan hormat,\n\n'
      '$open Saya memiliki keterampilan $sk yang sesuai dengan kebutuhan posisi ini.\n\n'
      '$expLine Pengalaman tersebut melatih saya bekerja teliti, rapi, dan tepat waktu.\n\n'
      'Saya yakin dapat berkontribusi bagi tim ${job.company}. Bersama surat ini saya lampirkan CV sebagai bahan pertimbangan. '
      'Atas perhatian Bapak/Ibu, saya ucapkan terima kasih.\n\nHormat saya,\n${p.name}';
}
