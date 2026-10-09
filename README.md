# KarirIn

Aplikasi pendamping karier untuk pencari kerja muda (ITASE 7.0 2026, SDG 8): Match Score transparan, Skill Gap & Jalur Belajar, AI Interview Coach, surat lamaran otomatis, dan pelacak lamaran.

Implementasi Flutter dari desain **KarirIn Prototype M3** (Material 3, 16 layar).

Beranda, Detail Lowongan, Rencana Belajar (Skill Gap), Persiapan Latihan, Sesi Latihan, Hasil Latihan, Lamaran, Masuk/Daftar, dan Buat Profil telah diperbarui mengikuti [rencana redesign](docs/ui-redesign-plan.md): palet navy–teal, Plus Jakarta Sans lokal, kartu lowongan beridentitas perusahaan, dan rincian kecocokan yang dapat dibuka. Fondasi visual baru berada di `lib/theme/career_theme.dart` dan `lib/widgets/career_widgets.dart`, diterapkan bertahap per layar. Layar lainnya masih memakai tema M3 awal.

## Menjalankan

```bash
flutter pub get
flutter run                 # perangkat/emulator Android
flutter run -d chrome       # pratinjau di browser
flutter test                # uji Match Score, rubrik wawancara, alur sesi
flutter build apk --release # berkas APK untuk Lampiran 2
```

Simulasi koneksi terputus (skenario black-box no. 11):

```bash
flutter run --dart-define=SIMULATE_OFFLINE=true
```

## Struktur

| Folder | Isi |
|---|---|
| `lib/theme/` | ColorScheme & type scale dari desain (primary `#2F5A8F`, secondary `#006B5F`, tertiary `#7A5900`, Roboto) |
| `lib/data/` | Model (bentuknya mengikuti koleksi Firestore pada Tabel 3.2) dan data lowongan kurasi |
| `lib/logic/` | `match_score.dart` (Persamaan 1), `interview.dart` (rubrik 4 aspek), `cover_letter.dart` |
| `lib/state/` | State aplikasi (Riverpod `Notifier`) |
| `lib/screens/` | Satu berkas per layar; navigasi dengan `go_router` (`lib/router.dart`) |
| `lib/widgets/` | Komponen bersama: logo K (vektor), ring gauge, tag, kartu, bottom sheet |

## Yang masih disimulasikan

Prototipe ini berjalan sepenuhnya offline dengan data contoh, sehingga bisa didemokan tanpa backend:

- **Ekstraksi CV / profil**: memakai profil persona Rani (CV) atau jawaban tanya-jawab (Bayu). Produksi: unggah ke Cloud Storage → fungsi `extractProfile` → Gemini.
- **Penilaian wawancara & surat lamaran**: heuristik lokal dengan bentuk keluaran yang sama dengan JSON dari Gemini.
- **Mode suara**: animasi rekam; transkrip diisi jawaban contoh. Produksi: `speech_to_text`.
- **Autentikasi, notifikasi, unggah berkas**: alur UI lengkap, belum tersambung ke Firebase.

Match Score **tidak** disimulasikan: dihitung dengan rumus tetap `100 × (0,50·Sw + 0,15·St + 0,15·Sp + 0,10·Se + 0,10·Sl)` dan diuji terhadap contoh Tabel 2.4 (Rani: 80 → 92,5).
