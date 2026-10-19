-- =============================================================================
-- 0014 — FIX 42804 pada admin_status_akun
-- =============================================================================
-- auth.users.email bertipe varchar(255), sedangkan deklarasi RETURNS TABLE
-- mendeklarasikan kolom email sebagai text. Postgres menolak (42804:
-- "Returned type character varying (255) does not match expected type text
-- in column 2"). Halaman Manajemen Pengguna gagal memuat status akun.
-- Perbaikan: eksplisit cast u.email::text.
-- =============================================================================

create or replace function public.admin_status_akun()
returns table(user_id uuid, email text, banned_until timestamp with time zone, aktif boolean)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh melihat status akun.'
      using errcode = '42501';
  end if;

  return query
    select u.id, u.email::text, u.banned_until,
           (u.banned_until is null or u.banned_until < now()) as aktif
      from auth.users u
     where u.is_sso_user = false or u.email is not null;
end;
$$;
