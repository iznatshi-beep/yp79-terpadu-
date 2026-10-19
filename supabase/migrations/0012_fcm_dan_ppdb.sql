-- 0012 - PUSH TOKEN (FCM) + PPDB + BROADCAST PENGUMUMAN

-- =============================================================
-- 1. PUSH TOKEN (FCM)
--    Satu baris per token perangkat. Dipanggil RPC dari aplikasi
--    setelah pengguna masuk / token berputar.
-- =============================================================
create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null default 'android',
  terakhir_dilihat timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.push_tokens enable row level security;

drop policy if exists push_token_milik_sendiri on public.push_tokens;
create policy push_tokens_milik_sendiri on public.push_tokens
  for all to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid());

create or replace function public.simpan_push_token(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Belum masuk.' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_token, '')), '') is null then
    raise exception 'Token kosong.';
  end if;

  insert into public.push_tokens (token, user_id, platform)
  values (btrim(p_token), auth.uid(), 'android')
  on conflict (token) do update
    set user_id = excluded.user_id,
        terakhir_dilihat = now();

  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.simpan_push_token(text) from public, anon;
grant execute on function public.simpan_push_token(text) to authenticated;

-- =============================================================
-- 2. BROADCAST PENGUMUMAN (admin menerbitkan)
-- ============================================================
create or replace function public.terbitkan_pengumuman(
  p_judul text, p_isi text, p_kategori text default 'umum',
  p_prioritas text default 'biasa', p_target text default 'semua'
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh menerbitkan pengumuman.'
      using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_judul, '')), '') is null
     or nullif(btrim(coalesce(p_isi, '')), '') is null then
    raise exception 'Judul dan isi pengumuman wajib diisi.';
  end if;
  if p_prioritas not in ('biasa', 'penting', 'darurat') then
    raise exception 'Prioritas harus biasa, penting, atau darurat.';
  end if;

  insert into public.announcements
    (dibuat_oleh, judul, isi, kategori, prioritas, target_penerbitan,
     dipublikasikan_pada, status)
  values (auth.uid(), btrim(p_judul), btrim(p_isi), p_kategori, p_prioritas,
          p_target, now(), 'terbit')
  returning id into v_id;

  perform public.catat_audit('terbitkan_pengumuman', 'announcements',
    v_id::text, jsonb_build_object('judul', p_judul, 'prioritas', p_prioritas));

  return jsonb_build_object('id', v_id);
end $$;

revoke all on function public.terbitkan_pengumuman(text, text, text, text, text)
  from public, anon;
grant execute on function public.terbitkan_pengumuman(text, text, text, text, text)
  to authenticated;

