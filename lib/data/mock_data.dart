// Curated prototype data (proposal 1.5: job data is curated manually by the team).
import 'models.dart';

const jobs = <Job>[
  Job(
    id: 'j1',
    title: 'Staf Administrasi Keuangan',
    company: 'PT Sinar Mandiri Abadi',
    city: 'Purwokerto',
    mode: WorkMode.kantor,
    field: 'keuangan',
    salary: 'Rp4,2–5 jt / bulan',
    wajib: ['Microsoft Excel', 'Akuntansi Dasar', 'Pembukuan', 'Pelaporan Keuangan'],
    tambahan: ['Komunikasi', 'Software Akuntansi'],
    eduMin: EduLevel.s1,
    eduFields: ['Akuntansi', 'Manajemen'],
    expYears: 0,
    desc:
        'Mencatat transaksi harian, melakukan rekonsiliasi kas, dan menyusun laporan keuangan bulanan untuk kantor cabang Purwokerto. Terbuka untuk lulusan baru.',
  ),
  Job(
    id: 'j2',
    title: 'Admin Media Sosial',
    company: 'Kopi Lereng Slamet',
    city: 'Purwokerto',
    mode: WorkMode.hybrid,
    field: 'pemasaran',
    salary: 'Rp3–3,8 jt / bulan',
    wajib: ['Canva', 'Copywriting', 'Meta Ads'],
    tambahan: ['Komunikasi', 'Fotografi Produk'],
    eduMin: EduLevel.d3,
    eduFields: ['Semua'],
    expYears: 0,
    desc: 'Mengelola konten Instagram dan TikTok, membuat jadwal unggahan, dan menjalankan iklan berbayar untuk UMKM kopi lokal.',
  ),
  Job(
    id: 'j3',
    title: 'Junior Data Analyst',
    company: 'Tani Digital Nusantara',
    city: 'Yogyakarta',
    mode: WorkMode.remote,
    field: 'data',
    salary: 'Rp5–6,5 jt / bulan',
    wajib: ['Microsoft Excel', 'SQL', 'Visualisasi Data', 'Statistik Dasar'],
    tambahan: ['Python', 'Komunikasi'],
    eduMin: EduLevel.s1,
    eduFields: ['Statistika', 'Informatika', 'Matematika'],
    expYears: 1,
    desc: 'Mengolah data transaksi petani mitra, membuat dasbor mingguan, dan menyajikan temuan kepada tim produk.',
  ),
  Job(
    id: 'j4',
    title: 'Customer Service Officer',
    company: 'BPR Artha Sejahtera',
    city: 'Purwokerto',
    mode: WorkMode.kantor,
    field: 'layanan',
    salary: 'Rp3,5–4,2 jt / bulan',
    wajib: ['Komunikasi', 'Microsoft Excel', 'Pelayanan Pelanggan'],
    tambahan: ['Bahasa Inggris', 'Microsoft Word'],
    eduMin: EduLevel.d3,
    eduFields: ['Semua'],
    expYears: 0,
    desc: 'Melayani nasabah di kantor, menjelaskan produk tabungan dan kredit, serta mencatat keluhan dan tindak lanjutnya.',
  ),
  Job(
    id: 'j5',
    title: 'Staf Pajak & Pembukuan',
    company: 'KAP Wijaya & Rekan',
    city: 'Banyumas',
    mode: WorkMode.kantor,
    field: 'keuangan',
    salary: 'Rp4–4,8 jt / bulan',
    wajib: ['Pembukuan', 'Akuntansi Dasar', 'Perpajakan', 'Microsoft Excel'],
    tambahan: ['Software Akuntansi', 'e-Faktur'],
    eduMin: EduLevel.s1,
    eduFields: ['Akuntansi'],
    expYears: 1,
    desc: 'Menyiapkan pembukuan klien UMKM, menghitung PPh 21, dan membantu pelaporan SPT Masa.',
  ),
  Job(
    id: 'j6',
    title: 'Admin Gudang',
    company: 'CV Berkah Logistik',
    city: 'Cilacap',
    mode: WorkMode.kantor,
    field: 'logistik',
    salary: 'Rp3,2–3,6 jt / bulan',
    wajib: ['Microsoft Excel', 'Manajemen Inventaris', 'Pencatatan Stok'],
    tambahan: ['Komunikasi', 'Ketelitian Data'],
    eduMin: EduLevel.smaSmk,
    eduFields: ['Semua'],
    expYears: 0,
    desc: 'Mencatat barang masuk dan keluar, menyusun laporan stok harian, dan membantu stock opname bulanan.',
  ),
];

