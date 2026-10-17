# YP79 Terpadu — Setup & Deploy

## 1. Struktur Project

```
yp79-terpadu/
├── lib/                       # Kode Flutter
├── supabase/
│   ├── migrations/
│   │   ├── 0001_schema.sql    # 1. Jalankan ini dulu
│   │   ├── 0002_rls_functions.sql
│   │   └── 0003_seed.sql
│   └── seed/
├── .github/workflows/build.yml  # CI build APK
└── .env                       # (buat di root, jangan commit)
```

## 2. Menjalankan Migrasi Database

1. Buka project Supabase Anda: `https://supabase.com/dashboard`
2. Masuk project `yukqngrtgevveimhrwke` (atau project YP79).
3. Buka **SQL Editor** → **New query**.
4. Copy-paste seluruh isi `supabase/migrations/0001_schema.sql` → Run.
5. Ulangi untuk `0002_rls_functions.sql`.
6. Ulangi untuk `0003_seed.sql`.

Semua tabel, RLS policies, dan functions harus sukses. Jika ada error, selesaikan terlebih dahulu sebelum lanjut.

> **Penting**: Jangan jalankan 0002 sebelum 0001, karena RLS mengacu ke tabel yang dibuat di 0001.

## 3. Setup `.env` (Root Project)

Buat file `.env` di root `yp79-terpadu/` (sudah di-gitignore otomatis oleh .gitignore Flutter):

```
SUPABASE_URL=https://yukqngrtgevveimhrwke.supabase.co
SUPABASE_ANON_KEY=<anon key dari Supabase Dashboard → Project Settings → API>
```

**Anon key** di-copy dari Supabase Dashboard, **bukan** access token `sbp_`. Access token bersifat per-project dan tidak boleh dipakai sebagai anon key.

## 4. Membuat Akun Admin Pertama

1. Di Supabase Dashboard → **Authentication → Users → Add User**.
2. Email: `admin@yp79.id` (sesuaikan).
3. Password: kuat, minimal 12 karakter, acak.
4. Di **User Metadata** (JSON), isi:
   ```json
   {
     "role": "admin",
     "nama": "Administrator YP79"
   }
   ```
5. Tambahkan **Application Metadata** juga:
   ```json
   {
     "role": "admin"
   }
   ```
6. Setelah user dibuat, login lewat aplikasi → otomatis masuk sebagai Admin Full Access.

> Akun admin **tidak boleh** dibuat lewat aplikasi (login page hanya untuk user yang sudah ada di Supabase Auth). Ini menghindari penanaman kredensial bawaan di source code.

## 5. Membuat User Siswa/Guru/Orang Tua

Sama seperti admin, tambah user di Supabase Auth, tapi dengan metadata role berbeda:
- `role: "guru"` + profile di tabel `teacher_profiles`
- `role: "siswa"` + profile di tabel `student_profiles`
- `role: "orang_tua"` + profile di tabel `parent_profiles`

Admin dapat membuat akun siswa/orang tua via **UI aplikasi** setelah admin login (fitur "Manajemen Pengguna"), bukan lewat Supabase Dashboard.

## 6. Menjalankan Aplikasi Lokal

```bash
# Di root project
flutter pub get
flutter run -d <device>
```

Pastikan `.env` sudah ada dan `SUPABASE_ANON_KEY` diisi.

## 7. Build APK (GitHub Actions)

Push ke branch `main` repo `iznatshi-beep/yp79-terpadu-`:
- CI otomatis build `flutter build apk --release --obfuscate`
- Hasil APK di-upload sebagai artifact + dibuat GitHub Release.

**Secrets yang dibutuhkan di GitHub repo** (Settings → Secrets → Actions):
| Name | Isi |
|---|---|
| `KEYSTORE_BASE64` | Base64 dari `yp79-release.keystore` |
| `KEYSTORE_PASSWORD` | Password keystore |
| `KEYSTORE_KEYPASSWORD` | Password alias |
| `KEYSTORE_ALIAS` | Nama alias (biasanya `yp79-release`) |

## 8. Status Integrasi Eksternal

| Modul | Status | Keterangan |
|---|---|---|
| QR Presensi | Siap | Gunakan `generate_attendance_qr` RPC. Token sekali pakai, hash disimpan server. |
| RFID | Menunggu perangkat | Tunggu integrasi reader fisik. Struktur `attendance_method='rfid'` sudah ada. |
| Push Notification | Menunggu FCM setup | Supabase Realtime tersedia. Push FCM butuh konfigurasi Firebase di aplikasi + webhook. |
| GPS Bus | Siap (telemetry) | `vehicle_locations` menerima koordinat dari device GPS/telemetry. Tanpa kredensial external, tampilkan "posisi belum tersedia". |
| Pembayaran | Nonaktif | Sesuai keputusan Anda, pembayaran via aplikasi dihapus. Modul keuangan hanya menampilkan `finance_items` (jenis biaya + nominal) sebagai informasi, tanpa transaksi. |

## 9. Backup

Di Supabase Dashboard → **Database → Backups**, atur interval backup otomatis. Skema dan data semua tersimpan di Postgres. Jika perlu migrasi antar project, export seluruh skema + data via `pg_dump` atau Supabase Dashboard → **Database → Export**.
