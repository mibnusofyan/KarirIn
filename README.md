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

Rencana lengkap ada di `docs/backend-development-plan.md`: Firebase paket Spark (tanpa billing) + Firebase AI Logic (Gemini). Proyek Firebase: `my-tugas-web` (Firestore `asia-southeast2`). Aplikasi Android memakai Firebase secara default; `flutter test` dan pratinjau web otomatis memakai data contoh (mock). Sumber data dapat dipaksa saat build:

```bash
flutter run                                  # default: proyek asli my-tugas-web
flutter run --dart-define=BACKEND=mock       # data contoh offline (APK cadangan demo)
flutter run --dart-define=USE_EMULATOR=true  # Auth + Firestore emulator lokal (debug)
```

Opsi build debug lain: `--dart-define=APP_CHECK_DEBUG_TOKEN=<uuid>` memakai token debug App Check yang sudah didaftarkan di konsol (tanpa itu, tiap instal baru mencetak token baru di log dan panggilan Gemini ditolak sampai token itu didaftarkan), dan `--dart-define=REMINDER_DEMO_MINUTES=1` membuat pengingat lamaran muncul 1 menit setelah dicatat (untuk demo/uji), bukan H+7 pukul 09.00.

Rilis untuk pengumpulan (APK ditandatangani keystore rilis, disalin ke `release/` yang tidak masuk git):

```bash
flutter clean
flutter build apk --release                           # KarirIn-v1.0.apk (Firebase)
flutter build apk --release --dart-define=BACKEND=mock   # KarirIn-v1.0-demo-offline.apk (cadangan tanpa server)
```

Build rilis dikecilkan R8; `android/app/proguard-rules.pro` menjaga kelas yang dibutuhkan pengingat terjadwal. Remote Config produksi berasal dari `remoteconfig.template.json` (`firebase deploy --only remoteconfig`), misalnya untuk mengganti model Gemini atau mematikan AI (`ai_enabled`) tanpa APK baru. Skenario uji ada di `docs/pengujian-black-box.md`.

Bila APK debug tidak memuat perubahan Dart terbaru (pernah terjadi: Gradle menganggap kompilasi Flutter sudah mutakhir), jalankan `flutter clean` lalu build ulang.

Pada mode `firebase`: login email/kata sandi dan Google (Firebase Auth), redirect otomatis (belum login → Masuk, belum punya profil → Buat profil, sudah → Beranda), profil disimpan ke `profiles/{uid}` setelah dikonfirmasi lalu setiap perubahan ikut tersimpan, simpanan lowongan dan pengaturan notifikasi di `users/{uid}`, katalog 20 lowongan dan 35 skill dibaca dari Firestore, Keluar, dan Hapus akun (menghapus data lalu akun).

Fitur AI (Tahap B2) memakai Gemini lewat Firebase AI Logic (nama model di Remote Config `ai_model_extract` dan `ai_model_fast`, sakelar `ai_enabled`):

- **Ekstraksi CV**: PDF (maks. 5 MB) atau foto kamera dibaca Gemini menjadi profil, divalidasi (`lib/services/ai/ai_parsing.dart`), lalu diperiksa pengguna. Berkas disimpan di penyimpanan privat perangkat; salinannya hanya dikirim ke server bersama Lamar cepat yang disetujui pengguna.
- **Penilaian wawancara**: rubrik 4 aspek + contoh jawaban yang dipersonalisasi; sesi tersimpan di `users/{uid}/interviews`. Mode suara memakai pengenalan suara perangkat (`id_ID`).
- **Surat lamaran**: nada formal/ringkas, buat ulang, salin, dan bagikan.
- Bila AI gagal (kuota, jaringan, keluaran tidak valid), penilaian dan surat memakai logika lokal dengan label "offline"; ekstraksi CV menampilkan galat dengan pilihan coba lagi atau tanya-jawab.

Pelacak lamaran (Tahap B3):