Job jobById(String id) => jobs.firstWhere((j) => j.id == id);

/// Profile extracted from Rani's CV (persona in proposal Tabel 2.1).
const raniProfile = Profile(
  name: 'Rani Lestari',
  level: EduLevel.s1,
  major: 'Manajemen',
  school: 'Universitas Banyumas Raya',
  city: 'Purwokerto',
  modes: [WorkMode.kantor, WorkMode.hybrid],
  source: ProfileSource.cvPdf,
  skills: ['Microsoft Excel', 'Akuntansi Dasar', 'Pembukuan', 'Komunikasi', 'Canva', 'Microsoft Word', 'Manajemen Waktu'],
  exps: [
    Experience(
      title: 'Magang Staf Keuangan',
      org: 'KSP Sejahtera Bersama',
      type: ExperienceType.magang,
      months: 6,
      field: 'keuangan',
      desc: 'membantu pencatatan transaksi harian dan menyusun rekap kas bulanan',
    ),
    Experience(
      title: 'Bendahara Himpunan Mahasiswa',
      org: 'HIMA Manajemen',
      type: ExperienceType.organisasi,
      months: 12,
      field: 'keuangan',
      desc: 'mengelola anggaran kegiatan dan laporan pertanggungjawaban',
    ),
  ],
);

const resources = <String, LearningResource>{
  'Pelaporan Keuangan': LearningResource(ResourceType.kursus, '3 jam', 'Dasar Menyusun Laporan Keuangan'),
  'Software Akuntansi': LearningResource(ResourceType.video, '2 jam', 'Pengenalan Software Akuntansi untuk UMKM'),
  'Copywriting': LearningResource(ResourceType.kursus, '4 jam', 'Copywriting untuk Media Sosial'),
  'Meta Ads': LearningResource(ResourceType.modul, '3 jam', 'Iklan Berbayar di Instagram & Facebook'),
  'Fotografi Produk': LearningResource(ResourceType.video, '90 mnt', 'Foto Produk dengan Ponsel'),
  'SQL': LearningResource(ResourceType.kursus, '6 jam', 'SQL Dasar untuk Analisis Data'),
  'Visualisasi Data': LearningResource(ResourceType.kursus, '4 jam', 'Visualisasi Data dengan Spreadsheet'),
  'Statistik Dasar': LearningResource(ResourceType.modul, '5 jam', 'Statistik Deskriptif untuk Pemula'),
  'Python': LearningResource(ResourceType.kursus, '8 jam', 'Python Dasar untuk Data'),
  'Pelayanan Pelanggan': LearningResource(ResourceType.video, '2 jam', 'Prinsip Pelayanan Prima'),
  'Bahasa Inggris': LearningResource(ResourceType.modul, '10 jam', 'Bahasa Inggris untuk Dunia Kerja'),
  'Perpajakan': LearningResource(ResourceType.kursus, '5 jam', 'PPh 21 dan Dasar Perpajakan'),
  'e-Faktur': LearningResource(ResourceType.video, '1 jam', 'Membuat e-Faktur Langkah demi Langkah'),
  'Manajemen Inventaris': LearningResource(ResourceType.modul, '3 jam', 'Dasar Manajemen Persediaan'),
  'Pencatatan Stok': LearningResource(ResourceType.video, '90 mnt', 'Kartu Stok dan Stock Opname'),
  'Ketelitian Data': LearningResource(ResourceType.modul, '1 jam', 'Teknik Cek Ganda Data Administrasi'),
  'Microsoft Excel': LearningResource(ResourceType.kursus, '4 jam', 'Excel untuk Administrasi'),
  'Komunikasi': LearningResource(ResourceType.video, '2 jam', 'Komunikasi Efektif di Tempat Kerja'),
  'Canva': LearningResource(ResourceType.video, '1 jam', 'Desain Cepat dengan Canva'),
};

