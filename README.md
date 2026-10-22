# YP79 Terpadu

Aplikasi Android Sekolah Terpadu berbasis **Flutter + Supabase** (Postgres + RLS + Auth).
4 role — **Admin, Guru, Siswa, Orang Tua** — dashboard & modul berbeda per role.

> **Panduan setup lengkap ada di [README-SETUP.md](README-SETUP.md)** — migrasi,
> kredensial, akun admin, FCM push, troubleshooting. README ini ringkasannya.

## Struktur Project

```
yp79-terpadu/
├── lib/                        # Kode Flutter
│   ├── features/               # Per fitur: beranda, lms, cbt, perpus, mabit,
│   │                           #   insiden, izin, keuangan, chat, ppdb, akademik
│   ├── services/               # repositories.dart (data layer), auth_service,
│   │                           #   google_auth, lampiran (upload), fcm
│   ├── core/                   # models (role, session_profile), theme
│   └── widgets/                # app_states, common
├── android/                    # Konfigurasi Android + google-services.json (Firebase)
├── supabase/
│   ├── migrations/             # 0001..0021 SQL + ALL_IN_ONE.sql + RESET_DESTRUCTIVE.sql
│   └── seed/                   # Data awal
├── push-notifier/              # FCM notifier Node.js (fcm.js) — Opsi B tanpa edge function
├── .github/workflows/
│   ├── build.yml               # CI: build APK release → GitHub Release
│   └── migrate-db.yml          # Manual: push migrasi SQL ke Supabase (management-api/psql)
├── tools/                      # apk_signer.py, dll
├── docs/AUDIT.md               # Audit skema + prosedur reset
├── .env                        # Kredensial publik (URL + anon key) — gitignored
└── .secrets/                   # Kredensial rahasia (svc_key, sbp_token, FCM SA) — gitignored
```

## Menjalankan Migrasi Database

**Project baru** — SQL Editor Supabase, berurutan (atau sekali paste `ALL_IN_ONE.sql`):
1. `0001_schema.sql` (tabel — WAJIB dulu)
2. `0002_rls_functions.sql` (RLS, mengacu tabel 0001)
3. `0003_seed.sql` → `0004_fixes.sql` → ... → `0021_incident_reports.sql`

**Cepat:** `supabase/migrations/ALL_IN_ONE.sql` sekali paste → Run.
Alternatif otomatis: Actions → **Migrasi Database Supabase** → Run workflow
(butuh secret `SUPABASE_ACCESS_TOKEN` atau `SUPABASE_DB_URL`).

> **Status 22 Okt 2026**: backend LIVE di project `kqkemiuqyfhqbwlgguqg` —
> 60+ tabel OK, 235 policy RLS, 19 fungsi, seed masuk, migrasi s.d. 0021 terpasang.
> URL Supabase lama (`yukqngrtgevveimhrwke.supabase.co`) sudah tidak ada.

Lalu isi `.env` di root project (lihat `README-SETUP.md` §3).

## Data Sekolah yang Perlu Diisi (agar modul hidup)

Urutan via app (login admin):

1. **Kelas** (`classes`) — wajib pertama; semua modul akademik bergantung padanya.
2. **Mapel** (`subjects`) — 8 sudah ter-seed; tambah bila perlu.
3. **Jadwal** (`schedules`) + penugasan guru (`teacher_assignments`).
4. **Siswa per kelas** — akun dibuat via **Manajemen Pengguna** di app
   (atau Supabase Auth dengan metadata role).
5. **Opsional per modul**: kendaraan (alokasi bus), event MABIT, buku perpus,
   soal CBT, kategori biaya, kalender akademik (`academic_calendar`).

## Akun (Auth)

- **Admin pertama**: dibuat manual di Supabase Dashboard → Authentication →
  Add User + metadata `{"role":"admin","nama":"..."}` — TIDAK lewat app.
