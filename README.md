# KarirIn

Aplikasi pendamping karier untuk pencari kerja muda (ITASE 7.0 2026, SDG 8): Match Score transparan, Skill Gap & Jalur Belajar, AI Interview Coach, surat lamaran otomatis, dan pelacak lamaran.

Implementasi Flutter dari desain **KarirIn Prototype M3** (Material 3, 16 layar).

Beranda, Detail Lowongan, Rencana Belajar (Skill Gap), Persiapan Latihan, Sesi Latihan, Hasil Latihan, Lamaran, Masuk/Daftar, Buat Profil, Tanya Jawab Profil, Konfirmasi Profil, Surat Lamaran, Profil, Processing, Splash, dan Onboarding telah diperbarui mengikuti [rencana redesign](docs/ui-redesign-plan.md): palet navy–teal, Plus Jakarta Sans lokal, kartu lowongan beridentitas perusahaan, dan rincian kecocokan yang dapat dibuka. Fondasi visual baru berada di `lib/theme/career_theme.dart` dan `lib/widgets/career_widgets.dart`; kini dipakai oleh seluruh 16 layar.

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
| `lib/data/repositories/` | Antarmuka repository (lowongan, profil, lamaran) dengan implementasi mock; implementasi Firebase menyusul di Tahap B1 |
| `lib/firebase/` | Inisialisasi Firebase: App Check, Crashlytics, default Remote Config |
| `lib/state/` | State aplikasi (Riverpod `Notifier`) |
| `lib/screens/` | Satu berkas per layar; navigasi dengan `go_router` (`lib/router.dart`) |
| `lib/widgets/` | Komponen bersama: logo K (vektor), ring gauge, tag, kartu, bottom sheet |

## Backend (Firebase)

Rencana lengkap ada di `docs/backend-development-plan.md`: Firebase paket Spark (tanpa billing) + Firebase AI Logic (Gemini). Proyek Firebase: `my-tugas-web` (Firestore `asia-southeast2`). Sumber data dipilih saat build:

```bash
flutter run --dart-define=BACKEND=mock       # default: data contoh offline
flutter run --dart-define=BACKEND=firebase   # perlu lib/firebase_options.dart hasil flutterfire configure
```

| Berkas | Isi |
|---|---|
| `firebase.json`, `.firebaserc` | Konfigurasi CLI dan emulator (Auth 9099, Firestore 8080, UI 4000); alias `emulator` = `demo-karirin` |
| `lib/firebase_options.dart`, `android/app/google-services.json` | Hasil `flutterfire configure` (bukan rahasia) |
| `firestore.rules` | Security rules: pengguna hanya mengakses datanya sendiri; katalog hanya ditulis skrip |
| `tool/export_seed.dart` | Mengekspor lowongan dan skill dari `mock_data.dart` ke `backend/data/*.json` |
| `backend/src/seed.ts` | Mengimpor katalog ke Firestore (merge; lowongan yang dihapus dari JSON dinonaktifkan) |

Mengisi katalog:

```bash
npm --prefix backend install
npm --prefix backend run export-data
firebase emulators:exec --project demo-karirin --only firestore "npm --prefix backend run seed:emulator"
npm --prefix backend run seed    # proyek asli, butuh backend/.env + service account
```

Rahasia **tidak** masuk git: `android/key.properties` dan `android/app/upload-keystore.jks` (tanda tangan APK rilis; simpan cadangannya), `backend/.env`, dan berkas service account. Sidik jari keystore untuk konsol Firebase (SHA-1 untuk Google Sign-In, SHA-256 untuk App Check):

| Keystore | SHA-1 | SHA-256 |
|---|---|---|
| Rilis (`upload`) | `33:96:10:42:AD:EE:AA:B1:29:3C:51:30:94:6F:73:BD:FA:19:08:AA` | `9E:63:AC:70:91:57:CA:CC:36:DE:4C:5F:DF:C7:BA:68:FC:AC:5F:F5:03:14:F8:15:6C:A3:0C:C0:D2:6F:AD:E7` |
| Debug (laptop ini) | `83:68:CA:34:55:06:05:B2:13:22:75:78:DA:C8:F2:F0:53:96:BC:05` | `80:03:B4:77:69:AC:99:48:F5:5B:6D:82:FA:42:20:09:A2:96:DA:D5:BE:92:D0:30:E8:A9:D8:FC:E4:59:29:92` |

## Yang masih disimulasikan

Prototipe ini berjalan sepenuhnya offline dengan data contoh, sehingga bisa didemokan tanpa backend:

- **Ekstraksi CV / profil**: memakai profil persona Rani (CV) atau jawaban tanya-jawab (Bayu). Produksi: unggah ke Cloud Storage → fungsi `extractProfile` → Gemini.
- **Penilaian wawancara & surat lamaran**: heuristik lokal dengan bentuk keluaran yang sama dengan JSON dari Gemini.
- **Mode suara**: animasi rekam; transkrip diisi jawaban contoh. Produksi: `speech_to_text`.
- **Autentikasi, notifikasi, unggah berkas**: alur UI lengkap, belum tersambung ke Firebase.

Match Score **tidak** disimulasikan: dihitung dengan rumus tetap `100 × (0,50·Sw + 0,15·St + 0,15·Sp + 0,10·Se + 0,10·Sl)` dan diuji terhadap contoh Tabel 2.4 (Rani: 80 → 92,5).