LearningResource resourceFor(String skill) => resources[skill] ?? LearningResource(ResourceType.modul, '2 jam', '$skill untuk Pemula');

/// Spelling variants that `normalizeSkill` maps to the canonical name.
const skillSynonyms = <String, List<String>>{
  'Microsoft Excel': ['Excel', 'MS Excel'],
  'Microsoft Word': ['Word', 'MS Word'],
};

/// Every skill the prototype knows: job requirements, Q&A options, Rani's CV and learning materials.
/// Seeded into Firestore `skills` by `tool/export_seed.dart`.
List<Skill> get skillCatalog {
  final names = <String>{
    for (final j in jobs) ...[...j.wajib, ...j.tambahan],
    ...qaQuestions[2].options,
    ...raniProfile.skills,
    ...resources.keys,
  };
  return [for (final n in names.toList()..sort()) Skill(name: n, synonyms: skillSynonyms[n] ?? const [], resource: resources[n])];
}

const qaQuestions = <QaQuestion>[
  QaQuestion(title: 'Apa pendidikan terakhirmu?', help: 'Pilih satu.', kind: QuestionKind.single, options: ['SMA/SMK', 'D3', 'S1']),
  QaQuestion(
    title: 'Apa jurusanmu?',
    help: 'Tulis nama jurusan atau program keahlian.',
    kind: QuestionKind.text,
    hint: 'Contoh: Teknik Komputer dan Jaringan',
  ),
  QaQuestion(
    title: 'Keterampilan apa yang sudah kamu kuasai?',
    help: 'Pilih semua yang sesuai.',
    kind: QuestionKind.multi,
    options: [
      'Microsoft Excel',
      'Microsoft Word',
      'Komunikasi',
      'Canva',
      'Jaringan Komputer',
      'Perakitan PC',
      'Pelayanan Pelanggan',
      'Bahasa Inggris',
      'Akuntansi Dasar',
      'Copywriting',
    ],
  ),
  QaQuestion(
    title: 'Pengalaman apa yang pernah kamu jalani?',
    help: 'Magang dan organisasi juga dihitung.',
    kind: QuestionKind.multi,
    options: ['Belum ada', 'Magang/PKL', 'Organisasi', 'Kerja paruh waktu', 'Proyek sekolah'],
  ),
  QaQuestion(
    title: 'Ceritakan satu pengalaman yang paling kamu banggakan.',
    help: 'Dua sampai tiga kalimat sudah cukup.',
    kind: QuestionKind.area,
    hint: 'Contoh: Saat PKL, saya memasang jaringan di 20 komputer lab sekolah…',
  ),
  QaQuestion(
    title: 'Bidang kerja apa yang kamu minati?',
    help: 'Pilih satu atau lebih.',
    kind: QuestionKind.multi,
    options: ['Administrasi', 'Keuangan', 'Teknologi Informasi', 'Pemasaran', 'Layanan Pelanggan', 'Logistik'],
  ),
  QaQuestion(
    title: 'Di kota mana kamu ingin bekerja?',
    help: 'Lowongan remote tetap ditampilkan.',
    kind: QuestionKind.single,
    options: ['Purwokerto', 'Banyumas', 'Cilacap', 'Yogyakarta'],
  ),
  QaQuestion(
    title: 'Mode kerja yang kamu inginkan?',
    help: 'Pilih semua yang kamu terima.',
    kind: QuestionKind.multi,
    options: ['Kantor', 'Hybrid', 'Remote'],
  ),
];