- **Siswa/Guru/Orang Tua**: dibuat admin lewat menu **Manajemen Pengguna** di app,
  atau manual di Supabase Auth dengan metadata role masing-masing.
- Google Sign-In: `signInWithIdToken`, Web client ID harus terdaftar sebagai
  `external_google_client_id` di Supabase Auth — detail README-SETUP.md §8.

## Google Sign-In

- Firebase project: `yp79-1793d`, package: `com.yp79terpadu.app`.
- Fingerprint keystore rilis (stabil via CI):
  - SHA-1: `EB:87:FD:8C:13:D8:CC:81:DA:D0:7E:35:7C:D0:3F:75:60:F2:A6:09`
  - SHA-256: `1F:E0:2D:E0:B4:CA:77:BE:75:7F:F4:B6:81:74:A9:59:BF:0C:C3:04:5D:9E:20:48:33:B9:3D:15:84:3F:DB:2F`
  (daftarkan keduanya di Firebase, lalu unduh ulang `google-services.json`).
- SHA-1 debug lokal: `70:29:7A:88:5C:65:1E:29:50:14:C9:B2:B5:4A:05:78:35:53:BF:58`
- Supabase `external_google_client_id` = Web client ID — detail/troubleshooting di README-SETUP.md.

## Build APK

Lokal: `flutter build apk --release` (butuh SDK lokal).

Via GitHub Actions (standar repo ini): push ke `main` → CI build release
+ obfuscate, signing dengan keystore dari GitHub Secrets, upload ke
[GitHub Releases](https://github.com/iznatshi-beep/yp79-terpadu-/releases).
Contoh rilis: `https://github.com/iznatshi-beep/yp79-terpadu-/releases/download/v102/app-release.apk`

Secrets repo: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEYSTORE_KEYPASSWORD`,
`KEYSTORE_ALIAS`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`
(+$`SUPABASE_ACCESS_TOKEN` untuk workflow migrate-db manual).

Tanpa secret keystore → APK debug-signed (build tetap jalan).
Tanpa secret Supabase → APK ter-build tapi tanpa backend.

## Push Notifikasi (FCM)

```bash
npm install          # firebase-admin
node push-notifier/fcm.js
```
Jadwalkan tiap ~1 menit (Task Scheduler Windows / cron). Idempotent via SQLite.
Butuh Node 22+, `.secrets/fcm_service_account.json`, `.secrets/svc_key.txt`.

## Status Integrasi

| Modul | Status | Keterangan |
|---|---|---|
| QR Presensi | Siap | RPC `generate_attendance_qr` — token sekali pakai, hash di server |
| Push FCM | Siap | `push-notifier/fcm.js` + cron 1 menit |
| GPS Bus | Siap (telemetri) | `vehicle_locations`; tanpa data tampil "posisi belum tersedia" |
| RFID | Menunggu perangkat | Struktur `attendance_method='rfid'` sudah ada |
| Pembayaran | Nonaktif | Keuangan hanya info `finance_items` (transfer manual, tanpa transaksi in-app) |

## Kredensial Sensitif

`.secrets/` gitignored: service_role key, token `sbp_`, service account FCM,
keystore — **jangan pernah commit/paste ke chat**; kalau bocor, rotasi segera.
Anon/publishable key di `.env` aman (RLS melindungi data).

## Backup

Supabase Dashboard → Database → Backups. Migrasi antar project via `pg_dump`
atau Dashboard Export. URL lama `yukqngrtgevveimhrwke.supabase.co` sudah mati —
pakai `kqkemiuqyfhqbwlgguqg.supabase.co`.

## Lihat Juga
- `README-SETUP.md` — panduan setup lengkap (migrasi, akun, FCM, troubleshooting)
- `docs/AUDIT.md` — audit skema + prosedur reset `RESET_DESTRUCTIVE.sql`
- `push-notifier/README.md` — dokumentasi FCM notifier
- `.secrets/README.txt` — cara menulis kredensial aman
