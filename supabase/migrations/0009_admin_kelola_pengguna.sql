-- =============================================================================
-- 0009 — ADMIN DAPAT MEMBUAT & MENGELOLA AKUN PENGGUNA
-- =============================================================================
-- Sebelum ini tidak ada satu pun jalan untuk membuat akun dari aplikasi: akun
-- hanya bisa lahir dari SQL manual, sedangkan halaman login dengan benar
-- menolak pendaftaran mandiri ("akun dibuat pihak sekolah"). Akibatnya sekolah
-- tidak bisa memakai aplikasinya sendiri.
--
-- Yang ditambahkan di sini:
--   1. admin_create_user   — admin membuat akun (email + kata sandi awal).
--   2. admin_set_role      — mengubah peran, termasuk mengaktifkan admin lain.
--   3. admin_reset_password— mengirim tautan reset kata sandi ke pengguna.
--   4. admin_set_aktif     — menonaktifkan / mengaktifkan kembali akun.
--   5. admin_hapus_user    — menghapus akun beserta seluruh jejak terkait.
--   6. admin_set_relasi_ortu — menghubungkan akun orang tua ke siswa.
--   7. Kebijakan RLS supaya ADMIN bisa membaca & mengubah seluruh profil,
--      data siswa/orang tua/guru, dan relasi orang tua-anak, serta membaca
--      audit log. Sebelumnya hampir semua tabel hanya punya kebijakan
--      "baca milik sendiri", sehingga halaman Manajemen Pengguna kosong.
--
-- Semua fungsi menolak pemanggil yang bukan admin (diperiksa di sisi server,
-- bukan dari argumen yang dikirim aplikasi) dan menulis jejaknya ke
-- public.audit_logs.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Semua ADMIN boleh membaca seluruh profil (dulu hanya milik sendiri).
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

do $$
declare p record;
begin
  for p in select policyname from pg_policies
           where schemaname = 'public' and tablename = 'profiles'
  loop
    execute format('drop policy if exists %I on public.profiles', p.policyname);
  end loop;
end $$;

create policy profiles_baca_sendiri on public.profiles
  for select using (id = auth.uid() or public.is_admin());

create policy profiles_ubah_admin on public.profiles
  for update using (public.is_admin()) with check (public.is_admin());

