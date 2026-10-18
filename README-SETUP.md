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
2. Masuk project `kqkemiuqyfhqbwlgguqg` (project YP79 yang sudah live), atau project baru buatan Anda.
3. Buka **SQL Editor** → **New query**.
4. Copy-paste seluruh isi `0001_schema.sql` → Run.
5. Ulangi untuk `0002_rls_functions.sql`.
6. Ulangi untuk `0003_seed.sql`.
7. Ulangi untuk `0004_fixes.sql` — unique constraint presensi (tanpa ini penyimpanan
   presensi gagal), perbaikan seed tahun ajaran semester genap, foreign key kelas.
8. Ulangi untuk `0005_cbt_dan_akses.sql` — perhitungan nilai CBT yang benar, RPC soal
   tanpa kunci jawaban, policy kategori biaya untuk orang tua/siswa.
9. Ulangi untuk `0006_aksi_dan_audit.sql` — policy guru untuk upsert presensi,
   trigger audit log otomatis pada 10 tabel sensitif.
10. Ulangi untuk `0007_chat_rls_fix.sql` — perbaikan RLS chat yang rekursi
    (`42P17 infinite recursion`), ekstensi pgcrypto untuk presensi QR.

**Cara lebih cepat:** pakai `supabase/migrations/ALL_IN_ONE.sql` (semua 7 migrasi
digabung berurutan) — cukup sekali paste lalu Run.

> **Status 18 Okt 2026**: backend YP79 sudah LIVE di project
> `kqkemiuqyfhqbwlgguqg` — hasil verifikasi: **59/59 tabel OK**, 235 policy RLS,
> 19 fungsi, seed lengkap. Kalau membuat project baru, jalankan migrasi di atas
> dari nol; kalau memakai project lama, jalankan `RESET_DESTRUCTIVE.sql` dulu
> (perintah lengkap ada di `docs/AUDIT.md` §3A).
>
> **Catatan**: URL Supabase lama (`yukqngrtgevveimhrwke.supabase.co`) sudah
> **tidak ada** (DNS: non-existent domain).

Semua tabel, RLS policies, dan functions harus sukses. Jika ada error, selesaikan terlebih dahulu sebelum lanjut.

> **Penting**: Jangan jalankan 0002 sebelum 0001, karena RLS mengacu ke tabel yang dibuat di 0001.

## 3. Setup `.env` (Root Project)

Buat file `.env` di root `yp79-terpadu/` (sudah di-gitignore otomatis oleh .gitignore Flutter):

```
SUPABASE_URL=https://kqkemiuqyfhqbwlgguqg.supabase.co
SUPABASE_ANON_KEY=<publishable/anon key dari Supabase Dashboard → Project Settings → API>
```

CI APK menyuntikkan kedua nilai itu lewat `--dart-define` dari GitHub Secrets
(`SUPABASE_URL`, `SUPABASE_ANON_KEY`) — sudah terisi untuk repo ini, jadi APK
hasil build langsung tersambung ke database.

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
| `KEYSTORE_BASE64` | Base64 dari `yp79-release.keystore` (**rotasi keystore lama — pernah ter-push ke repo publik**) |
| `KEYSTORE_PASSWORD` | Password keystore |
| `KEYSTORE_KEYPASSWORD` | Password alias |
| `KEYSTORE_ALIAS` | Nama alias (biasanya `yp79-release`) |
| `SUPABASE_URL` | URL project Supabase baru |
| `SUPABASE_ANON_KEY` | Publishable/anon key project baru (bukan `sb_secret_`, bukan `sbp_`) |

Tanpa 4 secret keystore, CI tetap menghasilkan APK (varian debug ditandatangani
debug key) supaya build tidak pernah gagal total. Tanpa 2 secret Supabase, APK
ter-build tetapi berjalan tanpa backend dan mencetak peringatan di log CI.

## 8. Status Integrasi Eksternal

### Firebase / Google Sign-In — fingerprint SHA

Firebase memakai SHA-1 (+ SHA-256) dari **sertifikat penanda tangan APK**. Kalau
SHA-nya berubah, Google Sign-In dan Firebase Analytics/Crashlytics menolak app.

APK harus selalu ditandatangani dengan **satu keystore rilis tetap**. Sejak
18 Okt 2026 CI memakai keystore rilis yang disimpan sebagai GitHub Secret, jadi
SHA-nya **stabil untuk setiap update**:

```
package name : com.yp79terpadu.app
SHA-1        : EB:87:FD:8C:13:D8:CC:81:DA:D0:7E:35:7C:D0:3F:75:60:F2:A6:09
SHA-256      : 1F:E0:2D:E0:B4:CA:77:BE:75:7F:F4:B6:81:74:A9:59:BF:0C:C3:04:5D:9E:20:48:33:B9:3D:15:84:3F:DB:2F
```

Daftarkan **kedua** fingerprint di Firebase → Project Settings → Your apps →
Android app → Add fingerprint, lalu **unduh ulang `google-services.json`** dan
timpa `android/app/google-services.json` (file lama masih punya
`"oauth_client": []` sehingga Google Sign-In tidak mungkin jalan).

Fingerprint debug lokal (untuk `flutter run` di PC, opsional):
`70:29:7A:88:5C:65:1E:29:50:14:C9:B2:B5:4A:05:78:35:53:BF:58`

Cara memeriksa SHA dari APK mana pun (tanpa JDK):
`python tools/apk_signer.py <file.apk>`

### Modul lain

| Modul | Status | Keterangan |
|---|---|---|
| QR Presensi | Siap | Gunakan `generate_attendance_qr` RPC. Token sekali pakai, hash disimpan server. |
| RFID | Menunggu perangkat | Tunggu integrasi reader fisik. Struktur `attendance_method='rfid'` sudah ada. |
| Push Notification | Menunggu FCM setup | Supabase Realtime tersedia. Push FCM butuh konfigurasi Firebase di aplikasi + webhook. |
| GPS Bus | Siap (telemetry) | `vehicle_locations` menerima koordinat dari device GPS/telemetry. Tanpa kredensial external, tampilkan "posisi belum tersedia". |
| Pembayaran | Nonaktif | Sesuai keputusan Anda, pembayaran via aplikasi dihapus. Modul keuangan hanya menampilkan `finance_items` (jenis biaya + nominal) sebagai informasi, tanpa transaksi. |

## 9. Backup

Di Supabase Dashboard → **Database → Backups**, atur interval backup otomatis. Skema dan data semua tersimpan di Postgres. Jika perlu migrasi antar project, export seluruh skema + data via `pg_dump` atau Supabase Dashboard → **Database → Export**.
