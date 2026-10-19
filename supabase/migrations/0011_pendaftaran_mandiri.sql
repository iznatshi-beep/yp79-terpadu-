-- 0011 - PEMILIHAN PERAN SETELAH LOGIN + PENDAFTARAN MANDIRI
-- Alur client: login email/Google dulu, SETELAH itu pilih peran (Siswa/Orang
-- Tua/Guru/Admin) tiap kali masuk. Pilihan = tampilan sesi ini; peran resmi
-- tetap di profiles.role (tidak bisa dinaikkan dari UI).
-- Pendaftaran mandiri: hanya Siswa/Orang Tua, status 'menunggu' sampai
-- admin menyetujui.

alter table public.profiles
  add column if not exists status_verifikasi text not null default 'aktif';

-- Pendaftaran mandiri (email+sandi): peran hanya siswa/orang_tua, status menunggu.
create or replace function public.daftar_sendiri(
  p_email text, p_password text, p_nama text, p_role text,
  p_identitas text default null, p_hubungan text default null
) returns jsonb language plpgsql security definer
set search_path = public, auth, extensions as $$
declare
  v_id uuid;
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_nama text := nullif(btrim(coalesce(p_nama, '')), '');
begin
  if p_role not in ('siswa', 'orang_tua') then
    raise exception 'Pendaftaran mandiri hanya untuk peran Siswa atau Orang Tua.'
      using errcode = '42501';
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Format email tidak valid.';
  end if;
  if length(coalesce(p_password, '')) < 8 then
    raise exception 'Kata sandi minimal 8 karakter.';
  end if;
  if v_nama is null then
    raise exception 'Nama wajib diisi.';
  end if;
  if exists (select 1 from public.profiles
             where lower(email) = v_email and status_verifikasi = 'aktif') then
    raise exception 'Email ini sudah terdaftar. Silakan masuk atau lupa kata sandi.';
  end if;

  v_id := public.buat_akun_auth(v_email, p_password, p_role::public.user_role,
                                coalesce(v_nama, split_part(v_email, '@', 1)));
  update public.profiles set status_verifikasi = 'menunggu' where id = v_id;

  if p_role = 'siswa' then
    insert into public.student_profiles (user_id, nis, nama_lengkap)
    values (v_id, coalesce(nullif(btrim(coalesce(p_identitas, '')), ''),
                           'BELUM-' || substr(v_id::text, 1, 8)),
            coalesce(v_nama, 'Siswa'))
    on conflict (user_id) do nothing;
  else
    insert into public.parent_profiles (user_id, nama_lengkap, hubungan)
    values (v_id, v_nama, coalesce(nullif(btrim(p_hubungan), ''), 'wali'))
    on conflict (user_id) do nothing;
  end if;

  perform public.catat_audit('pendaftaran_mandiri', 'profiles', v_id::text,
    jsonb_build_object('role', p_role, 'email', v_email));

  return jsonb_build_object('user_id', v_id, 'status', 'menunggu');
end $$;

-- Admin menyetujui / menolak pendaftar mandiri.
create or replace function public.admin_set_status_pendaftar(
  p_user_id uuid, p_status text
) returns jsonb language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh menyetujui pendaftar.'
      using errcode = '42501';
  end if;
  if p_status not in ('aktif', 'ditolak') then
    raise exception 'Status harus aktif atau ditolak.';
  end if;

  update public.profiles set status_verifikasi = p_status where id = p_user_id;
  if not found then
    raise exception 'Profil pengguna tidak ditemukan.';
  end if;

  update auth.users
     set banned_until = case when p_status = 'ditolak'
                             then now() + interval '100 years' else null end,
         updated_at = now()
   where id = p_user_id;

  perform public.catat_audit('set_status_pendaftar', 'profiles', p_user_id::text,
                             jsonb_build_object('status', p_status));
  return jsonb_build_object('user_id', p_user_id, 'status', p_status);
end $$;

-- Pengguna memilih peran untuk SESI INI (hanya laporan; peran resmi tidak diubah).
create or replace function public.pilih_peran_sesi(p_role text)
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'ok', true,
    'peran_resmi', (select role::text from public.profiles where id = auth.uid())
  );
$$;

revoke all on function public.admin_set_status_pendaftar(uuid, text) from public, anon;
grant execute on function public.admin_set_status_pendaftar(uuid, text) to authenticated;
grant execute on function public.daftar_sendiri(text, text, text, text, text, text)
  to anon, authenticated;
grant execute on function public.pilih_peran_sesi(text) to authenticated;

insert into public.schema_migrations (versi) values ('0011_pilih_peran_dan_daftar')
on conflict (versi) do nothing;
