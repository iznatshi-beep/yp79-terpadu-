-- =============================================================================
-- 0015 — FIX 42804 pada ppdb_set_status
-- =============================================================================
-- Kolom admissions.status bertipe ENUM ppdb_status, sedangkan parameter
-- p_status bertipe text. `set status = p_status` ditolak Postgres:
-- "column \"status\" is of type ppdb_status but expression is of type text".
-- Perbaikan: cast eksplisit p_status::public.ppdb_status.
--
-- Nilai yang dipakai aplikasi: verifikasi / lolos / tidak_lolos.
-- 'verifikasi' tidak ada di enum -> dipetakan ke 'pemeriksaan' (selesai
-- diperiksa) agar aksi "Tandai Verifikasi" tetap berarti tanpa mengubah
-- skema enum.
-- =============================================================================

create or replace function public.ppdb_set_status(
  p_id uuid,
  p_status text
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_status public.ppdb_status;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh mengubah status PPDB.'
      using errcode = '42501';
  end if;

  v_status := case
    when p_status = 'verifikasi' then 'pemeriksaan'::public.ppdb_status
    else p_status::public.ppdb_status
  end;

  update public.admissions
     set status = v_status, updated_at = now()
   where id = p_id;
  if not found then
    raise exception 'Pendaftar tidak ditemukan.';
  end if;

  perform public.catat_audit('ppdb_set_status', 'admissions', p_id::text,
                             jsonb_build_object('status', v_status::text));
  return jsonb_build_object('id', p_id, 'status', v_status::text);
end;
$$;

-- ppdb_set_hasil juga menulis enum dari text lewat variabel text:
create or replace function public.ppdb_set_hasil(
  p_id uuid,
  p_hasil text,
  p_publikasi boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_status_adm public.ppdb_status;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin sekolah yang boleh menetapkan hasil PPDB.'
      using errcode = '42501';
  end if;
  if p_hasil not in ('lolos', 'tidak_lolos') then
    raise exception 'Hasil harus lolos atau tidak_lolos.';
  end if;

  insert into public.admission_results (admission_id, hasil, published, ditetapkan_oleh)
  values (p_id, p_hasil::public.ppdb_status, p_publikasi, auth.uid());

  v_status_adm := case
    when p_hasil = 'lolos' then 'lolos'::public.ppdb_status
    else 'tidak_lolos'::public.ppdb_status
  end;
  update public.admissions set status = v_status_adm where id = p_id;

  perform public.catat_audit('ppdb_hasil', 'admission_results',
    p_id::text, jsonb_build_object('hasil', p_hasil));
  return jsonb_build_object('id', p_id, 'hasil', p_hasil);
end;
$$;