- Lamaran tersimpan di `users/{uid}/applications` (tanggal nyata dan riwayat status) dan tersinkron langsung, termasuk perubahan saat offline.
- "Lamar di situs perusahaan" (lowongan perusahaan nyata) membuka halaman resmi di dalam aplikasi (Custom Tabs). Saat pengguna kembali ke KarirIn, aplikasi menanyakan apakah lamaran sudah terkirim sebelum mencatatnya. "Simpan salinan CV untuk diunggah" membagikan CV dari perangkat ke File/Drive, karena pemilih berkas portal tidak bisa membuka penyimpanan privat aplikasi.
- Pengingat tindak lanjut adalah notifikasi lokal terjadwal (H+7 pukul 09.00), dibatalkan saat lamaran selesai atau toggle dimatikan, dan dijadwalkan ulang saat masuk di perangkat baru. Izin notifikasi Android 13+ diminta saat pertama kali dibutuhkan.
- Rencana Belajar: "Buka materi" membuka tautan materi dari koleksi `skills`; "Unggah bukti" menyimpan tautan sertifikat atau catatan di profil.
- Snapshot Match Score per lowongan di `users/{uid}/matches` diperbarui setiap profil berubah, untuk validasi skor (subbab 3.2.3).
- Beranda menampilkan kartu offline saat perangkat tidak terhubung, dan sheet notifikasi berisi notifikasi dari Firestore serta pengingat yang akan datang.
- Hapus akun menghapus semua subkoleksi pengguna, salinan CV, dan pengingat terjadwal.

Lamar cepat (lowongan mitra demo):

- Lowongan dari mitra fiktif (`lib/data/catalog_partner.dart`, berlabel "Lamar cepat · Mitra demo") dilamar di dalam aplikasi: CV PDF dari perangkat (atau dipilih saat melamar, maks. 5 MB), surat lamaran opsional (bisa dibuat dari profil), dan persetujuan berbagi data per lamaran. Lowongan perusahaan nyata tetap lewat situs perusahaan.
- Lamaran disimpan di `users/{uid}/applications/{id}` dengan `quick: true`, salinan profil (`applicant`), `letter`, dan `consent`. Karena paket Spark tidak punya Cloud Storage, CV disimpan sebagai bytes di `applications/{id}/cv/0..5`, maksimal 900 KB per potongan. Rules mewajibkan status awal `dikirim`, melarang pengguna mengubah statusnya, dan melarang potongan CV diganti.
- Pelacak menampilkan status dari perusahaan, pesan rekruter, dan riwayat. "Tarik lamaran" menghapus lamaran beserta salinan CV.
- Sisi rekruter (dashboard web di luar cakupan lomba Mobile Development) dijalankan tim lewat skrip:

```bash
npm --prefix backend run recruiter -- inbox
npm --prefix backend run recruiter -- status <id> wawancara --note "Senin 27 Okt, 10.00 via Zoom."
npm --prefix backend run recruiter -- status <id> ditolak --dry-run
```

`inbox` menyimpan CV (PDF utuh) dan ringkasan pelamar di `backend/inbox/`. Folder ini masuk `.gitignore` karena berisi data pribadi, jadi hapus setelah demo. `status` mengubah status dan riwayat, menyimpan notifikasi, lalu mengirim push lewat kanal `application_status`; Pelacak di HP pelamar langsung berubah.

Tautan materi belajar saat ini adalah pencarian video gratis berdasarkan judul materi (`tool/export_seed.dart`); ganti dengan kursus pilihan tim di `lib/data/mock_data.dart`/`catalog_extra.dart` (`LearningResource.url`), lalu jalankan export dan seed.

| Berkas | Isi |
|---|---|
| `firebase.json`, `.firebaserc` | Konfigurasi CLI dan emulator (Auth 9099, Firestore 8080, UI 4000); alias `emulator` = `demo-karirin` |
| `lib/firebase_options.dart`, `android/app/google-services.json` | Hasil `flutterfire configure` (bukan rahasia) |
| `firestore.rules` | Security rules: pengguna hanya mengakses datanya sendiri; katalog hanya ditulis skrip |
| `lib/data/catalog_extra.dart` | 14 lowongan tambahan (j7–j20, termasuk TKJ) yang hanya masuk Firestore; mode mock tetap 6 lowongan |
| `lib/data/catalog_partner.dart` | Lowongan mitra demo untuk Lamar cepat (hanya Firestore) |
| `tool/export_seed.dart` | Mengekspor lowongan dan skill (`catalog_real.dart` + `catalog_partner.dart`) ke `backend/data/*.json` |
| `backend/src/recruiter.ts` | Sisi rekruter Lamar cepat: unduh lamaran dan CV, ubah status, kirim push |
| `backend/test/rules.test.ts` | Uji security rules di emulator: `npm --prefix backend run test:rules` |
| `backend/src/seed.ts` | Mengimpor katalog ke Firestore (merge; lowongan yang dihapus dari JSON dinonaktifkan) |
| `backend/src/generate-questions.ts` | Draf 5 pertanyaan wawancara per lowongan dari Gemini → ditinjau tim (`reviewedBy`) → diterbitkan ke `jobs/{id}/questionSets` |
| `tool/make_sample_cvs.py`, `test_data/cv/` | CV contoh fiktif (Rani, Bayu, Sinta) untuk menguji ekstraksi; pakai juga untuk demo dan UAT |

