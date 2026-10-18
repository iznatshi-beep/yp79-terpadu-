-- ============================================================================
--   PERINGATAN KERAS — FILE INI MENGHAPUS DATA
-- ============================================================================
-- File ini SENGAJA diberi nama RESET_DESTRUCTIVE.sql (bukan 000*.sql) supaya
-- TIDAK ikut ter-apply otomatis oleh:
--   - tools/deploy_supabase.py            (hanya ambil 000*.sql)
--   - .github/workflows/migrate-db.yml    (hanya ambil 000*.sql)
--   - supabase/migrations/ALL_IN_ONE.sql  (hanya berisi 0001..0006)
--
-- JANGAN dijalankan kecuali Anda BENAR-BENAR ingin mengosongkan schema `public`
-- pada project Supabase target. Semua tabel, data, policy, dan fungsi di
-- schema public akan HILANG. User di `auth.users` TIDAK dihapus, tetapi
-- profilenya hilang.
--
-- Gunanya: menyiapkan project "aplikasi lama" agar bisa dipakai ulang yp79
-- tanpa tabel bentrok (school_settings versi lama, dst).
--
-- Cara pakai: jalankan file ini SENDIRIAN, sebelum 0001..0006.
-- ============================================================================

drop schema if exists public cascade;
create schema public;

-- Kembalikan grant standar Supabase setelah schema dibuat ulang.
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on all tables in schema public to postgres, anon, authenticated, service_role;
grant all on all routines in schema public to postgres, anon, authenticated, service_role;
grant all on all sequences in schema public to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on routines to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to postgres, anon, authenticated, service_role;

-- Catatan: trigger `on_auth_user_created` pada auth.users ikut terhapus
-- (karena bergantung pada fungsi public.handle_new_user). Migrasi 0002
-- membuatnya kembali dengan `drop trigger if exists` + `create trigger`,
-- jadi cukup jalankan 0001..0006 setelah file ini.
