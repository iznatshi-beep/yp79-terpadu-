-- =============================================================================
-- 0016 — FIX 42804 pada terbitkan_pengumuman
-- =============================================================================
-- Kolom announcements.target_penerbitan bertipe ENUM notification_target,
-- parameter p_target bertipe text -> INSERT ditolak 42804.
-- Perbaikan: cast eksplisit p_target::public.notification_target, dengan
-- validasi nilai (nilai asing ditolak dengan pesan jelas).
-- =============================================================================

create or replace function public.terbitkan_pengumuman(
  p_judul text,
  p_isi text,
  p_kategori text default 'umum',
  p_prioritas text default 'biasa',
  p_target text default 'semua'
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_id uuid;
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
  if p_target not in ('semua','admin','guru','siswa','orang_tua','kelas','mabit') then
    raise exception 'Target tidak dikenal: %', p_target;
  end if;

  insert into public.announcements
    (dibuat_oleh, judul, isi, kategori, prioritas, target_penerbitan,
     dipublikasikan_pada, status)
  values (auth.uid(), btrim(p_judul), btrim(p_isi), btrim(p_kategori), p_prioritas,
          p_target::public.notification_target, now(), 'dipublikasikan')
  returning id into v_id;

  perform public.catat_audit('terbitkan_pengumuman', 'announcements',
    v_id::text, jsonb_build_object('judul', p_judul, 'prioritas', p_prioritas));

  return jsonb_build_object('id', v_id);
end;
$$;