Mengisi katalog:

```bash
npm --prefix backend install
npm --prefix backend run export-data
firebase emulators:exec --project demo-karirin --only firestore "npm --prefix backend run seed:emulator"
npm --prefix backend run seed    # proyek asli, butuh backend/.env + service account
```

Menguji aplikasi terhadap emulator (data dan akun hanya ada di laptop):

```bash
firebase emulators:start --project my-tugas-web --only auth,firestore
```

Lalu isi katalog ke emulator dengan `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=my-tugas-web npx --prefix backend tsx backend/src/seed.ts`. Di Windows, `firebase emulators:exec` kadang meninggalkan proses Java yang tetap memegang port 8080; hentikan proses itu bila emulator berikutnya gagal dengan "port taken".

Rahasia **tidak** masuk git: `android/key.properties` dan `android/app/upload-keystore.jks` (tanda tangan APK rilis; simpan cadangannya), `backend/.env`, dan berkas service account. Sidik jari keystore untuk konsol Firebase (SHA-1 untuk Google Sign-In, SHA-256 untuk App Check):

| Keystore | SHA-1 | SHA-256 |
|---|---|---|
| Rilis (`upload`) | `33:96:10:42:AD:EE:AA:B1:29:3C:51:30:94:6F:73:BD:FA:19:08:AA` | `9E:63:AC:70:91:57:CA:CC:36:DE:4C:5F:DF:C7:BA:68:FC:AC:5F:F5:03:14:F8:15:6C:A3:0C:C0:D2:6F:AD:E7` |
| Debug (laptop ini) | `83:68:CA:34:55:06:05:B2:13:22:75:78:DA:C8:F2:F0:53:96:BC:05` | `80:03:B4:77:69:AC:99:48:F5:5B:6D:82:FA:42:20:09:A2:96:DA:D5:BE:92:D0:30:E8:A9:D8:FC:E4:59:29:92` |

## Yang masih disimulasikan

Pada build mock (`--dart-define=BACKEND=mock`, juga dipakai `flutter test` dan pratinjau web) aplikasi berjalan offline dengan data contoh:

- **Ekstraksi CV / profil**: memakai profil persona Rani (CV) atau jawaban tanya-jawab (Bayu).
- **Penilaian wawancara & surat lamaran**: heuristik lokal dengan bentuk keluaran yang sama dengan JSON dari Gemini; juga menjadi cadangan build Firebase saat AI tidak tersedia.
- **Mode suara**: animasi rekam; transkrip diisi jawaban contoh.
- **Autentikasi**: alur UI saja.
- **Lamar cepat**: lowongan j1 dan j6 berlaku sebagai mitra; CV contoh Rani dipakai dan lamaran hanya tersimpan di memori.

Notifikasi lowongan baru (Tahap B5): setiap perangkat menyimpan token FCM di `users/{uid}.fcmTokens` (izin notifikasi diminta setelah profil pertama disimpan). Setelah lowongan baru ditambahkan ke `catalog_extra.dart` dan diekspor, jalankan:

```bash
npm --prefix backend run seed
npm --prefix backend run notify -- j21 --dry-run
npm --prefix backend run notify -- j21
```

Skrip menghitung Match Score dengan port TypeScript (`backend/src/match-score.ts`, dijamin sama dengan Dart lewat `test/fixtures/match_cases.json`), lalu untuk pengguna dengan skor ≥ 75 yang tidak mematikan pengaturannya menyimpan dokumen di `users/{uid}/notifications` dan mengirim push. Mengetuk notifikasi membuka detail lowongan. Jalankan ulang aman: tiap pengguna hanya dinotifikasi sekali per lowongan. Alternatif tanpa laptop: GitHub → Actions → "Kirim notifikasi lowongan baru" (butuh secret `FIREBASE_SERVICE_ACCOUNT`).

CI GitHub Actions (`.github/workflows/ci.yml`) menjalankan `flutter analyze`, `flutter test`, typecheck backend, uji kesetaraan Match Score Dart/TypeScript, dan uji security rules di setiap PR.

App Check: Firebase AI Logic sudah di-enforce (permintaan Gemini hanya dari aplikasi asli atau token debug terdaftar); Firestore dan Auth sengaja tidak di-enforce agar aplikasi tetap bisa dipakai di perangkat yang gagal Play Integrity (misalnya emulator), dengan fitur AI jatuh ke cadangan.

Match Score **tidak** disimulasikan: dihitung dengan rumus tetap `100 × (0,50·Sw + 0,15·St + 0,15·Sp + 0,10·Se + 0,10·Sl)` dan diuji terhadap contoh Tabel 2.4 (Rani: 80 → 92,5).
