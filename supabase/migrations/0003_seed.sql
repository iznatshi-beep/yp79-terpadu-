-- ============================================================================
-- YP79 TERPADU — SEED DATA (Migration 0003)
-- Jalankan SETELAH 0002. Data admin dibuat di Supabase Auth (lihat instruksi di README-SETUP).
-- ============================================================================

-- Finance categories default
insert into public.finance_categories (kode, nama, deskripsi) values
  ('SPP', 'SPP Bulanan', 'Sumbangan Pemeliharaan Pendidikan bulanan'),
  ('Gedung', 'Uang Gedung', 'Biaya gedung semester'),
  ('Kegiatan', 'Biaya Kegiatan', 'Kegiatan sekolah'),
  ('Lainnya', 'Biaya Lain', 'Biaya lain yang ditetapkan')
on conflict (kode) do nothing;

-- Tahun ajaran
insert into public.academic_years (id, semester, tahun_ajaran, mulai, selesai) values
  ('2026/2027', 'gasal', '2026/2027', '2026-07-01', '2027-01-15'),
  ('2026/2027', 'genap', '2026/2027', '2027-01-15', '2027-06-30')
on conflict (id) do nothing;

-- Subject default
insert into public.subjects (kode, nama) values
  ('MTK', 'Matematika'),
  ('IPA', 'IPA'),
  ('IPS', 'IPS'),
  ('BS', 'Bahasa Indonesia'),
  ('BI', 'Bahasa Inggris'),
  ('PAI', 'Pendidikan Agama Islam'),
  ('PJOK', 'PJOK'),
  ('INFORMATIKA', 'Informatika')
on conflict (kode, nama) do nothing;