/// Interview set generated for j1 (Staf Administrasi Keuangan): 3 behavioural + 2 technical.
const interviewJ1 = <InterviewQuestion>[
  InterviewQuestion(
    type: 'Perilaku',
    text:
        'Ceritakan pengalaman saat kamu harus menyelesaikan banyak tugas administrasi dengan tenggat yang berdekatan. Bagaimana kamu mengaturnya?',
    demo:
        'Waktu magang saya pernah dapat banyak tugas sekaligus. Saya buat daftar prioritas dan mengerjakan yang paling mendesak dulu, jadi semua selesai tepat waktu.',
    better:
        'Saat magang di KSP Sejahtera Bersama, saya diminta menyelesaikan rekap kas bulanan sekaligus menginput sekitar 300 transaksi dalam satu minggu. Saya menyusun daftar prioritas harian dan membuat template Excel agar input lebih cepat. Hasilnya, rekap selesai sehari lebih awal tanpa selisih saldo.',
  ),
  InterviewQuestion(
    type: 'Perilaku',
    text: 'Pernahkah kamu menemukan kesalahan pada data atau catatan keuangan? Apa yang kamu lakukan?',
    demo:
        'Pernah, saat rekap kas ada selisih Rp150.000. Saya cek ulang bukti transaksi satu per satu dan ternyata ada nota yang tercatat dua kali, lalu saya laporkan ke pembimbing dan perbaiki sehingga saldo kembali sesuai.',
    better:
        'Ketika menyusun rekap kas akhir bulan, saya menemukan selisih Rp150.000. Tugas saya memastikan saldo sesuai sebelum dilaporkan. Saya mencocokkan 120 bukti transaksi dengan catatan dan menemukan satu nota tercatat dua kali. Setelah diperbaiki, saldo sesuai dan saya mengusulkan kolom nomor nota agar duplikasi mudah terdeteksi.',
  ),
  InterviewQuestion(
    type: 'Perilaku',
    text: 'Ceritakan saat kamu bekerja sama dengan tim untuk mencapai sebuah target.',
    demo: 'Di himpunan mahasiswa saya jadi bendahara dan bekerja sama dengan panitia supaya acara berjalan lancar.',
    better:
        'Sebagai bendahara HIMA Manajemen, saya bertanggung jawab atas anggaran seminar nasional dengan target 200 peserta. Saya rutin rapat mingguan dengan divisi acara dan sponsor untuk memantau pengeluaran. Hasilnya, acara diikuti 230 peserta dan anggaran surplus 8 persen.',
  ),
  InterviewQuestion(
    type: 'Teknis',
    text: 'Bagaimana langkahmu menyusun rekonsiliasi kas bulanan menggunakan Microsoft Excel?',
    demo: 'Saya bandingkan catatan kas dengan rekening koran, lalu tandai yang belum cocok dan cari penyebabnya.',
    better:
        'Saya mengimpor mutasi rekening koran ke Excel, lalu mencocokkannya dengan buku kas menggunakan VLOOKUP berdasarkan tanggal dan nominal. Transaksi yang tidak cocok saya tandai dengan conditional formatting, lalu saya telusuri buktinya. Terakhir, saya buat ringkasan saldo dan selisih yang sudah dijelaskan.',
  ),
  InterviewQuestion(
    type: 'Teknis',
    text: 'Apa perbedaan laporan laba rugi dan neraca, dan kapan masing-masing digunakan?',
    demo:
        'Laba rugi menunjukkan pendapatan dan beban dalam satu periode, sedangkan neraca menunjukkan aset, kewajiban, dan modal pada satu tanggal tertentu. Laba rugi dipakai untuk menilai kinerja.',
    better:
        'Laporan laba rugi merangkum pendapatan dan beban selama satu periode, misalnya satu bulan, untuk melihat apakah usaha untung atau rugi. Neraca menunjukkan posisi aset, kewajiban, dan modal pada tanggal tertentu. Laba rugi dipakai untuk menilai kinerja, sedangkan neraca untuk menilai kondisi keuangan.',
  ),
];

const initialApplications = <JobApplication>[
  JobApplication(
    id: 'a1',
    title: 'Customer Service Officer',
    company: 'BPR Artha Sejahtera',
    status: AppStage.wawancara,
    date: '2 Okt',
    remind: 'Wawancara 10 Okt, 09.00',
  ),
  JobApplication(
    id: 'a2',
    title: 'Admin Media Sosial',
    company: 'Kopi Lereng Slamet',
    status: AppStage.dikirim,
    date: '1 Okt',
    remind: 'Tindak lanjut 8 Okt',
  ),
  JobApplication(
    id: 'a3',
    title: 'Kasir',
    company: 'Toko Swalayan Mitra',
    status: AppStage.tes,
    date: '28 Sep',
    remind: 'Tes online 9 Okt, 10.00',
  ),
  JobApplication(id: 'a4', title: 'Staf Administrasi', company: 'PT Graha Niaga', status: AppStage.ditolak, date: '18 Sep'),
];
