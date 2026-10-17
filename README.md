# YP79 Terpadu

Aplikasi Android Sekolah Terpadu berbasis Flutter + Supabase (Postgres + RLS + Auth).

## Struktur

- `lib/` — kode Flutter (UI 4 role, modul presensi, nilai, LMS, CBT, e-book, keuangan, MABIT, chat)
- `supabase/` — skema SQL + RLS + functions + seed
- `android/` — konfigurasi Android, termasuk `google-services.json` (Google Sign-In via Firebase)
- `.github/workflows/build.yml` — CI build APK

## Menjalankan Migrasi Database

Jalankan berturut-turut di SQL Editor Supabase:
1. `supabase/migrations/0001_schema.sql`
2. `supabase/migrations/0002_rls_functions.sql`
3. `supabase/migrations/0003_seed.sql`

Lalu isi `.env` di root project (lihat `README-SETUP.md`).

## Google Sign-In

- Firebase project: `yp79-1793d`
- Android package: `com.yp79terpadu.app`
- SHA-1 debug (mesin developer): `70:29:7A:88:5C:65:1E:29:50:14:C9:B2:B5:4A:05:78:35:53:BF:58`
- SHA-1 release: belum ada — tambahkan setelah keystore release tersedia.

## Build APK

Lokal:
```
flutter build apk --debug
```

Via GitHub Actions: push ke `main`, CI otomatis build & upload artifact. Untuk tanda tangan release, set secrets di repo:
- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEYSTORE_KEYPASSWORD`
- `KEYSTORE_ALIAS`