-- Pengguna boleh memperbarui namanya sendiri, tetapi TIDAK boleh menaikkan
-- perannya sendiri (peran hanya lewat admin_set_role).
create policy profiles_ubah_nama_sendiri on public.profiles
  for update using (id = auth.uid())
  with check (
    id = auth.uid()
    and role = (select p.role from public.profiles p where p.id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 2. ADMIN boleh mengelola data rinci tiap peran.
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array[
    'student_profiles', 'parent_profiles', 'teacher_profiles', 'parent_student'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);

    for p in select policyname from pg_policies
             where schemaname = 'public' and tablename = t
    loop
      execute format('drop policy if exists %I on public.%I', p.policyname, t);
    end loop;

    -- Semua pengguna yang sudah masuk boleh membaca (halaman guru perlu daftar
    -- nama siswa di kelasnya); yang membatasi data mana yang boleh dilihat
    -- adalah kebijakan per-tabel di modul masing-masing.
    execute format(
      'create policy %I on public.%I for select to authenticated using (true)',
      t || '_baca_semua', t);

    execute format(
      'create policy %I on public.%I for all to authenticated
         using (public.is_admin()) with check (public.is_admin())',
      t || '_tulis_admin', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Audit log: admin boleh membacanya.
-- ---------------------------------------------------------------------------
alter table public.audit_logs enable row level security;

do $$
declare p record;
begin
  for p in select policyname from pg_policies
           where schemaname = 'public' and tablename = 'audit_logs'
  loop
    execute format('drop policy if exists %I on public.audit_logs', p.policyname);
  end loop;
end $$;

create policy audit_logs_baca_admin on public.audit_logs
  for select using (public.is_admin());

-- ---------------------------------------------------------------------------
-- 4. Catatan audit. SECURITY DEFINER supaya tetap bisa menulis walaupun
--    pemanggil tidak punya izin insert ke audit_logs.
-- ---------------------------------------------------------------------------
create or replace function public.catat_audit(
  p_aksi text,
  p_target_table text default null,
  p_target_id text default null,
  p_metadata jsonb default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs (actor_user_id, aksi, target_table, target_id, metadata)
  values (auth.uid(), p_aksi, p_target_table, p_target_id, p_metadata);
end $$;

-- ---------------------------------------------------------------------------
-- 5. Pembantu: buat akun di auth.users + identities.
--    - aud/role wajib diisi 'authenticated';
--    - kolom identitas TIDAK boleh menyertakan `email`, karena kolom itu
--      generated di auth.identities (error 428C9);
--    - kata sandi di-hash bcrypt oleh auth-service;
--    - pgcrypto ada di schema `extensions`, BUKAN `public`. Karena fungsi ini
--      menyetel search_path sendiri (yang menghapus bawaan `extensions`),
--      crypt/gen_salt WAJIB ditulis lengkap — kalau tidak:
--      "function gen_salt(unknown) does not exist" (42883).
-- ---------------------------------------------------------------------------
create or replace function public.buat_akun_auth(
  p_email text, p_password text, p_role public.user_role, p_nama text
) returns uuid language plpgsql security definer
set search_path = public, auth, extensions as $$
declare v_id uuid;
begin
  select id into v_id from auth.users
   where email = lower(p_email) and is_sso_user = false;

  if v_id is null then
    v_id := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      is_sso_user, is_anonymous
    ) values (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
      lower(p_email), extensions.crypt(p_password, extensions.gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('role', p_role::text, 'nama', p_nama),
      '', '', '', '', false, false
    );

    insert into auth.identities
      (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (
      v_id::text, v_id,
      jsonb_build_object('sub', v_id::text, 'email', lower(p_email),
                         'email_verified', true, 'phone_verified', false),
      'email', now(), now(), now()
    );
  else
    update auth.users
       set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
           email_confirmed_at = coalesce(email_confirmed_at, now()),
           raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
                                || jsonb_build_object('role', p_role::text, 'nama', p_nama)
     where id = v_id;
  end if;

  return v_id;
end $$;

-- ---------------------------------------------------------------------------
-- 6. admin_create_user — satu-satunya jalan sah membuat akun dari aplikasi.
-- ---------------------------------------------------------------------------
create or replace function public.admin_create_user(
  p_email text,
  p_nama text,
  p_role public.user_role,
  p_password text,
  p_identitas text default null,
  p_kelas_id uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_nama text := nullif(btrim(coalesce(p_nama, '')), '');
  v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh membuat akun.'
      using errcode = '42501';
  end if;

  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Format email tidak valid.';
  end if;

  if v_nama is null then
    raise exception 'Nama pengguna wajib diisi.';
  end if;

  -- Kata sandi awal minimal 8 karakter dan harus diketik ulang oleh admin,
  -- jadi tidak ada kata sandi bawaan yang selalu sama.
  if length(coalesce(p_password, '')) < 8 then
    raise exception 'Kata sandi awal minimal 8 karakter.';
  end if;

  -- Data identitas wajib untuk siswa (NIS dipakai di banyak modul).
  if p_role = 'siswa' and nullif(btrim(coalesce(p_identitas, '')), '') is null then
    raise exception 'NIS wajib diisi untuk akun siswa.';
  end if;

  -- Ambil dulu id akun yang sudah ada (kalau ada) sebelum memeriksa bentrok
  -- email. Versi sebelumnya memakai coalesce(..., '0'::uuid) yang membuat
  -- Postgres mengeluh "invalid input syntax for type uuid: 0".
  select u.id into v_id
    from auth.users u
   where lower(u.email) = v_email and u.is_sso_user = false;

  -- Jangan izinkan email yang sudah dipakai profil LAIN; salah pilih akun
  -- bisa membuat data satu orang menimpa orang lain.
  if exists (
    select 1 from public.profiles p
     where lower(p.email) = v_email
       and (v_id is null or p.id <> v_id)
  ) then
    raise exception 'Email % sudah dipakai akun lain.', v_email;
  end if;

  perform public.buat_akun_auth(v_email, p_password, p_role, v_nama);

  if v_id is null then
    select u.id into v_id
      from auth.users u
     where lower(u.email) = v_email and u.is_sso_user = false;
  end if;

  insert into public.profiles (id, role, nama, email)
  values (v_id, p_role, v_nama, v_email)
  on conflict (id) do update
    set role = excluded.role, nama = excluded.nama, email = excluded.email;

  if p_role = 'siswa' then
    insert into public.student_profiles (user_id, nis, nama_lengkap, kelas_id)
    values (v_id, btrim(p_identitas), v_nama, p_kelas_id)
    on conflict (user_id) do update
      set nis = excluded.nis, nama_lengkap = excluded.nama_lengkap,
          kelas_id = coalesce(excluded.kelas_id, public.student_profiles.kelas_id);

  elsif p_role = 'orang_tua' then
    insert into public.parent_profiles (user_id, nama_lengkap)
    values (v_id, v_nama)
    on conflict (user_id) do update set nama_lengkap = excluded.nama_lengkap;

  else
    -- guru, guru_pembimbing, admin
    insert into public.teacher_profiles (user_id, nama_lengkap, nip)
    values (v_id, v_nama, nullif(btrim(coalesce(p_identitas, '')), ''))
    on conflict (user_id) do update
      set nama_lengkap = excluded.nama_lengkap,
          nip = coalesce(excluded.nip, public.teacher_profiles.nip);
  end if;

  perform public.catat_audit(
    'buat_akun', 'profiles', v_id::text,
    jsonb_build_object('role', p_role::text, 'email', v_email, 'nama', v_nama));

  return jsonb_build_object('user_id', v_id, 'email', v_email, 'role', p_role::text);
end $$;

-- ---------------------------------------------------------------------------
-- 7. admin_set_role — pindah peran (mis. guru menjadi guru pembimbing).
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_role(
  p_user_id uuid, p_role public.user_role, p_identitas text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_lama text;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh mengubah peran.'
      using errcode = '42501';
  end if;

  if p_user_id = auth.uid() and p_role <> 'admin' then
    raise exception 'Tidak bisa menurunkan peran akun sendiri. '
                    'Minta admin lain melakukannya.';
  end if;

  select role::text into v_lama from public.profiles where id = p_user_id;
  if v_lama is null then
    raise exception 'Profil pengguna tidak ditemukan.';
  end if;

  update public.profiles set role = p_role where id = p_user_id;

  if p_role = 'siswa' then
    if nullif(btrim(coalesce(p_identitas, '')), '') is null
       and not exists (select 1 from public.student_profiles where user_id = p_user_id)
    then
      raise exception 'NIS wajib diisi saat mengubah akun menjadi siswa.';
    end if;
    insert into public.student_profiles (user_id, nis, nama_lengkap)
    select p_user_id, coalesce(nullif(btrim(p_identitas), ''), '-'),
           coalesce((select nama from public.profiles where id = p_user_id), '-')
    on conflict (user_id) do nothing;
  elsif p_role = 'orang_tua' then
    insert into public.parent_profiles (user_id, nama_lengkap)
    select p_user_id, coalesce((select nama from public.profiles where id = p_user_id), '-')
    on conflict (user_id) do nothing;
  elsif p_role in ('guru', 'guru_pembimbing', 'admin') then
    insert into public.teacher_profiles (user_id, nama_lengkap, nip)
    select p_user_id, coalesce((select nama from public.profiles where id = p_user_id), '-'),
           nullif(btrim(coalesce(p_identitas, '')), '')
    on conflict (user_id) do update
      set nip = coalesce(excluded.nip, public.teacher_profiles.nip);
  end if;

  perform public.catat_audit(
    'ubah_peran', 'profiles', p_user_id::text,
    jsonb_build_object('dari', v_lama, 'menjadi', p_role::text));

  return jsonb_build_object('user_id', p_user_id, 'role_lama', v_lama,
                            'role_baru', p_role::text);
end $$;

-- ---------------------------------------------------------------------------
-- 8. admin_reset_password — kirim tautan reset (bukan menetapkan sandi baru).
--    Tautan hanya sah bila konfigurasi SMTP/Site URL Supabase sudah benar.
-- ---------------------------------------------------------------------------
create or replace function public.admin_reset_password(p_email text, p_redirect text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh mengirim tautan reset.'
      using errcode = '42501';
  end if;

  perform public.reset_password_email(lower(btrim(p_email)), '', p_redirect);

  perform public.catat_audit('kirim_reset_sandi', 'auth.users', p_email, null);

  return jsonb_build_object(
    'email', lower(btrim(p_email)),
    'catatan', 'Tautan reset dikirim bila SMTP/Site URL Supabase sudah diatur.');
end $$;

-- ---------------------------------------------------------------------------
-- 9. admin_set_aktif — nonaktifkan / aktifkan kembali akun.
--    Supabase menonaktifkan akun lewat `banned_until` di masa depan.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_aktif(p_user_id uuid, p_aktif boolean)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh mengaktifkan/menonaktifkan akun.'
      using errcode = '42501';
  end if;

  if p_user_id = auth.uid() and not p_aktif then
    raise exception 'Tidak bisa menonaktifkan akun sendiri.';
  end if;

  -- Tanpa pemeriksaan ini, fungsi melaporkan sukses walau tidak ada baris yang
  -- berubah (mis. id salah) — admin mengira akun sudah dinonaktifkan padahal
  -- belum. Jangan pernah melaporkan keberhasilan yang tidak terjadi.
  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'Profil pengguna tidak ditemukan.';
  end if;

  if not p_aktif and exists (
    select 1 from public.profiles
     where id = p_user_id and role = 'admin'
  ) and (select count(*) from public.profiles where role = 'admin') <= 1 then
    raise exception 'Ini satu-satunya akun admin. Buat admin lain dulu.';
  end if;

  update auth.users
     set banned_until = case when p_aktif then null else now() + interval '100 years' end,
         updated_at = now()
   where id = p_user_id;

  if not found then
    raise exception 'Akun tidak ditemukan di auth.users.';
  end if;

  perform public.catat_audit(
    case when p_aktif then 'aktifkan_akun' else 'nonaktifkan_akun' end,
    'auth.users', p_user_id::text, null);

  return jsonb_build_object('user_id', p_user_id, 'aktif', p_aktif);
end $$;

-- ---------------------------------------------------------------------------
-- 10. admin_hapus_user — hapus akun beserta jejaknya.
--     Urutan penting: tabel an demo/operasional lebih dulu, profil terakhir.
--     Baris yang tidak ada tabelnya dilewati, jadi fungsi tetap jalan walau
--     modulnya belum dipakai.
-- ---------------------------------------------------------------------------
create or replace function public.admin_hapus_user(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  v_email text;
  v_role  text;
  t text;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh menghapus akun.'
      using errcode = '42501';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'Tidak bisa menghapus akun sendiri.';
  end if;

  select email, role::text into v_email, v_role
    from public.profiles where id = p_user_id;
  if v_email is null then
    raise exception 'Profil pengguna tidak ditemukan.';
  end if;

  if v_role = 'admin'
     and (select count(*) from public.profiles where role = 'admin') <= 1 then
    raise exception 'Ini satu-satunya akun admin dan tidak boleh dihapus.';
  end if;

  -- Relasi orang tua <-> siswa (dua arah).
  delete from public.parent_student
   where parent_user_id = p_user_id or student_user_id = p_user_id;

  -- Data rinci per peran.
  foreach t in array array[
    'student_profiles', 'parent_profiles', 'teacher_profiles'
  ]
  loop
    execute format('delete from public.%I where user_id = $1', t) using p_user_id;
  end loop;

  -- Data operasional milik pengguna (hanya tabel yang benar-benar ada).
  foreach t in array array[
    'leave_requests', 'attendance_records', 'grading_records', 'assignment_submissions',
    'exam_attempts', 'library_loans', 'book_reservations', 'mutabaah_entries',
    'memorization_targets', 'memorization_submissions', 'consent_responses',
    'appointments', 'notifications', 'notification_preferences', 'user_settings',
    'chat_messages', 'conversation_members', 'admission_applicants'
  ]
  loop
    if exists (select 1 from information_schema.tables
                where table_schema = 'public' and table_name = t)
       and exists (select 1 from information_schema.columns
                    where table_schema = 'public' and table_name = t
                      and column_name = 'user_id')
    then
      execute format('delete from public.%I where user_id = $1', t) using p_user_id;
    end if;
  end loop;

  delete from public.profiles where id = p_user_id;
  delete from auth.identities where user_id = p_user_id;
  delete from auth.users where id = p_user_id;

  perform public.catat_audit(
    'hapus_akun', 'profiles', p_user_id::text,
    jsonb_build_object('email', v_email, 'role', v_role));

  return jsonb_build_object('dihapus', true, 'email', v_email);
end $$;

-- ---------------------------------------------------------------------------
-- 11. admin_set_relasi_ortu — hubungkan akun orang tua ke siswa.
--     Owner (auth.uid()) menjadi pencatat audit, bukan parameter pemanggil.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_relasi_ortu(
  p_parent_id uuid, p_student_id uuid, p_hubungan text default 'wali',
  p_verifikasi boolean default true
) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh mengatur relasi orang tua.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles where id = p_parent_id and role = 'orang_tua') then
    raise exception 'Akun orang tua tidak ditemukan.';
  end if;
  if not exists (select 1 from public.profiles where id = p_student_id and role = 'siswa') then
    raise exception 'Akun siswa tidak ditemukan.';
  end if;

  insert into public.parent_student (parent_user_id, student_user_id, hubungan, diverifikasi)
  values (p_parent_id, p_student_id, coalesce(nullif(btrim(p_hubungan), ''), 'wali'), p_verifikasi)
  on conflict (parent_user_id, student_user_id) do update
    set hubungan = excluded.hubungan, diverifikasi = excluded.diverifikasi;

  perform public.catat_audit(
    'atur_relasi_ortu', 'parent_student',
    p_parent_id::text || '->' || p_student_id::text,
    jsonb_build_object('hubungan', p_hubungan, 'diverifikasi', p_verifikasi));

  return jsonb_build_object('parent_user_id', p_parent_id, 'student_user_id', p_student_id);
end $$;

create or replace function public.admin_hapus_relasi_ortu(p_parent_id uuid, p_student_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh mengubah relasi orang tua.'
      using errcode = '42501';
  end if;

  delete from public.parent_student
   where parent_user_id = p_parent_id and student_user_id = p_student_id;

  perform public.catat_audit('hapus_relasi_ortu', 'parent_student',
    p_parent_id::text || '->' || p_student_id::text, null);

  return jsonb_build_object('dihapus', true);
end $$;

-- ---------------------------------------------------------------------------
-- 12. Daftar kelas (dipakai halaman Manajemen Pengguna saat membuat siswa).
-- ---------------------------------------------------------------------------
create or replace function public.list_kelas()
returns table (id uuid, nama text, jenjang text, tahun_ajaran text)
language sql security definer set search_path = public as $$
  select k.id, k.nama, k.jenjang, k.tahun_ajaran from public.classes k order by k.nama;
$$;

-- ---------------------------------------------------------------------------
-- 13. Hak eksekusi: hanya pengguna yang sudah masuk (admin diperiksa di dalam).
-- ---------------------------------------------------------------------------
revoke all on function public.buat_akun_auth(text, text, public.user_role, text) from public, anon;
revoke all on function public.admin_create_user(text, text, public.user_role, text, text, uuid) from public, anon;
revoke all on function public.admin_set_role(uuid, public.user_role, text) from public, anon;
revoke all on function public.admin_reset_password(text, text) from public, anon;
revoke all on function public.admin_set_aktif(uuid, boolean) from public, anon;
revoke all on function public.admin_hapus_user(uuid) from public, anon;
revoke all on function public.admin_set_relasi_ortu(uuid, uuid, text, boolean) from public, anon;
revoke all on function public.admin_hapus_relasi_ortu(uuid, uuid) from public, anon;

grant execute on function public.admin_create_user(text, text, public.user_role, text, text, uuid) to authenticated;
grant execute on function public.admin_set_role(uuid, public.user_role, text) to authenticated;
grant execute on function public.admin_reset_password(text, text) to authenticated;
grant execute on function public.admin_set_aktif(uuid, boolean) to authenticated;
grant execute on function public.admin_hapus_user(uuid) to authenticated;
grant execute on function public.admin_set_relasi_ortu(uuid, uuid, text, boolean) to authenticated;
grant execute on function public.admin_hapus_relasi_ortu(uuid, uuid) to authenticated;
grant execute on function public.list_kelas() to authenticated;

-- ---------------------------------------------------------------------------
-- 14. Status aktif akun (dibaca dari auth.users.banned_until).
--     Tabel `auth` tidak bisa dibaca langsung dari aplikasi.
-- ---------------------------------------------------------------------------
create or replace function public.admin_status_akun()
returns table (user_id uuid, email text, banned_until timestamptz, aktif boolean)
language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh melihat status akun.'
      using errcode = '42501';
  end if;

  return query
    select u.id, u.email, u.banned_until,
           (u.banned_until is null or u.banned_until < now()) as aktif
      from auth.users u
     where u.is_sso_user = false or u.email is not null;
end $$;

revoke all on function public.admin_status_akun() from public, anon;
grant execute on function public.admin_status_akun() to authenticated;

-- ---------------------------------------------------------------------------
-- 15. Penanda: migrasi ini sudah terpasang.
-- ---------------------------------------------------------------------------
create table if not exists public.schema_migrations (
  versi text primary key,
  dipasang_pada timestamptz not null default now()
);
insert into public.schema_migrations (versi) values ('0009_admin_kelola_pengguna')
on conflict (versi) do nothing;
