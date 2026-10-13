// One free YouTube video per skill, played inside KarirIn (VideoLessonScreen). Picked by the team: Indonesian,
// beginner level, embeddable (`playableInEmbed`), checked 13 Okt 2026. `tool/export_seed.dart` turns each entry into
// the skill's learning material in Firestore, so changing a video here needs a re-export and seed.

class LearningVideo {
  const LearningVideo(this.id, this.channel, this.seconds);

  /// YouTube video id (the `v=` of a watch URL).
  final String id;
  final String channel;
  final int seconds;

  String get url => 'https://www.youtube.com/watch?v=$id';

  /// "25 mnt", "1 jam 8 mnt".
  String get durationLabel {
    final m = (seconds / 60).round().clamp(1, 1 << 20);
    if (m < 60) return '$m mnt';
    return m % 60 == 0 ? '${m ~/ 60} jam' : '${m ~/ 60} jam ${m % 60} mnt';
  }
}

const learningVideos = <String, LearningVideo>{
  'Akuntansi Dasar': LearningVideo('jQ2vOo_lPdA', 'William Basri', 1512),
  'Bahasa Inggris': LearningVideo('ue8xB1oxXdE', 'Elearning Media', 716),
  'Canva': LearningVideo('ynwUuEELPYw', 'Schoolpedia', 1926),
  'Copywriting': LearningVideo('w7drAXsN8xA', 'Upgraded', 400),
  'e-Faktur': LearningVideo('KS40I1LcKZ0', 'Direktorat Jenderal Pajak', 389),
  'Fotografi Produk': LearningVideo('99mynr-NWSs', 'Glenn Prasetya', 980),
  'Instalasi Software': LearningVideo('SOxURzYOhns', 'Levelup iD', 1063),
  'Jaringan Komputer': LearningVideo('CMlqR70Nk9Y', 'ID-Networkers (IDN.ID)', 747),
  'Kepemimpinan': LearningVideo('Xn0byI5PDVc', 'Fanny Winara', 1173),
  'Ketelitian Data': LearningVideo('euq7Af56c58', 'Budi Tutorials', 482),
  'Komunikasi': LearningVideo('QKmhxs56PAg', 'Satu Persen - Indonesian Life School', 478),
  'Manajemen Inventaris': LearningVideo('LtGOmbDchG0', 'Belajar Manajemen Ekonomi Bisnis', 2197),
  'Manajemen Waktu': LearningVideo('P-CS6RVU7ic', 'Satu Persen - Indonesian Life School', 1037),
  'Meta Ads': LearningVideo('NHd7EVbWwk4', 'Akuira', 3504),
  'Microsoft Excel': LearningVideo('0ttAfGBNruE', 'Felly Tutorial', 957),
  'Microsoft Word': LearningVideo('Ua2ws-LcLxE', 'Ignasius Ryan', 1307),
  'Negosiasi': LearningVideo('Q6t3tkAIfZk', 'Raymond Chin', 810),
  'Pelaporan Keuangan': LearningVideo('5BzbPBKjqGg', 'Felly Tutorial', 898),
  'Pelayanan Pelanggan': LearningVideo('R5jUms6wAtU', 'Marketeers TV', 500),
  'Pembukuan': LearningVideo('Gpxd-zSthGg', 'Kelly Patricia', 760),
  'Pencatatan Stok': LearningVideo('ODquNYzuNaQ', 'Empat Klip', 237),
  'Perakitan PC': LearningVideo('yx7n_MsHqF0', 'LKP Sembiring Official', 777),
  'Perpajakan': LearningVideo('HIVpdqCeMdQ', 'RajaPPN', 1285),
  'Python': LearningVideo('poZtdyC24P4', 'Dea Afrizal', 4075),
  'Software Akuntansi': LearningVideo('2o3wkwvGHDs', 'Dedy Sidarta', 402),
  'SQL': LearningVideo('7WH4mKdYKZQ', 'SUHU TV', 375),
  'Statistik Dasar': LearningVideo('el7Ezn9PpWU', 'Indonesia Belajar', 753),
  'Troubleshooting Hardware': LearningVideo('at-NL8_XT_w', 'Timon Adiyoso', 369),
  'Visualisasi Data': LearningVideo('6vH3HGrhMfw', 'EduFlix', 532),
};
