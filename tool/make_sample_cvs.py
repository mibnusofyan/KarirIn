"""Writes fictional sample CVs (the proposal's personas) as plain one-page PDFs for testing CV extraction.

Run from the project root: python tool/make_sample_cvs.py  → test_data/cv/*.pdf
No dependencies: the PDF is assembled by hand with the built-in Helvetica font.
"""
from pathlib import Path

CVS = {
    'cv-rani-lestari.pdf': [
        ('h', 'RANI LESTARI'),
        ('t', 'Purwokerto, Jawa Tengah | rani.lestari@contoh.id | 0812-0000-1111'),
        ('s', 'PENDIDIKAN'),
        ('t', 'S1 Manajemen, Universitas Banyumas Raya (2022 - 2026), IPK 3,52'),
        ('s', 'PENGALAMAN'),
        ('b', 'Magang Staf Keuangan - KSP Sejahtera Bersama (Feb - Jul 2025)'),
        ('t', '- Membantu pencatatan transaksi harian sekitar 300 transaksi per bulan'),
        ('t', '- Menyusun rekap kas bulanan dan rekonsiliasi dengan rekening koran'),
        ('b', 'Bendahara - Himpunan Mahasiswa Manajemen (2023 - 2024)'),
        ('t', '- Mengelola anggaran kegiatan dan laporan pertanggungjawaban'),
        ('s', 'KETERAMPILAN'),
        ('t', 'MS Excel (VLOOKUP, pivot table), Akuntansi Dasar, Pembukuan, MS Word,'),
        ('t', 'Canva, Komunikasi, Manajemen Waktu'),
    ],
    'cv-bayu-pratama.pdf': [
        ('h', 'BAYU PRATAMA'),
        ('t', 'Purwokerto | bayu.pratama@contoh.id | 0857-0000-2222'),
        ('s', 'PENDIDIKAN'),
        ('t', 'SMK Negeri Purwokerto Raya - Teknik Komputer dan Jaringan (2023 - 2026)'),
        ('s', 'PENGALAMAN'),
        ('b', 'Praktik Kerja Lapangan - CV Mitra Komputindo (Jan - Mar 2026)'),
        ('t', '- Merakit dan memperbaiki 15 unit PC kantor klien'),
        ('t', '- Memasang jaringan LAN di 20 komputer laboratorium sekolah mitra'),
        ('b', 'Anggota - Ekstrakurikuler Robotik (2024 - 2025)'),
        ('s', 'KEAHLIAN'),
        ('t', 'Jaringan komputer, perakitan PC, instalasi Windows dan aplikasi kantor,'),
        ('t', 'konfigurasi router MikroTik dasar, Microsoft Excel, komunikasi'),
    ],
    'cv-sinta-ayu.pdf': [
        ('h', 'SINTA AYU WARDANI'),
        ('t', 'Yogyakarta | sinta.wardani@contoh.id | 0821-0000-3333'),
        ('s', 'RINGKASAN'),
        ('t', 'Staf administrasi 2 tahun yang ingin beralih ke bidang analisis data.'),
        ('s', 'PENGALAMAN KERJA'),
        ('b', 'Staf Administrasi - PT Graha Niaga, Yogyakarta (Agu 2024 - sekarang)'),
        ('t', '- Mengelola data penjualan bulanan dan membuat laporan di Excel'),
        ('t', '- Membuat dasbor penjualan sederhana yang dipakai 3 kepala cabang'),
        ('s', 'PENDIDIKAN'),
        ('t', 'D3 Statistika, Politeknik Statistika Nusantara (2021 - 2024)'),
        ('s', 'KETERAMPILAN'),
        ('t', 'Microsoft Excel, SQL dasar, visualisasi data, statistik deskriptif,'),
        ('t', 'Python (pemula), komunikasi, ketelitian data'),
    ],
}

STYLE = {'h': ('F2', 18, 26), 's': ('F2', 11, 24), 'b': ('F2', 10.5, 17), 't': ('F1', 10.5, 16)}


def _escape(s: str) -> str:
    return s.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')


def write_pdf(path: Path, lines):
    y = 790
    ops = []
    for kind, text in lines:
        font, size, gap = STYLE[kind]
        if kind == 's':
            y -= 8
        ops.append(f'BT /{font} {size} Tf 56 {y} Td ({_escape(text)}) Tj ET')
        y -= gap
    stream = '\n'.join(ops).encode('latin-1')
    objs = [
        b'<< /Type /Catalog /Pages 2 0 R >>',
        b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>',
        b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
        b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
        b'<< /Length %d >>\nstream\n' % len(stream) + stream + b'\nendstream',
    ]
    out = bytearray(b'%PDF-1.4\n')
    offsets = []
    for i, o in enumerate(objs, 1):
        offsets.append(len(out))
        out += b'%d 0 obj\n' % i + o + b'\nendobj\n'
    xref = len(out)
    out += b'xref\n0 %d\n0000000000 65535 f \n' % (len(objs) + 1)
    out += b''.join(b'%010d 00000 n \n' % off for off in offsets)
    out += b'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' % (len(objs) + 1, xref)
    path.write_bytes(bytes(out))


if __name__ == '__main__':
    target = Path('test_data/cv')
    target.mkdir(parents=True, exist_ok=True)
    for name, lines in CVS.items():
        write_pdf(target / name, lines)
        print(target / name)