-- =============================================================
-- PPDB: nomor registrasi otomatis, verifikasi, hasil
-- =============================================================
create or replace function public.ppdb_daftar(
  p_nama text, p_nisn text default null, p_jk text default null,
  p_tgl_lahir date default null, p_asal text default null,
  p_jenjang text default null, p_ortu_nama text default null,
  p_ortu_hubungan text default null, p_ortu_hp text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_nomor text;
  v_urut int;
begin
  if nullif(btrim(coalesce(p_nama, '')), '') is null then
    raise exception 'Nama calon siswa wajib diisi.';
  end if;

  select coalesce(max(substring(nomor_registrasi from '[0-9]+$')::int), 0) + 1
    into v_urut
    from public.admissions
   where nomor_registrasi like 'PPDB-' || to_char(now(), 'YYYY') || '-%';

  v_nomor := 'PPDB-' || to_char(now(), 'YYYY') || '-' || lpad(v_urut::text, 4, '0');

  insert into public.admissions (nomor_registrasi, nama_calon, nisn_calon,
    jenis_kelamin, tanggal_lahir, asal_sekolah, jenjang, status)
  values (v_nomor, btrim(p_nama), p_nisn, p_jk, p_tgl, p_asal, p_jenjang, 'draf')
  returning id into v_id;

  if nullif(btrim(coalesce(p_ortu_nama, '')), '') is not null then
    insert into public.admission_parents (admission_id, nama, hubungan, no_hp)
    values (v_id, btrim(p_ortu_nama),
            coalesce(nullif(btrim(coalesce(p_ortu_hubungan, '')), ''), 'wali'),
            p_ortu_hp);
  end if;

  return jsonb_build_object('id', v_id, 'nomor_registrasi', v_nomor);
end $$;

create or replace function public.ppdb_set_status(p_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh mengubah status PPDB.'
      using errcode = '42501';
  end if;
  update public.admissions set status = p_status, updated_at = now()
   where id = p_id;
  if not found then
    raise exception 'Pendaftar tidak ditemukan.';
  end if;
  perform public.catat_audit('ppdb_set_status', 'admissions', p_id::text,
                             jsonb_build_object('status', p_status));
  return jsonb_build_object('id', p_id, 'status', p_status);
end $$;

create or replace function public.ppdb_set_hasil(
  p_id uuid, p_hasil text, p_publikasi boolean default false
) returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare v_status_adm text;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh menetapkan hasil PPDB.'
      using errcode = '42501';
  end if;
  if p_hasil not in ('lolos', 'tidak_lolos') then
    raise exception 'Hasil harus lolos atau tidak_lolos.';
  end if;

  insert into public.admission_results (admission_id, hasil, published, ditetapkan_oleh)
  values (p_id, p_hasil, p_publikasi, auth.uid());

  v_status_adm := case when p_hasil = 'lolos' then 'lolos' else 'tidak_lolos' end;
  update public.admissions set status = v_status_adm where id = p_id;

  perform public.catat_audit('ppdb_hasil', 'admission_results',
    p_id::text, jsonb_build_object('hasil', p_hasil));
  return jsonb_build_object('id', p_id, 'hasil', p_hasil);
end $$;

revoke all on function public.ppdb_set_status(uuid, text) from public, anon;
revoke all on function public.ppdb_set_hasil(uuid, text, boolean) from public, anon;
grant execute on function public.ppdb_set_status(uuid, text) to authenticated;
grant execute on function public.ppdb_set_hasil(uuid, text, boolean) to authenticated;

-- Formulir PPDB publik: anon boleh mendaftar.
grant execute on function public.ppdb_daftar(text, text, text, date, text, text,
  text, text, text) to anon, authenticated;

-- RLS: pendaftar PPDB dapat dibaca siapa saja yang sudah masuk (admin
-- memerlukan akses penuh), menulis hanya admin.
alter table public.push_tokens enable row level security;
do $$
declare p record;
begin
  for p in select policyname from pg_policies
           where schemaname='public' and tablename='admissions'
  loop
    execute format('drop policy if exists %I on public.admissions', p.policyname);
  end loop;
end $$;
create policy admissions_baca on public.admissions
  for select to authenticated using (true);
create policy admissions_tulis_admin on public.admissions
  for all to authenticated using (public.is_admin())
  with check (public.is_admin());

alter table public.admission_documents enable row level security;
alter table public.admission_parents enable row level security;
alter table public.admission_results enable row level security;

do $$
declare t text;
begin
  foreach t in array array['admission_documents','admission_parents','admission_results']
  loop
    execute format('create policy %I on public.%I for select to authenticated using (true)',
      t || '_baca', t);
    execute format('create policy %I on public.%I for all to authenticated
                     using (public.is_admin()) with check (public.is_admin())',
                   t || '_tulis_admin', t);
  end loop;
end $$;

-- Publikasi hasil PPDB harus bisa dibaca pendaftar (anon) lewat form status.
create policy admission_results_baca_publik on public.admission_results
  for select to authenticated using (published = true or public.is_admin());

insert into public.schema_migrations (versi) values ('0012_fcm_dan_ppdb')
on conflict (versi) do nothing;
