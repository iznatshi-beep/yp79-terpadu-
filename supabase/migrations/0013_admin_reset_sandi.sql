-- =============================================================================
-- 0013 — PERBAIKAN ADMIN: RESET SANDI + FORM BUAT AKUN
-- =============================================================================
-- 1. admin_reset_password: fungsi lama memanggil public.reset_password_email()
--    yang TIDAK ADA (error 42883 di aplikasi). SMTP juga belum pasti aktif,
--    jadi sekarang admin menyetel kata sandi BARU secara langsung dan
--    menyampaikannya ke pengguna (dihasilkan acak di server).
-- 2. admin_create_user: samakan tipe p_role (public.user_role) di semua
--    pemanggilan; p_kelas_id text -> uuid eksplisit agar 42804 tidak muncul
--    lagi ketika klien mengirim string.
-- =============================================================================

create or replace function public.admin_reset_password(
  p_email text,
  p_redirect text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_id uuid;
  v_baru text;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh reset kata sandi.'
      using errcode = '42501';
  end if;

  select id into v_id
    from auth.users
   where lower(email) = lower(btrim(p_email))
     and is_sso_user = false;
  if v_id is null then
    raise exception 'Email % tidak terdaftar.', p_email
      using errcode = 'P0002';
  end if;

  -- Akun Google (SSO) tidak memakai kata sandi lokal.
  if exists (
    select 1 from auth.identities i
     where i.user_id = v_id and i.provider <> 'email'
  ) then
    raise exception 'Akun % masuk lewat Google, tidak perlu kata sandi.', p_email
      using errcode = 'P0001';
  end if;

  v_baru := 'yp79-' || substr(
    md5(random()::text || clock_timestamp()::text || v_id::text), 1, 10);

  update auth.users
     set encrypted_password = extensions.crypt(v_baru, extensions.gen_salt('bf'))
   where id = v_id;

  perform public.catat_audit('reset_sandi', 'auth.users', v_id::text, null);

  return jsonb_build_object(
    'email', lower(btrim(p_email)),
    'password_baru', v_baru);
end;
$$;

-- ---------------------------------------------------------------------------
-- admin_set_relasi_ortu / admin_hapus_user / admin_set_aktif sudah aman
-- (uuid langsung). Tidak diubah.
-- ---------------------------------------------------------------------------
