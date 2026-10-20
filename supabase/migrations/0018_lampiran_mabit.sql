-- 0018: Lampiran (file upload) untuk form mutabaah & setoran hafalan.
-- Kolom lampiran_url menyimpan public URL dari storage bucket `lampiran`.
-- (Kolom sudah ditambahkan manual via Management API; migration ini
--  menjaga konsistensi untuk project baru / reset.)

alter table mutabaah_entries
  add column if not exists lampiran_url text;

alter table memorization_submissions
  add column if not exists lampiran_url text;

comment on column mutabaah_entries.lampiran_url is
  'URL file lampiran (foto/PDF) mutabaah harian dari storage bucket lampiran.';

comment on column memorization_submissions.lampiran_url is
  'URL file lampiran (audio/video setoran hafalan) dari storage bucket lampiran.';
