// KarirIn partner employers for Lamar cepat. They are fictional (the prototype's companies), labelled "Mitra demo" in
// the app, and their recruiter is the team running backend/src/recruiter.ts. Real companies stay in catalog_real.dart,
// where the user applies on the company's own site.
import 'models.dart';

const _note =
    ' Lowongan demo dari mitra fiktif KarirIn untuk mencoba Lamar cepat: lamaran dikirim di dalam aplikasi dan statusnya diperbarui tim KarirIn sebagai rekruter.';

const partnerJobs = <Job>[
  Job(
    id: 'mitra-sinar-mandiri-admin-keuangan',
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
    desc: 'Mencatat transaksi harian, melakukan rekonsiliasi kas, dan menyusun laporan keuangan bulanan. Terbuka untuk lulusan baru.$_note',
    quickApply: true,
  ),
  Job(
    id: 'mitra-lereng-slamet-admin-sosmed',
    title: 'Admin Media Sosial',
    company: 'Kopi Lereng Slamet',
    city: 'Purwokerto',
    mode: WorkMode.hybrid,
    field: 'pemasaran',
    salary: 'Rp3–3,8 jt / bulan',
    wajib: ['Canva', 'Copywriting', 'Meta Ads'],
    tambahan: ['Komunikasi', 'Fotografi Produk'],
    eduMin: EduLevel.smaSmk,
    eduFields: ['Semua'],
    expYears: 0,
    desc: 'Mengelola konten Instagram dan TikTok, membuat jadwal unggahan, dan menjalankan iklan berbayar untuk UMKM kopi lokal.$_note',
    quickApply: true,
  ),
  Job(
    id: 'mitra-berkah-logistik-admin-gudang',
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
    desc: 'Mencatat barang masuk dan keluar, menyusun laporan stok harian, dan membantu stock opname bulanan.$_note',
    quickApply: true,
  ),
];
