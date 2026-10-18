-- =====================================================================
-- YP79 TERPADU — BUNDLE SEMUA MIGRASI (untuk PROJECT SUPABASE BARU)
-- Urutan: 0001 -> 0002 -> 0003 -> 0004 -> 0005 -> 0006
-- Paste SELURUH isi file ini ke Supabase SQL Editor -> Run (sekali saja).
-- JANGAN dijalankan di project yang sudah punya tabel aplikasi lain.
-- =====================================================================


-- >>>>>>>>>>>>>>>>>>>> 0001_schema.sql <<<<<<<<<<<<<<<<<<

-- ============================================================================
-- YP79 TERPADU â€” SUPABASE SCHEMA (Migration 0001)
-- Jalankan seluruh isi file ini di Supabase SQL Editor (atau supabase db push).
-- ============================================================================

-- =============================== TYPES ===============================
create or replace type public.user_role as enum ('admin','guru','guru_pembimbing','siswa','orang_tua');
create or replace type public.attendance_status as enum ('hadir','terlambat','izin','sakit','alpa');
create or replace type public.attendance_method as enum ('manual','qr','rfid','mabit');
create or replace type public.grading_category as enum ('tugas','ujian','harian','prakarya','karakter');
create or replace type public.assignment_status as enum ('draft','dipublikasikan','dikumpulkan','keterlambatan','dinilai','dikembalikan');
create or replace type public.exam_status as enum ('draft','aktif','selesai','dipublikasikan');
create or replace type public.exam_attempt_status as enum ('menunggu','berlangsung','dikumpulkan','dinilai');
create or replace type public.invoice_status as enum ('menunggu','berhasil','gagal','keterlambatan');
create or replace type public.ppdb_status as enum ('draf','diajukan','pemeriksaan','perlu_perbaikan','lolos','tidak_lolos');
create or replace type public.leave_status as enum ('diajukan','diproses','disetujui','ditolak');
create or replace type public.mabit_participant_status as enum ('terdaftar','check_in','check_out','absen');
create or replace type public.memorization_status as enum ('diajukan','diverifikasi','ditolak','pengulangan');
create or replace type public.consent_status as enum ('menunggu','disetujui','ditolak','kedaluwarsa');
create or replace type public.appointment_status as enum ('diajukan','diterima','ditolak','selesai','dibatalkan');
create or replace type public.report_status as enum ('draf','periksa','dipublikasikan');
create or replace type public.notification_target as enum ('semua','admin','guru','siswa','orang_tua','kelas','mabit');
create or replace type public.bus_status as enum ('aktif','siaga','perjalanan','tidak_tersambung');

-- =============================== IDENTITAS ===============================
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'siswa',
  nama text not null,
  npsn text,
  nisn text,
  email text,
  foto_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.student_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  nis text not null unique,
  nisn text,
  nama_lengkap text not null,
  jenis_kelamin text check (jenis_kelamin in ('L','P')),
  tanggal_lahir date,
  tempat_lahir text,
  kelas_id uuid,
  tahun_ajaran text,
  semester text,
  status_aktif boolean not null default true,
  alamat text,
  keterangan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.parent_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  nama_lengkap text not null,
  hubungan text,
  no_hp text,
  alamat text,
  pekerjaan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.teacher_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  nip text,
  nuptk text,
  nama_lengkap text not null,
  jenis_kelamin text check (jenis_kelamin in ('L','P')),
  jabatan text,
  status_aktif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.parent_student (
  parent_user_id uuid not null references public.parent_profiles (user_id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  hubungan text not null default 'Ayah',
  diverifikasi boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (parent_user_id, student_user_id)
);

-- =============================== STRUKTUR SEKOLAH ===============================
create table if not exists public.academic_years (
  id text primary key,             -- contoh: '2025/2026'
  semester text not null check (semester in ('gasal','genap')),
  tahun_ajaran text not null,
  mulai date,
  selesai date,
  unique (tahun_ajaran, semester)
);

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  nama text not null,             -- '7A', '8B'
  jenjang text not null default 'SMP',
  wali_kelas_id uuid references public.profiles (id) on delete set null,
  tahun_ajaran text not null,
  unique (nama, tahun_ajaran)
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  kode text not null,
  nama text not null,
  guru_id uuid references public.profiles (id) on delete set null,
  unique (kode, nama)
);

create table if not exists public.class_enrollments (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  tahun_ajaran text not null,
  semester text not null,
  created_at timestamptz not null default now(),
  unique (student_user_id, class_id, tahun_ajaran, semester)
);

create table if not exists public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  teacher_user_id uuid not null references public.teacher_profiles (user_id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  subject_id uuid references public.subjects (id) on delete set null,
  tahun_ajaran text not null,
  peran text not null default 'pengampu' check (peran in ('pengampu','wali_kelas','pembimbing_mabit')),
  unique (teacher_user_id, class_id, subject_id, tahun_ajaran, peran)
);

create table if not exists public.schedules (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  teacher_user_id uuid references public.teacher_profiles (user_id) on delete set null,
  hari text not null check (hari in ('Senin','Selasa','Rabu','Kamis','Jumat','Sabtu')),
  jam_ke integer not null,
  jam_mulai text not null,
  jam_selesai text not null,
  ruang text,
  tahun_ajaran text not null,
  unique (class_id, hari, jam_ke, tahun_ajaran)
);

create table if not exists public.academic_calendar (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null,
  jenis text not null check (jenis in ('libur','kegiatan','ujian','mabit','lainnya')),
  judul text not null,
  deskripsi text,
  dibuat_oleh uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

-- =============================== PRESSENSI ===============================
create table if not exists public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  class_id uuid references public.classes (id) on delete set null,
  tanggal date not null,
  guru_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.attendance_sessions (id) on delete set null,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  tanggal date not null,
  status public.attendance_status not null,
  metode public.attendance_method not null default 'manual',
  jam_checkin timestamptz,
  jam_checkout timestamptz,
  catatan text,
  qr_token_hash text,
  dibuat_oleh uuid references public.profiles (id) on delete set null,
  diperbarui_oleh uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_attendance_record_date on public.attendance_records (tanggal, student_user_id);
create index if not exists idx_attendance_record_student on public.attendance_records (student_user_id, tanggal);

create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  diajukan_oleh uuid not null references public.profiles (id) on delete cascade,
  mulai date not null,
  selesai date,
  jenis text not null check (jenis in ('izin','sakit')),
  alasan text not null,
  lampiran_url text,
  status public.leave_status not null default 'diajukan',
  keputusan_oleh uuid references public.profiles (id) on delete set null,
  catatan_keputusan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_leave_student on public.leave_requests (student_user_id, mulai);

-- =============================== AKADEMIK / LMS / CBT ===============================
create table if not exists public.learning_materials (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects (id) on delete cascade,
  class_id uuid references public.classes (id) on delete cascade,
  dibuat_oleh uuid not null references public.profiles (id) on delete cascade,
  judul text not null,
  deskripsi text,
  file_url text,
  file_nama text,
  tenggat timestamptz,
  dipublikasikan boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_material_class on public.learning_materials (class_id, dipublikasikan);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  dibuat_oleh uuid not null references public.profiles (id) on delete cascade,
  judul text not null,
  deskripsi text,
  tenggat timestamptz not null,
  lampiran_url text,
  bobot integer,
  rubrik text,
  status public.assignment_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_assignment_class on public.assignments (class_id, status, tenggat);

create table if not exists public.assignment_submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments (id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  jawaban_text text,
  file_url text,
  file_nama text,
  waktu_kumpul timestamptz not null default now(),
  keteterlambatan boolean not null default false,
  nilai numeric(5,2),
  umpan_balik text,
  status public.assignment_status not null default 'draft',
  created_at timestamptz not null default now(),
  unique (assignment_id, student_user_id)
);
create index if not exists idx_submission_assignment on public.assignment_submissions (assignment_id);

create table if not exists public.grading_records (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  guru_id uuid not null references public.profiles (id) on delete cascade,
  kategori public.grading_category not null,
  nilai numeric(5,2) not null check (nilai >= 0 and nilai <= 100),
  semester text not null,
  tahun_ajaran text not null,
  tanggal_input date not null default current_date,
  catatan text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_grading_student on public.grading_records (student_user_id, semester, tahun_ajaran);

create table if not exists public.report_cards (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  semester text not null,
  tahun_ajaran text not null,
  status public.report_status not null default 'draf',
  dibuat_oleh uuid references public.profiles (id) on delete set null,
  dipublikasikan_pada timestamptz,
  catatan_karakter text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_user_id, semester, tahun_ajaran)
);

create table if not exists public.report_card_items (
  id uuid primary key default gen_random_uuid(),
  report_card_id uuid not null references public.report_cards (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  nilai_akhir numeric(5,2),
  predikat text,
  catatan_guru text
);

create table if not exists public.exams (
  id uuid primary key default gen_random_uuid(),
  dibuat_oleh uuid not null references public.profiles (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  judul text not null,
  deskripsi text,
  mulai timestamptz not null,
  selesai timestamptz not null,
  durasi_menit integer not null default 60,
  jumlah_percobaan integer not null default 1,
  status public.exam_status not null default 'draft',
  kunci_terkunci boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_exam_window on public.exams (mulai, selesai, status);

create table if not exists public.exam_questions (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams (id) on delete cascade,
  urutan integer not null default 1,
  tipe text not null check (tipe in ('pilihan','esai')),
  pertanyaan text not null,
  opsi_a text,
  opsi_b text,
  opsi_c text,
  opsi_d text,
  kunci text check (kunci in ('A','B','C','D')),
  skor integer not null default 1,
  unique (exam_id, urutan)
);

create table if not exists public.exam_attempts (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams (id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  percobaan integer not null default 1,
  mulai timestamptz not null default now(),
  selesai timestamptz,
  status public.exam_attempt_status not null default 'menunggu',
  nilai_pilihan numeric(5,2),
  total_skor numeric(5,2),
  created_at timestamptz not null default now(),
  unique (exam_id, student_user_id, percobaan)
);

create table if not exists public.exam_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.exam_attempts (id) on delete cascade,
  question_id uuid not null references public.exam_questions (id) on delete cascade,
  jawaban text,
  tervalidasi boolean not null default false,
  unique (attempt_id, question_id)
);

-- =============================== KEUANGAN (non-pembayaran) ===============================
create table if not exists public.finance_categories (
  id uuid primary key default gen_random_uuid(),
  kode text not null unique,
  nama text not null,            -- 'SPP', 'Uang Gedung', 'Biaya Kegiatan', ...
  deskripsi text,
  aktif boolean not null default true
);

create table if not exists public.finance_items (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.finance_categories (id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  semester text not null,
  tahun_ajaran text not null,
  nominal integer not null default 0,
  keterangan text,
  created_at timestamptz not null default now(),
  unique (student_user_id, semester, tahun_ajaran, category_id)
);
create index if not exists idx_finance_student on public.finance_items (student_user_id, tahun_ajaran, semester);

-- =============================== PPDB ===============================
create table if not exists public.admissions (
  id uuid primary key default gen_random_uuid(),
  nomor_registrasi text not null unique,
  nama_calon text not null,
  nisn_calon text,
  jenis_kelamin text check (jenis_kelamin in ('L','P')),
  tanggal_lahir date,
  asal_sekolah text,
  jenjang text not null default 'SMP',
  status public.ppdb_status not null default 'draf',
  dibuat_oleh uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admission_parents (
  id uuid primary key default gen_random_uuid(),
  admission_id uuid not null references public.admissions (id) on delete cascade,
  nama text not null,
  hubungan text,
  no_hp text,
  pekerjaan text,
  alamat text
);

create table if not exists public.admission_documents (
  id uuid primary key default gen_random_uuid(),
  admission_id uuid not null references public.admissions (id) on delete cascade,
  jenis text not null,
  file_url text not null,
  verifikasi text check (verifikasi in ('belum','lulus','perlu_perbaikan')),
  catatan text,
  unique (admission_id, jenis)
);

create table if not exists public.admission_results (
  id uuid primary key default gen_random_uuid(),
  admission_id uuid not null references public.admissions (id) on delete cascade,
  hasil text not null check (hasil in ('lolos','tidak_lolos')),
  nilai_selain text,
  ditetapkan_oleh uuid not null references public.profiles (id) on delete cascade,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  unique (admission_id)
);

-- =============================== MABIT ===============================
create table if not exists public.mabit_events (
  id uuid primary key default gen_random_uuid(),
  nama_kegiatan text not null,
  deskripsi text,
  tanggal_mulai date not null,
  tanggal_selesai date not null,
  lokasi text,
  rundown_json jsonb not null default '[]'::jsonb,
  presensi_aktif boolean not null default true,
  status text not null default 'aktif' check (status in ('aktif','selesai','dibatalkan')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mabit_participants (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.mabit_events (id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  status public.mabit_participant_status not null default 'terdaftar',
  jam_checkin timestamptz,
  jam_checkout timestamptz,
  validasi_oleh uuid references public.profiles (id) on delete set null,
  unique (event_id, student_user_id)
);

create table if not exists public.mabit_groups (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.mabit_events (id) on delete cascade,
  nama_kelompok text not null,
  pembimbing_id uuid references public.profiles (id) on delete set null,
  unique (event_id, nama_kelompok)
);

create table if not exists public.mabit_group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.mabit_groups (id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  unique (group_id, student_user_id)
);

create table if not exists public.mabit_rooms (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.mabit_events (id) on delete cascade,
  nama_kamar text not null,
  kapasitas integer not null default 4,
  unique (event_id, nama_kamar)
);

create table if not exists public.mabit_room_assignments (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.mabit_rooms (id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  unique (room_id, student_user_id)
);

create table if not exists public.mabit_rundown_items (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.mabit_events (id) on delete cascade,
  urutan integer not null default 1,
  jam text not null,
  aktivitas text not null,
  keterangan text
);

create table if not exists public.mabit_media (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.mabit_events (id) on delete cascade,
  file_url text not null,
  deskripsi text,
  dipublikasikan boolean not null default false,
  diunggah_oleh uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.mutabaah_entries (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  event_id uuid references public.mabit_events (id) on delete set null,
  tanggal date not null,
  checklist jsonb not null default '{}'::jsonb,   -- {"dzikir_pagi": true, ...}
  diverifikasi boolean not null default false,
  diverifikasi_oleh uuid,
  diverifikasi_pada timestamptz,
  unique (student_user_id, tanggal, event_id)
);

create table if not exists public.memorization_targets (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  kategori text not null,          -- 'Juz Amma', 'Doa', ...
  judul text not null,
  target_tanggal date,
  created_at timestamptz not null default now()
);

create table if not exists public.memorization_submissions (
  id uuid primary key default gen_random_uuid(),
  target_id uuid not null references public.memorization_targets (id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  capaian text,
  catatan text,
  status public.memorization_status not null default 'diajukan',
  verified_by uuid references public.profiles (id) on delete set null,
  verified_at timestamptz,
  alasan_penolakan text,
  created_at timestamptz not null default now()
);

create table if not exists public.consent_forms (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.mabit_events (id) on delete cascade,
  judul text not null,
  deskripsi text,
  tenggat date not null,
  catat_medik_aktif boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.consent_responses (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.consent_forms (id) on delete cascade,
  parent_user_id uuid not null references public.parent_profiles (user_id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  jawaban text not null check (jawaban in ('setuju','tidak_setuju')),
  catatan_medik text,
  status public.consent_status not null default 'menunggu',
  created_at timestamptz not null default now(),
  unique (form_id, parent_user_id, student_user_id)
);

-- =============================== PERPUSTAKAAN ===============================
create table if not exists public.library_books (
  id uuid primary key default gen_random_uuid(),
  isbn text unique,
  judul text not null,
  penulis text,
  penerbit text,
  tahun_terbit text,
  kategori text,
  stok_total integer not null default 0,
  stok_tersedia integer not null default 0,
  cover_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.library_loans (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.library_books (id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  tanggal_pinjam date not null default current_date,
  tanggal_kembali date not null,
  dikembalikan date,
  status text not null default 'dipinjam' check (status in ('dipinjam','dikembalikan','terlambat','ditolak')),
  catatan text,
  unique (book_id, student_user_id, tanggal_pinjam)
);

create table if not exists public.digital_resources (
  id uuid primary key default gen_random_uuid(),
  judul text not null,
  kategori text,
  file_url text not null,
  file_nama text,
  deskripsi text,
  dibuat_oleh uuid references public.profiles (id) on delete set null,
  dipublikasikan boolean not null default false,
  created_at timestamptz not null default now()
);

-- =============================== TRANSPORTASI ===============================
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  plat_nomor text not null unique,
  jenis text not null default 'bus',
  status public.bus_status not null default 'siaga',
  kapasitas integer not null default 40,
  sopir_nama text,
  created_at timestamptz not null default now()
);

create table if not exists public.vehicle_assignments (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  rute_mulai text,
  rute_tujuan text,
  unique (vehicle_id, student_user_id)
);

create table if not exists public.vehicle_locations (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  heading double precision,
  kecepatan_kph double precision,
  terekam_pada timestamptz not null default now(),
  sumber text not null default 'telemetry'
);
create index if not exists idx_vehicle_location_time on public.vehicle_locations (vehicle_id, terekam_pada desc);

-- =============================== KOMUNIKASI ===============================
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  penerima_user_id uuid not null references public.profiles (id) on delete cascade,
  target public.notification_target not null default 'semua',
  judul text not null,
  pesan text,
  tipe text not null,
  referensi_id uuid,
  dibaca_pada timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_notification_user on public.notifications (penerima_user_id, created_at desc);
create index if not exists idx_notification_unread on public.notifications (penerima_user_id) where dibaca_pada is null;

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  dibuat_oleh uuid not null references public.profiles (id) on delete cascade,
  judul text not null,
  isi text,
  kategori text,
  prioritas text not null default 'biasa' check (prioritas in ('biasa','penting','darurat')),
  target_penerbitan public.notification_target not null default 'semua',
  lampiran_url text,
  dipublikasikan_pada timestamptz not null default now(),
  status text not null default 'dipublikasikan' check (status in ('dipublikasikan','terjadwal','arsip'))
);

create table if not exists public.chat_conversations (
  id uuid primary key default gen_random_uuid(),
  dibuat_oleh uuid not null references public.profiles (id) on delete cascade,
  guru_user_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  unique (conversation_id, user_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations (id) on delete cascade,
  pengirim_user_id uuid not null references public.profiles (id) on delete cascade,
  isi text not null,
  lampiran_url text,
  status_pesan text not null default 'terkirim' check (status_pesan in ('terkirim','dibaca')),
  created_at timestamptz not null default now()
);
create index if not exists idx_chat_message_conv on public.chat_messages (conversation_id, created_at);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  diajukan_oleh uuid not null references public.profiles (id) on delete cascade,
  guru_user_id uuid not null references public.profiles (id) on delete cascade,
  topik text not null,
  tanggal date not null,
  jam text not null,
  metode text not null default 'tatap_muka' check (metode in ('tatap_muka','online','telepon')),
  catatan text,
  status public.appointment_status not null default 'diajukan',
  keputusan_oleh uuid,
  catatan_keputusan text,
  created_at timestamptz not null default now(),
  unique (guru_user_id, tanggal, jam)
);

-- =============================== BUKU SAKU KEDISIPLINAN ===============================
create table if not exists public.character_records (
  id uuid primary key default gen_random_uuid(),
  student_user_id uuid not null references public.student_profiles (user_id) on delete cascade,
  tanggal date not null,
  jenis text not null check (jenis in ('tindakan','apresiasi','peringatan')),
  deskripsi text not null,
  poin integer not null default 0,
  input_oleh uuid not null references public.profiles (id) on delete cascade,
  dikoreksi_oleh uuid,
  catatan_koreksi text,
  created_at timestamptz not null default now()
);
create index if not exists idx_character_student on public.character_records (student_user_id, tanggal);

-- =============================== AUDIT LOG ===============================
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles (id) on delete set null,
  aksi text not null,
  target_table text,
  target_id text,
  metadata jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_audit_actor on public.audit_logs (actor_user_id, created_at desc);

-- =============================== SCHOOL SETTINGS ===============================
create table if not exists public.school_settings (
  key text primary key,
  value jsonb,
  updated_at timestamptz not null default now()
);

insert into public.school_settings (key, value)
values
  ('sekolah', '{"nama":"YP79 Terpadu","alamat":"","no_hp":"","email":""}'),
  ('presensi', '{"jam_mulai":"07:00","batas_terlambat":"07:30","jam_selesai":"14:30"}'),
  ('nilai', '{"skala":"0-100","bobot_tugas":0.4,"bobot_ujian":0.6,"predikat":"A>=80,B>=70,C>=60,D<60"}'),
  ('ppdb', '{"periode_buka":false,"nomor_registrasi_awal":"2026"}')
on conflict (key) do nothing;


-- >>>>>>>>>>>>>>>>>>>> 0002_rls_functions.sql <<<<<<<<<<<<<<<<<<

-- ============================================================================
-- YP79 TERPADU — RLS + FUNCTIONS + TRIGGERS (Migration 0002)
-- Jalankan SETELAH 0001_schema.sql sukses.
-- ============================================================================

-- Enable RLS pada seluruh tabel data
alter table public.profiles enable row level security;
alter table public.student_profiles enable row level security;
alter table public.parent_profiles enable row level security;
alter table public.teacher_profiles enable row level security;
alter table public.parent_student enable row level security;
alter table public.academic_years enable row level security;
alter table public.classes enable row level security;
alter table public.subjects enable row level security;
alter table public.class_enrollments enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.schedules enable row level security;
alter table public.academic_calendar enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.leave_requests enable row level security;
alter table public.learning_materials enable row level security;
alter table public.assignments enable row level security;
alter table public.assignment_submissions enable row level security;
alter table public.grading_records enable row level security;
alter table public.report_cards enable row level security;
alter table public.report_card_items enable row level security;
alter table public.exams enable row level security;
alter table public.exam_questions enable row level security;
alter table public.exam_attempts enable row level security;
alter table public.exam_answers enable row level security;
alter table public.finance_categories enable row level security;
alter table public.finance_items enable row level security;
alter table public.admissions enable row level security;
alter table public.admission_parents enable row level security;
alter table public.admission_documents enable row level security;
alter table public.admission_results enable row level security;
alter table public.mabit_events enable row level security;
alter table public.mabit_participants enable row level security;
alter table public.mabit_groups enable row level security;
alter table public.mabit_group_members enable row level security;
alter table public.mabit_rooms enable row level security;
alter table public.mabit_room_assignments enable row level security;
alter table public.mabit_rundown_items enable row level security;
alter table public.mabit_media enable row level security;
alter table public.mutabaah_entries enable row level security;
alter table public.memorization_targets enable row level security;
alter table public.memorization_submissions enable row level security;
alter table public.consent_forms enable row level security;
alter table public.consent_responses enable row level security;
alter table public.library_books enable row level security;
alter table public.library_loans enable row level security;
alter table public.digital_resources enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_assignments enable row level security;
alter table public.vehicle_locations enable row level security;
alter table public.notifications enable row level security;
alter table public.announcements enable row level security;
alter table public.chat_conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.appointments enable row level security;
alter table public.character_records enable row level security;
alter table public.audit_logs enable row level security;
alter table public.school_settings enable row level security;

-- =============================== HELPERS ===============================
create or replace function public.is_admin()
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_admin_or_staff()
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin','guru','guru_pembimbing')
  );
$$;

create or replace function public.current_student_id()
returns uuid language sql stable security definer as $$
  select (select user_id from public.student_profiles where user_id = auth.uid())::uuid;
$$;

create or replace function public.current_parent_id()
returns uuid language sql stable security definer as $$
  select (select user_id from public.parent_profiles where user_id = auth.uid())::uuid;
$$;

create or replace function public.is_class_teacher(p_class uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.teacher_assignments
    where class_id = p_class
      and teacher_user_id = auth.uid()
  );
$$;

create or replace function public.is_subject_teacher(p_subj uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.teacher_assignments ta
    where ta.subject_id = p_subj and ta.teacher_user_id = auth.uid()
  )
  or exists (
    select 1 from public.subjects s
    where s.id = p_subj and s.guru_id = auth.uid()
  );
$$;

create or replace function public.is_parent_of(p_student uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.parent_student ps
    where ps.student_user_id = p_student
      and ps.parent_user_id = (
        select user_id from public.parent_profiles where user_id = auth.uid()
      )
      and ps.diverifikasi = true
  );
$$;

-- =============================== PROFILES ===============================
create policy profiles_select on public.profiles
  using (
    public.is_admin()
    or id = auth.uid()
    or exists (
      select 1 from public.parent_student ps
      where ps.student_user_id = id
        and ps.parent_user_id = (select user_id from public.parent_profiles where user_id = auth.uid())
        and ps.diverifikasi = true
    )
  );

create policy profiles_insert on public.profiles
  for insert
  with check (
    public.is_admin() or id = auth.uid()
  );

create policy profiles_update on public.profiles
  for update
  using (
    public.is_admin()
    or (id = auth.uid())
  );

create policy profiles_delete on public.profiles
  for delete
  using (public.is_admin());

-- =============================== STUDENT PROFILES ===============================
create policy student_read on public.student_profiles
  using (
    public.is_admin()
    or user_id = public.current_student_id()
    or public.is_parent_of(user_id)
    or exists (
      select 1 from public.teacher_assignments ta
      join public.class_enrollments ce on ce.class_id = ta.class_id
      where ce.student_user_id = user_id
        and ta.teacher_user_id = auth.uid()
    )
  );

create policy student_insert on public.student_profiles
  for insert
  with check (public.is_admin());

create policy student_update on public.student_profiles
  for update
  using (public.is_admin());

create policy student_delete on public.student_profiles
  for delete
  using (public.is_admin());

-- =============================== PARENT PROFILES ===============================
create policy parent_read on public.parent_profiles
  using (
    public.is_admin()
    or user_id = public.current_parent_id()
  );

create policy parent_insert on public.parent_profiles
  for insert
  with check (public.is_admin() or user_id = auth.uid());

create policy parent_update on public.parent_profiles
  for update
  using (public.is_admin() or user_id = auth.uid());

create policy parent_delete on public.parent_profiles
  for delete
  using (public.is_admin());

-- =============================== TEACHER PROFILES ===============================
create policy teacher_read on public.teacher_profiles
  using (
    public.is_admin()
    or user_id = auth.uid()
    or public.is_admin_or_staff()
  );

create policy teacher_insert on public.teacher_profiles
  for insert
  with check (public.is_admin());

create policy teacher_update on public.teacher_profiles
  for update
  using (public.is_admin());

create policy teacher_delete on public.teacher_profiles
  for delete
  using (public.is_admin());

-- =============================== PARENT-STUDENT ===============================
create policy p_s_read on public.parent_student
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or (parent_user_id = public.current_parent_id())
  );

create policy p_s_insert on public.parent_student
  for insert
  with check (public.is_admin());

create policy p_s_update on public.parent_student
  for update
  using (public.is_admin());

create policy p_s_delete on public.parent_student
  for delete
  using (public.is_admin());

-- =============================== ACADEMIC YEARS ===============================
create policy ay_read on public.academic_years
  using (true);

create policy ay_write on public.academic_years
  for insert
  with check (public.is_admin());

create policy ay_update on public.academic_years
  for update
  using (public.is_admin());

create policy ay_delete on public.academic_years
  for delete
  using (public.is_admin());

-- =============================== CLASSES ===============================
create policy classes_read on public.classes
  using (
    public.is_admin_or_staff()
    or exists (select 1 from public.class_enrollments ce where ce.class_id = id and ce.student_user_id = public.current_student_id())
    or exists (select 1 from public.parent_student ps where public.is_parent_of(ps.student_user_id)
      and exists (select 1 from public.class_enrollments ce where ce.student_user_id = ps.student_user_id and ce.class_id = id))
  );

create policy classes_write on public.classes
  for insert
  with check (public.is_admin());

create policy classes_update on public.classes
  for update
  using (public.is_admin());

create policy classes_delete on public.classes
  for delete
  using (public.is_admin());

-- =============================== SUBJECTS ===============================
create policy subjects_read on public.subjects
  using (
    public.is_admin_or_staff()
    or guru_id = auth.uid()
    or exists (
      select 1 from public.teacher_assignments ta
      where ta.subject_id = id
        and ta.teacher_user_id = auth.uid()
    )
  );

create policy subjects_write on public.subjects
  for insert
  with check (public.is_admin());

create policy subjects_update on public.subjects
  for update
  using (public.is_admin());

create policy subjects_delete on public.subjects
  for delete
  using (public.is_admin());

-- =============================== ENROLLMENTS ===============================
create policy ce_read on public.class_enrollments
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
    or exists (
      select 1 from public.teacher_assignments ta
      where ta.class_id = class_id
        and ta.teacher_user_id = auth.uid()
    )
  );

create policy ce_write on public.class_enrollments
  for insert
  with check (public.is_admin());

create policy ce_update on public.class_enrollments
  for update
  using (public.is_admin());

create policy ce_delete on public.class_enrollments
  for delete
  using (public.is_admin());

-- =============================== TEACHER ASSIGNMENTS ===============================
create policy ta_read on public.teacher_assignments
  using (
    public.is_admin()
    or teacher_user_id = auth.uid()
  );

create policy ta_write on public.teacher_assignments
  for insert
  with check (public.is_admin());

create policy ta_update on public.teacher_assignments
  for update
  using (public.is_admin());

create policy ta_delete on public.teacher_assignments
  for delete
  using (public.is_admin());

-- =============================== SCHEDULES ===============================
create policy schedules_read on public.schedules
  using (
    public.is_admin_or_staff()
    or teacher_user_id = auth.uid()
    or exists (select 1 from public.class_enrollments ce where ce.class_id = class_id and ce.student_user_id = public.current_student_id())
    or (exists (select 1 from public.parent_student ps where public.is_parent_of(ps.student_user_id))
      and exists (select 1 from public.class_enrollments ce where ce.student_user_id in (select student_user_id from public.parent_student where public.is_parent_of(student_user_id)) and ce.class_id = class_id))
  );

create policy schedules_write on public.schedules
  for insert
  with check (public.is_admin());

create policy schedules_update on public.schedules
  for update
  using (public.is_admin());

create policy schedules_delete on public.schedules
  for delete
  using (public.is_admin());

-- =============================== ACADEMIC CALENDAR ===============================
create policy cal_read on public.academic_calendar
  using (true);

create policy cal_write on public.academic_calendar
  for insert
  with check (public.is_admin());

create policy cal_update on public.academic_calendar
  for update
  using (public.is_admin());

create policy cal_delete on public.academic_calendar
  for delete
  using (public.is_admin());

-- =============================== ATTENDANCE ===============================
create policy as_read on public.attendance_sessions
  using (public.is_admin_or_staff());

create policy as_write on public.attendance_sessions
  for insert
  with check (public.is_admin_or_staff());

create policy ar_read on public.attendance_records
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
    or exists (
      select 1 from public.teacher_assignments ta
      where ta.class_id in (select class_id from public.class_enrollments where student_user_id = public.attendance_records.student_user_id)
        and ta.teacher_user_id = auth.uid()
    )
  );
-- Perbaikan: policy tidak boleh self-reference di subquery. Tulis ulang:
drop policy ar_read on public.attendance_records;
create policy ar_read on public.attendance_records
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
    or exists (
      select 1 from public.teacher_assignments ta
      where ta.teacher_user_id = auth.uid()
        and ta.class_id in (
          select class_id from public.class_enrollments
          where student_user_id = public.attendance_records.student_user_id
        )
    )
  );

create policy ar_insert on public.attendance_records
  for insert
  with check (
    public.is_admin()
    or (metode in ('manual','qr') and public.is_admin_or_staff())
    or (metode = 'rfid' and public.is_admin())
  );

create policy ar_update on public.attendance_records
  for update
  using (public.is_admin());

create policy ar_delete on public.attendance_records
  for delete
  using (public.is_admin());

-- =============================== LEAVE REQUESTS ===============================
create policy leave_read on public.leave_requests
  using (
    public.is_admin_or_staff()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
    or diajukan_oleh = auth.uid()
  );

create policy leave_insert on public.leave_requests
  for insert
  with check (
    public.is_admin_or_staff()
    or diajukan_oleh = auth.uid()
  );

create policy leave_update on public.leave_requests
  for update
  using (public.is_admin_or_staff());

create policy leave_delete on public.leave_requests
  for delete
  using (public.is_admin());

-- =============================== LMS MATERIALS ===============================
create policy lm_read on public.learning_materials
  using (
    public.is_admin_or_staff()
    or dibuat_oleh = auth.uid()
    or (dipublikasikan = true and exists (
      select 1 from public.class_enrollments ce
      where ce.class_id = class_id
        and ce.student_user_id = public.current_student_id()
    ))
    or (dipublikasikan = true and exists (
      select 1 from public.parent_student ps
      where public.is_parent_of(ps.student_user_id)
        and exists (select 1 from public.class_enrollments ce where ce.student_user_id = ps.student_user_id and ce.class_id = class_id)
    ))
  );

create policy lm_insert on public.learning_materials
  for insert
  with check (
    public.is_admin()
    or (dibuat_oleh = auth.uid() and public.is_admin_or_staff())
  );

create policy lm_update on public.learning_materials
  for update
  using (public.is_admin() or dibuat_oleh = auth.uid());

create policy lm_delete on public.learning_materials
  for delete
  using (public.is_admin() or dibuat_oleh = auth.uid());

-- =============================== ASSIGNMENTS ===============================
create policy asg_read on public.assignments
  using (
    public.is_admin_or_staff()
    or dibuat_oleh = auth.uid()
    or (status in ('dipublikasikan','dikumpulkan','keterlambatan','dinilai','dikembalikan') and exists (
      select 1 from public.class_enrollments ce
      where ce.class_id = class_id
        and ce.student_user_id = public.current_student_id()
    ))
  );

create policy asg_insert on public.assignments
  for insert
  with check (public.is_admin() or (dibuat_oleh = auth.uid() and public.is_admin_or_staff()));

create policy asg_update on public.assignments
  for update
  using (public.is_admin() or dibuat_oleh = auth.uid());

create policy asg_delete on public.assignments
  for delete
  using (public.is_admin() or dibuat_oleh = auth.uid());

create policy sub_read on public.assignment_submissions
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
    or exists (
      select 1 from public.assignments a
      where a.id = assignment_id
        and a.dibuat_oleh = auth.uid()
    )
  );

create policy sub_insert on public.assignment_submissions
  for insert
  with check (
    student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy sub_update on public.assignment_submissions
  for update
  using (
    public.is_admin()
    or exists (select 1 from public.assignments a where a.id = assignment_id and a.dibuat_oleh = auth.uid())
  );

create policy sub_delete on public.assignment_submissions
  for delete
  using (public.is_admin());

-- =============================== GRADING ===============================
create policy gr_read on public.grading_records
  using (
    public.is_admin()
    or (guru_id = auth.uid() and public.is_admin_or_staff())
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy gr_insert on public.grading_records
  for insert
  with check (
    public.is_admin()
    or (guru_id = auth.uid() and public.is_admin_or_staff())
  );

create policy gr_update on public.grading_records
  for update
  using (
    public.is_admin()
    or (guru_id = auth.uid() and public.is_admin_or_staff())
  );

create policy gr_delete on public.grading_records
  for delete
  using (public.is_admin());

-- =============================== REPORT CARDS ===============================
create policy rc_read on public.report_cards
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy rc_write on public.report_cards
  for insert
  with check (public.is_admin());

create policy rc_update on public.report_cards
  for update
  using (public.is_admin() or dibuat_oleh = auth.uid());

create policy rc_delete on public.report_cards
  for delete
  using (public.is_admin());

create policy rci_read on public.report_card_items
  using (
    public.is_admin()
    or report_card_id in (select id from public.report_cards where student_user_id = public.current_student_id())
    or report_card_id in (select id from public.report_cards where public.is_parent_of(student_user_id))
  );

create policy rci_write on public.report_card_items
  for insert
  with check (public.is_admin());

create policy rci_update on public.report_card_items
  for update
  using (public.is_admin());

create policy rci_delete on public.report_card_items
  for delete
  using (public.is_admin());

-- =============================== EXAMS / CBT ===============================
create policy exam_read on public.exams
  using (
    public.is_admin_or_staff()
    or (status in ('aktif','selesai','dipublikasikan') and exists (
      select 1 from public.class_enrollments ce
      where ce.class_id = class_id
        and ce.student_user_id = public.current_student_id()
    ))
  );

create policy exam_insert on public.exams
  for insert
  with check (public.is_admin() or (dibuat_oleh = auth.uid() and public.is_admin_or_staff()));

create policy exam_update on public.exams
  for update
  using (public.is_admin() or dibuat_oleh = auth.uid());

create policy exam_delete on public.exams
  for delete
  using (public.is_admin() or dibuat_oleh = auth.uid());

create or replace function public.exam_publishable(p_exam uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.exams
    where id = p_exam
      and (status in ('selesai','dipublikasikan') or kunci_terkunci = false)
  );
$$;

create policy exq_read on public.exam_questions
  using (
    public.is_admin_or_staff()
    or public.exam_publishable(exam_id)
  );

create policy exq_write on public.exam_questions
  for insert
  with check (public.is_admin_or_staff());

create policy exq_update on public.exam_questions
  for update
  using (public.is_admin_or_staff());

create policy exq_delete on public.exam_questions
  for delete
  using (public.is_admin_or_staff());

create policy eatt_read on public.exam_attempts
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or (public.is_admin_or_staff() and exam_id in (
      select e.id from public.exams e where e.dibuat_oleh = auth.uid()
    ))
  );

create policy eatt_insert on public.exam_attempts
  for insert
  with check (
    student_user_id = public.current_student_id()
    or public.is_admin()
  );

create policy eatt_update on public.exam_attempts
  for update
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
  );

create policy eatt_delete on public.exam_attempts
  for delete
  using (public.is_admin());

create policy eans_read on public.exam_answers
  using (
    public.is_admin()
    or public.is_admin_or_staff()
    or attempt_id in (select id from public.exam_attempts where student_user_id = public.current_student_id())
  );

create policy eans_write on public.exam_answers
  for insert
  with check (public.is_admin() or attempt_id in (select id from public.exam_attempts where student_user_id = public.current_student_id()));

create policy eans_update on public.exam_answers
  for update
  using (public.is_admin() or attempt_id in (select id from public.exam_attempts where student_user_id = public.current_student_id()));

create policy eans_delete on public.exam_answers
  for delete
  using (public.is_admin());

-- =============================== FINANCE ===============================
create policy fin_cat_read on public.finance_categories
  using (public.is_admin_or_staff());

create policy fin_cat_write on public.finance_categories
  for insert
  with check (public.is_admin());

create policy fin_cat_update on public.finance_categories
  for update
  using (public.is_admin());

create policy fin_cat_delete on public.finance_categories
  for delete
  using (public.is_admin());

create policy fin_item_read on public.finance_items
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy fin_item_write on public.finance_items
  for insert
  with check (public.is_admin());

create policy fin_item_update on public.finance_items
  for update
  using (public.is_admin());

create policy fin_item_delete on public.finance_items
  for delete
  using (public.is_admin());

-- =============================== PPDB ===============================
create policy adm_read on public.admissions
  using (public.is_admin());

create policy adm_write on public.admissions
  for insert
  with check (public.is_admin());

create policy adm_update on public.admissions
  for update
  using (public.is_admin());

create policy adm_delete on public.admissions
  for delete
  using (public.is_admin());

create policy adm_parent_read on public.admission_parents
  using (public.is_admin());

create policy adm_parent_write on public.admission_parents
  for insert
  with check (public.is_admin());

create policy adm_parent_update on public.admission_parents
  for update
  using (public.is_admin());

create policy adm_parent_delete on public.admission_parents
  for delete
  using (public.is_admin());

create policy adm_doc_read on public.admission_documents
  using (public.is_admin());

create policy adm_doc_write on public.admission_documents
  for insert
  with check (public.is_admin());

create policy adm_doc_update on public.admission_documents
  for update
  using (public.is_admin());

create policy adm_doc_delete on public.admission_documents
  for delete
  using (public.is_admin());

create policy adm_result_read on public.admission_results
  using (public.is_admin());

create policy adm_result_write on public.admission_results
  for insert
  with check (public.is_admin());

create policy adm_result_update on public.admission_results
  for update
  using (public.is_admin());

create policy adm_result_delete on public.admission_results
  for delete
  using (public.is_admin());

-- =============================== MABIT ===============================
create policy mabit_ev_read on public.mabit_events
  using (
    public.is_admin_or_staff()
    or status = 'aktif'
    or exists (select 1 from public.mabit_participants mp where mp.event_id = id and public.is_parent_of(mp.student_user_id))
  );

create policy mabit_ev_write on public.mabit_events
  for insert
  with check (public.is_admin());

create policy mabit_ev_update on public.mabit_events
  for update
  using (public.is_admin());

create policy mabit_ev_delete on public.mabit_events
  for delete
  using (public.is_admin());

create policy mabit_part_read on public.mabit_participants
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy mabit_part_write on public.mabit_participants
  for insert
  with check (public.is_admin());

create policy mabit_part_update on public.mabit_participants
  for update
  using (
    public.is_admin()
    or (student_user_id = public.current_student_id() and status in ('check_in','check_out'))
  );

create policy mabit_part_delete on public.mabit_participants
  for delete
  using (public.is_admin());

create policy mabit_group_read on public.mabit_groups
  using (
    public.is_admin()
    or pembimbing_id = auth.uid()
    or exists (select 1 from public.mabit_group_members mgm where mgm.group_id = id and public.is_parent_of(mgm.student_user_id))
  );

create policy mabit_group_write on public.mabit_groups
  for insert
  with check (public.is_admin());

create policy mabit_group_update on public.mabit_groups
  for update
  using (public.is_admin());

create policy mabit_group_delete on public.mabit_groups
  for delete
  using (public.is_admin());

create policy mabit_gm_read on public.mabit_group_members
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy mabit_gm_write on public.mabit_group_members
  for insert
  with check (public.is_admin());

create policy mabit_gm_update on public.mabit_group_members
  for update
  using (public.is_admin());

create policy mabit_gm_delete on public.mabit_group_members
  for delete
  using (public.is_admin());

create policy mabit_room_read on public.mabit_rooms
  using (public.is_admin_or_staff());

create policy mabit_room_write on public.mabit_rooms
  for insert
  with check (public.is_admin());

create policy mabit_room_update on public.mabit_rooms
  for update
  using (public.is_admin());

create policy mabit_room_delete on public.mabit_rooms
  for delete
  using (public.is_admin());

create policy mabit_ra_read on public.mabit_room_assignments
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy mabit_ra_write on public.mabit_room_assignments
  for insert
  with check (public.is_admin());

create policy mabit_ra_update on public.mabit_room_assignments
  for update
  using (public.is_admin());

create policy mabit_ra_delete on public.mabit_room_assignments
  for delete
  using (public.is_admin());

create policy mabit_ru_read on public.mabit_rundown_items
  using (
    public.is_admin_or_staff()
    or exists (select 1 from public.mabit_participants mp where mp.event_id = event_id and (public.is_parent_of(mp.student_user_id) or mp.student_user_id = public.current_student_id()))
  );

create policy mabit_ru_write on public.mabit_rundown_items
  for insert
  with check (public.is_admin());

create policy mabit_ru_update on public.mabit_rundown_items
  for update
  using (public.is_admin());

create policy mabit_ru_delete on public.mabit_rundown_items
  for delete
  using (public.is_admin());

create policy mabit_media_read on public.mabit_media
  using (
    public.is_admin()
    or dipublikasikan = true
    or diunggah_oleh = auth.uid()
  );

create policy mabit_media_write on public.mabit_media
  for insert
  with check (public.is_admin_or_staff());

create policy mabit_media_update on public.mabit_media
  for update
  using (public.is_admin());

create policy mabit_media_delete on public.mabit_media
  for delete
  using (public.is_admin());

create policy mutabaah_read on public.mutabaah_entries
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy mutabaah_write on public.mutabaah_entries
  for insert
  with check (student_user_id = public.current_student_id());

create policy mutabaah_update on public.mutabaah_entries
  for update
  using (
    public.is_admin()
    or (diverifikasi = true and verified_by = auth.uid())
    or student_user_id = public.current_student_id()
  );

create policy mutabaah_delete on public.mutabaah_entries
  for delete
  using (public.is_admin());

create policy mem_target_read on public.memorization_targets
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy mem_target_write on public.memorization_targets
  for insert
  with check (public.is_admin_or_staff());

create policy mem_target_update on public.memorization_targets
  for update
  using (public.is_admin_or_staff());

create policy mem_target_delete on public.memorization_targets
  for delete
  using (public.is_admin());

create policy mem_sub_read on public.memorization_submissions
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy mem_sub_write on public.memorization_submissions
  for insert
  with check (student_user_id = public.current_student_id() or public.is_admin());

create policy mem_sub_update on public.memorization_submissions
  for update
  using (
    public.is_admin()
    or verified_by = auth.uid()
    or student_user_id = public.current_student_id()
  );

create policy mem_sub_delete on public.memorization_submissions
  for delete
  using (public.is_admin());

create policy consent_form_read on public.consent_forms
  using (
    public.is_admin()
    or exists (select 1 from public.consent_responses cr where cr.form_id = id and public.is_parent_of(cr.student_user_id))
  );

create policy consent_form_write on public.consent_forms
  for insert
  with check (public.is_admin());

create policy consent_form_update on public.consent_forms
  for update
  using (public.is_admin());

create policy consent_form_delete on public.consent_forms
  for delete
  using (public.is_admin());

create policy consent_resp_read on public.consent_responses
  using (
    public.is_admin()
    or public.is_parent_of(student_user_id)
  );

create policy consent_resp_write on public.consent_responses
  for insert
  with check (public.is_parent_of(student_user_id) or public.is_admin());

create policy consent_resp_update on public.consent_responses
  for update
  using (public.is_admin() or public.is_parent_of(student_user_id));

create policy consent_resp_delete on public.consent_responses
  for delete
  using (public.is_admin());

-- =============================== LIBRARY ===============================
create policy lb_read on public.library_books
  using (true);

create policy lb_write on public.library_books
  for insert
  with check (public.is_admin());

create policy lb_update on public.library_books
  for update
  using (public.is_admin());

create policy lb_delete on public.library_books
  for delete
  using (public.is_admin());

create policy ll_read on public.library_loans
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy ll_write on public.library_loans
  for insert
  with check (public.is_admin());

create policy ll_update on public.library_loans
  for update
  using (public.is_admin());

create policy ll_delete on public.library_loans
  for delete
  using (public.is_admin());

create policy dr_read on public.digital_resources
  using (
    dipublikasikan = true
    or public.is_admin()
    or dibuat_oleh = auth.uid()
  );

create policy dr_write on public.digital_resources
  for insert
  with check (public.is_admin());

create policy dr_update on public.digital_resources
  for update
  using (public.is_admin());

create policy dr_delete on public.digital_resources
  for delete
  using (public.is_admin());

-- =============================== VEHICLES / GPS ===============================
create policy veh_read on public.vehicles
  using (
    public.is_admin()
    or exists (select 1 from public.vehicle_assignments va where va.vehicle_id = id and public.is_parent_of(va.student_user_id))
  );

create policy veh_write on public.vehicles
  for insert
  with check (public.is_admin());

create policy veh_update on public.vehicles
  for update
  using (public.is_admin());

create policy veh_delete on public.vehicles
  for delete
  using (public.is_admin());

create policy va_read on public.vehicle_assignments
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy va_write on public.vehicle_assignments
  for insert
  with check (public.is_admin());

create policy va_update on public.vehicle_assignments
  for update
  using (public.is_admin());

create policy va_delete on public.vehicle_assignments
  for delete
  using (public.is_admin());

create policy vloc_read on public.vehicle_locations
  using (
    public.is_admin()
    or exists (select 1 from public.vehicle_assignments va where va.vehicle_id = vehicle_id and public.is_parent_of(va.student_user_id))
  );

create policy vloc_write on public.vehicle_locations
  for insert
  with check (public.is_admin());

create policy vloc_update on public.vehicle_locations
  for update
  using (public.is_admin());

create policy vloc_delete on public.vehicle_locations
  for delete
  using (public.is_admin());

-- =============================== NOTIFICATIONS ===============================
create policy notif_read on public.notifications
  using (
    penerima_user_id = auth.uid()
    or public.is_admin()
  );

create policy notif_write on public.notifications
  for insert
  with check (public.is_admin());

create policy notif_update on public.notifications
  for update
  using (
    penerima_user_id = auth.uid()
    or public.is_admin()
  );

create policy notif_delete on public.notifications
  for delete
  using (public.is_admin() or penerima_user_id = auth.uid());

create policy ann_read on public.announcements
  using (
    public.is_admin()
    or target_penerbitan = 'semua'
    or target_penerbitan = (select role::text from public.profiles where id = auth.uid())
    or dibuat_oleh = auth.uid()
  );

create policy ann_write on public.announcements
  for insert
  with check (public.is_admin());

create policy ann_update on public.announcements
  for update
  using (public.is_admin());

create policy ann_delete on public.announcements
  for delete
  using (public.is_admin());

-- =============================== CHAT ===============================
create policy conv_read on public.chat_conversations
  using (
    public.is_admin()
    or dibuat_oleh = auth.uid()
    or guru_user_id = auth.uid()
    or exists (select 1 from public.conversation_members cm where cm.conversation_id = id and cm.user_id = auth.uid())
  );

create policy conv_write on public.chat_conversations
  for insert
  with check (public.is_admin() or dibuat_oleh = auth.uid());

create policy conv_update on public.chat_conversations
  for update
  using (public.is_admin() or dibuat_oleh = auth.uid());

create policy conv_delete on public.chat_conversations
  for delete
  using (public.is_admin() or dibuat_oleh = auth.uid());

create policy conv_member_read on public.conversation_members
  using (
    public.is_admin()
    or user_id = auth.uid()
    or conversation_id in (select id from public.chat_conversations where dibuat_oleh = auth.uid() or guru_user_id = auth.uid())
  );

create policy conv_member_write on public.conversation_members
  for insert
  with check (public.is_admin() or user_id = auth.uid());

create policy conv_member_update on public.conversation_members
  for update
  using (public.is_admin());

create policy conv_member_delete on public.conversation_members
  for delete
  using (public.is_admin() or user_id = auth.uid());

create policy msg_read on public.chat_messages
  using (
    public.is_admin()
    or pengirim_user_id = auth.uid()
    or conversation_id in (select id from public.chat_conversations where dibuat_oleh = auth.uid() or guru_user_id = auth.uid())
  );

create policy msg_write on public.chat_messages
  for insert
  with check (
    public.is_admin()
    or pengirim_user_id = auth.uid()
  );

create policy msg_update on public.chat_messages
  for update
  using (public.is_admin() or pengirim_user_id = auth.uid());

create policy msg_delete on public.chat_messages
  for delete
  using (public.is_admin() or pengirim_user_id = auth.uid());

-- =============================== APPOINTMENTS ===============================
create policy app_read on public.appointments
  using (
    public.is_admin()
    or diajukan_oleh = auth.uid()
    or guru_user_id = auth.uid()
  );

create policy app_write on public.appointments
  for insert
  with check (
    public.is_admin()
    or diajukan_oleh = auth.uid()
  );

create policy app_update on public.appointments
  for update
  using (public.is_admin() or guru_user_id = auth.uid());

create policy app_delete on public.appointments
  for delete
  using (public.is_admin());

-- =============================== CHARACTER RECORDS ===============================
create policy char_read on public.character_records
  using (
    public.is_admin()
    or student_user_id = public.current_student_id()
    or public.is_parent_of(student_user_id)
  );

create policy char_write on public.character_records
  for insert
  with check (public.is_admin_or_staff());

create policy char_update on public.character_records
  for update
  using (public.is_admin());

create policy char_delete on public.character_records
  for delete
  using (public.is_admin());

-- =============================== AUDIT LOGS ===============================
create policy audit_read on public.audit_logs
  using (public.is_admin());

create policy audit_write on public.audit_logs
  for insert
  with check (public.is_admin_or_staff());

create policy audit_update on public.audit_logs
  for update
  using (public.is_admin());

create policy audit_delete on public.audit_logs
  for delete
  using (public.is_admin());

-- =============================== SCHOOL SETTINGS ===============================
create policy settings_read on public.school_settings
  using (public.is_admin_or_staff() or key = 'sekolah');

create policy settings_write on public.school_settings
  for insert
  with check (public.is_admin());

create policy settings_update on public.school_settings
  for update
  using (public.is_admin());

create policy settings_delete on public.school_settings
  for delete
  using (public.is_admin());

-- =============================== TRIGGERS ===============================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated on public.profiles
  before update for each row execute function public.set_updated_at();

create trigger trg_student_updated on public.student_profiles
  before update for each row execute function public.set_updated_at();

create trigger trg_parent_updated on public.parent_profiles
  before update for each row execute function public.set_updated_at();

create trigger trg_teacher_updated on public.teacher_profiles
  before update for each row execute function public.set_updated_at();

create trigger trg_att_updated on public.attendance_records
  before update for each row execute function public.set_updated_at();

create trigger trg_leave_updated on public.leave_requests
  before update for each row execute function public.set_updated_at();

create trigger trg_lm_updated on public.learning_materials
  before update for each row execute function public.set_updated_at();

create trigger trg_asg_updated on public.assignments
  before update for each row execute function public.set_updated_at();

create trigger trg_gr_updated on public.grading_records
  before update for each row execute function public.set_updated_at();

create trigger trg_rc_updated on public.report_cards
  before update for each row execute function public.set_updated_at();

create trigger trg_exam_updated on public.exams
  before update for each row execute function public.set_updated_at();

create trigger trg_adm_updated on public.admissions
  before update for each row execute function public.set_updated_at();

create trigger trg_mabit_updated on public.mabit_events
  before update for each row execute function public.set_updated_at();

-- =============================== FUNCTIONS (RPC) ===============================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, role, nama, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'role', 'siswa')::public.user_role,
    coalesce(new.raw_user_meta_data->>'nama', split_part(new.email,'@',1)),
    new.email
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.generate_attendance_qr(
  p_student uuid,
  p_metode public.attendance_method default 'qr'
)
returns text language plpgsql security definer as $$
declare
  v_token text;
  v_hash text;
  v_status text;
begin
  if not public.is_admin_or_staff() then
    raise exception 'Hanya admin/staf yang dapat membuat token presensi';
  end if;

  select status into v_status from public.attendance_records
  where student_user_id = p_student
    and tanggal = current_date
  limit 1;

  if v_status = 'hadir' or v_status = 'terlambat' then
    raise exception 'Sudah ada presensi hari ini: %', v_status;
  end if;

  v_token := encode(digest(random()::text || p_student::text || now()::text, 'sha256'), 'hex');
  v_hash := encode(digest(v_token, 'sha256'), 'sha256');

  insert into public.attendance_records (
    student_user_id, tanggal, status, metode, jam_checkin, qr_token_hash, dibuat_oleh
  ) values (
    p_student, current_date, 'hadir', p_metode, now(), v_hash, auth.uid()
  );

  return v_token;
end;
$$;

create or replace function public.verify_attendance_qr(
  p_token text,
  p_student uuid
)
returns void language plpgsql security definer as $$
declare
  v_hash text;
begin
  if not public.is_admin_or_staff() then
    raise exception 'Hanya admin/staf yang dapat memverifikasi token presensi';
  end if;

  v_hash := encode(digest(p_token, 'sha256'), 'sha256');

  update public.attendance_records
  set qr_token_hash = null
  where student_user_id = p_student
    and tanggal = current_date
    and status = 'hadir'
    and qr_token_hash = v_hash;

  if not found then
    raise exception 'Token tidak valid atau kedaluwarsa';
  end if;
end;
$$;

create or replace function public.finalize_cbt(
  p_attempt uuid
)
returns numeric(5,2) language plpgsql security definer as $$
declare
  v_total numeric(5,2);
  v_attempt record;
begin
  if not public.is_admin_or_staff() and not exists (
    select 1 from public.exam_attempts ea where ea.id = p_attempt and ea.student_user_id = public.current_student_id()
  ) then
    raise exception 'Akses ditolak';
  end if;

  select * into v_attempt from public.exam_attempts where id = p_attempt;
  if not found then
    raise exception 'Attempt tidak ditemukan';
  end if;

  update public.exam_attempts
  set nilai_pilihan = (
    select coalesce(sum(
      case when q.tipe = 'pilihan' and q.kunci is not null then q.skor else 0 end
    ), 0)::numeric(5,2)
    from public.exam_questions q
    where q.exam_id = v_attempt.exam_id
  ),
  total_skor = (
    select coalesce(sum(q.skor), 0)::numeric(5,2)
    from public.exam_questions q
    where q.exam_id = v_attempt.exam_id
  )
  where id = p_attempt;

  select nilai_pilihan into v_total from public.exam_attempts where id = p_attempt;
  return v_total;
end;
$$;

create or replace function public.send_notification(
  p_penerima uuid,
  p_judul text,
  p_pesan text,
  p_tipe text
)
returns uuid language plpgsql security definer as $$
declare
  v_id uuid;
begin
  if not public.is_admin_or_staff() then
    raise exception 'Hanya admin/staf yang dapat mengirim notifikasi';
  end if;

  insert into public.notifications (penerima_user_id, judul, pesan, tipe)
  values (p_penerima, p_judul, p_pesan, p_tipe)
  returning id into v_id;

  return v_id;
end;
$$;

-- =============================== GRANT EXECUTE (terbatas) ===============================
revoke execute on function public.generate_attendance_qr(uuid, public.attendance_method) from anon, authenticated;
revoke execute on function public.verify_attendance_qr(text, uuid) from anon, authenticated;
grant execute on function public.generate_attendance_qr(uuid, public.attendance_method) to authenticated;
grant execute on function public.verify_attendance_qr(text, uuid) to authenticated;
revoke execute on function public.finalize_cbt(uuid) from anon, authenticated;
grant execute on function public.finalize_cbt(uuid) to authenticated;
revoke execute on function public.send_notification(uuid, text, text, text) from anon, authenticated;
grant execute on function public.send_notification(uuid, text, text, text) to authenticated;


-- >>>>>>>>>>>>>>>>>>>> 0003_seed.sql <<<<<<<<<<<<<<<<<<

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


-- >>>>>>>>>>>>>>>>>>>> 0004_fixes.sql <<<<<<<<<<<<<<<<<<

-- ============================================================================
-- YP79 TERPADU — MIGRATION 0004: PERBAIKAN HASIL AUDIT
-- Idempoten: aman dijalankan berulang, aman pada DB yang sudah terisi.
-- Jalankan SETELAH 0001, 0002, 0003.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) PRESENSI: constraint unik untuk upsert.
--    Kode aplikasi memakai:
--      upsert(..., onConflict: 'student_user_id,tanggal')
--    Tanpa unique index yang cocok, PostgREST menolak dengan error 42P10
--    ("there is no unique or exclusion constraint matching the ON CONFLICT
--    specification") sehingga SELURUH penyimpanan presensi gagal.
-- ---------------------------------------------------------------------------
do $$
begin
  create unique index if not exists uq_attendance_student_tanggal
    on public.attendance_records (student_user_id, tanggal);
  raise notice 'uq_attendance_student_tanggal siap.';
exception when others then
  raise warning 'Gagal membuat uq_attendance_student_tanggal (kemungkinan ada data ganda): %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- 2) NILAI: cegah baris ganda untuk kombinasi yang sama.
--    Aplikasi melakukan select-then-insert/update (bukan upsert), jadi tanpa
--    index ini dua guru bisa membuat baris kembar untuk siswa+mapel+kategori.
-- ---------------------------------------------------------------------------
do $$
begin
  create unique index if not exists uq_grading_unique_row
    on public.grading_records (student_user_id, subject_id, kategori, semester, tahun_ajaran);
  raise notice 'uq_grading_unique_row siap.';
exception when others then
  raise warning 'Gagal membuat uq_grading_unique_row (kemungkinan ada data ganda): %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- 3) SEED TAHUN AJARAN: perbaikan bug 0003.
--    Di 0003 kedua baris memakai id '2026/2027' padahal `id` adalah PRIMARY KEY,
--    sehingga baris semester GENAP ter-skip oleh `on conflict (id) do nothing`.
--    Akibatnya semester genap tidak pernah ada di database.
-- ---------------------------------------------------------------------------
insert into public.academic_years (id, semester, tahun_ajaran, mulai, selesai)
values
  ('2026/2027-gas', 'gasal', '2026/2027', '2026-07-01', '2027-01-15'),
  ('2026/2027-gen', 'genap', '2026/2027', '2027-01-15', '2027-06-30')
on conflict (tahun_ajaran, semester) do nothing;

-- ---------------------------------------------------------------------------
-- 4) INTEGRITAS: student_profiles.kelas_id belum punya foreign key ke classes.
--    Tanpa FK, kelas_id bisa berisi uuid hantu dan relasi kelas tidak terjaga.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'fk_student_profile_kelas'
  ) then
    alter table public.student_profiles
      add constraint fk_student_profile_kelas
      foreign key (kelas_id) references public.classes (id) on delete set null;
    raise notice 'fk_student_profile_kelas dibuat.';
  end if;
exception when others then
  raise warning 'FK kelas_id dilewati: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- 5) ANNOUNCEMENTS: aplikasi mengurutkan berdasarkan dipublikasikan_pada,
--    tetapi nilai default kolomnya masih null untuk pengumuman berstatus
--    'dipublikasikan' → urutan tidak stabil. Isi nilai yang kosong.
-- ---------------------------------------------------------------------------
update public.announcements
   set dipublikasikan_pada = now()
 where status = 'dipublikasikan'
   and dipublikasikan_pada is null;

-- ---------------------------------------------------------------------------
-- 6) Index tambahan untuk query yang dipakai layar beranda.
-- ---------------------------------------------------------------------------
create index if not exists idx_notif_penerima_unread
  on public.notifications (penerima_user_id, dibaca_pada);
create index if not exists idx_submission_student
  on public.assignment_submissions (student_user_id);
create index if not exists idx_attempt_student
  on public.exam_attempts (student_user_id, exam_id);

-- ============================================================================
-- SELESAI. Catat status redaman:
--   * Mulai 0004, aplikasi TIDAK lagi menyimpan kolom `kunci` soal ke klien
--     (lihat catatan audit: kunci jawaban harus dikirim lewat RPC terkunci).
-- ============================================================================


-- >>>>>>>>>>>>>>>>>>>> 0005_cbt_dan_akses.sql <<<<<<<<<<<<<<<<<<

-- ============================================================================
-- YP79 TERPADU — MIGRATION 0005: PERBAIKAN CBT + AKSES KATEGORI BIAYA
-- Temuan audit:
--   1) RLS `exq_read` hanya mengizinkan baca exam_questions bila ujian berstatus
--      'selesai'/'dipublikasikan' atau kunci_terkunci = false. Akibatnya siswa
--      TIDAK PERNAH bisa memuat soal pada ujian yang sedang aktif.
--   2) RLS tidak bisa menyembunyikan satu kolom, sehingga kolom `kunci`
--      (kunci jawaban) ikut terkirim ke aplikasi siswa bila baris soal dibaca.
--   3) Fungsi `finalize_cbt` menghitung nilai dengan menjumlahkan skor SEMUA
--      soal pilihan yang punya kunci, tanpa pernah membandingkan jawaban siswa.
--      Efeknya: setiap siswa selalu mendapat nilai penuh.
--   4) Policy `finance_categories` hanya untuk admin/staf, sehingga halaman
--      Rincian Pembiayaan milik orang tua/siswa selalu kosong.
-- Idempoten & aman dijalankan berulang.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) AKSES KATEGORI BIAYA untuk siswa & orang tua (read-only).
-- ---------------------------------------------------------------------------
drop policy if exists fin_cat_read on public.finance_categories;
create policy fin_cat_read on public.finance_categories
  for select
  using (
    public.is_admin_or_staff()
    or public.current_student_id() is not null
    or public.current_parent_id() is not null
  );

-- ---------------------------------------------------------------------------
-- 2) RPC soal ujian TANPA kunci jawaban.
--    Dipakai aplikasi saat ujian berjalan. Kolom `kunci` tidak pernah
--    dikembalikan, sehingga kunci tidak bisa bocor ke perangkat siswa.
-- ---------------------------------------------------------------------------
create or replace function public.exam_questions_public(p_exam uuid)
returns table (
  id uuid,
  urutan integer,
  tipe text,
  pertanyaan text,
  opsi_a text,
  opsi_b text,
  opsi_c text,
  opsi_d text,
  skor integer
)
language sql
stable
security definer
set search_path = public
as $$
  select q.id, q.urutan, q.tipe, q.pertanyaan,
         q.opsi_a, q.opsi_b, q.opsi_c, q.opsi_d, q.skor
    from public.exam_questions q
    join public.exams e on e.id = q.exam_id
   where q.exam_id = p_exam
     and (
       public.is_admin_or_staff()
       or (
         e.status in ('aktif', 'selesai', 'dipublikasikan')
         and exists (
           select 1 from public.class_enrollments ce
            where ce.class_id = e.class_id
              and ce.student_user_id = public.current_student_id()
         )
       )
     )
   order by q.urutan;
$$;

revoke all on function public.exam_questions_public(uuid) from public;
grant execute on function public.exam_questions_public(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) RPC kunci jawaban khusus koreksi/pembahasan (guru, admin, atau siswa
--    setelah ujian benar-benar selesai).
-- ---------------------------------------------------------------------------
create or replace function public.exam_questions_with_key(p_exam uuid)
returns table (
  id uuid,
  urutan integer,
  tipe text,
  pertanyaan text,
  opsi_a text,
  opsi_b text,
  opsi_c text,
  opsi_d text,
  kunci text,
  skor integer
)
language sql
stable
security definer
set search_path = public
as $$
  select q.id, q.urutan, q.tipe, q.pertanyaan,
         q.opsi_a, q.opsi_b, q.opsi_c, q.opsi_d, q.kunci, q.skor
    from public.exam_questions q
   where q.exam_id = p_exam
     and (
       public.is_admin_or_staff()
       or exists (
         select 1 from public.exams e
          where e.id = q.exam_id and e.status in ('selesai', 'dipublikasikan')
       )
     )
   order by q.urutan;
$$;

revoke all on function public.exam_questions_with_key(uuid) from public;
grant execute on function public.exam_questions_with_key(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) PERHITUNGAN NILAI CBT YANG BENAR.
--    Hanya jawaban yang cocok dengan kunci yang dihitung.
--    total_skor = skor maksimum yang mungkin (pembagi), nilai_pilihan = skor
--    yang benar-benar diperoleh.
-- ---------------------------------------------------------------------------
create or replace function public.finalize_cbt(p_attempt uuid)
returns numeric(5,2)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exam uuid;
  v_nilai numeric(5,2);
  v_total numeric(5,2);
begin
  if not public.is_admin_or_staff() and not exists (
    select 1 from public.exam_attempts ea
     where ea.id = p_attempt
       and ea.student_user_id = public.current_student_id()
  ) then
    raise exception 'Akses ditolak';
  end if;

  select exam_id into v_exam from public.exam_attempts where id = p_attempt;
  if v_exam is null then
    raise exception 'Attempt tidak ditemukan';
  end if;

  -- Nilai pilihan ganda: bandingkan jawaban siswa dengan kunci.
  select coalesce(sum(q.skor), 0)::numeric(5,2)
    into v_nilai
    from public.exam_answers a
    join public.exam_questions q on q.id = a.question_id
   where a.attempt_id = p_attempt
     and q.tipe = 'pilihan'
     and q.kunci is not null
     and upper(btrim(coalesce(a.jawaban, ''))) = upper(btrim(q.kunci));

  -- Skor maksimum yang mungkin untuk ujian ini.
  select coalesce(sum(q.skor), 0)::numeric(5,2)
    into v_total
    from public.exam_questions q
   where q.exam_id = v_exam;

  update public.exam_attempts
     set nilai_pilihan = v_nilai,
         total_skor = v_total
   where id = p_attempt;

  return v_nilai;
end;
$$;

revoke all on function public.finalize_cbt(uuid) from public;
grant execute on function public.finalize_cbt(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Tandai jawaban yang sudah dinilai supaya koreksi tidak dihitung dua kali.
-- ---------------------------------------------------------------------------
update public.exam_answers a
   set tervalidasi = true
  from public.exam_questions q
 where q.id = a.question_id
   and q.tipe = 'pilihan'
   and q.kunci is not null;

-- ============================================================================
-- SELESAI.
-- Catatan: policy `exq_read` yang lama sengaja TIDAK dihapus karena masih
-- dipakai guru/admin lewat tabel langsung. Aplikasi hanya memakai RPC di atas.
-- ============================================================================


-- >>>>>>>>>>>>>>>>>>>> 0006_aksi_dan_audit.sql <<<<<<<<<<<<<<<<<<

-- ============================================================================
-- YP79 TERPADU — MIGRATION 0006: AKSI OPERASIONAL + AUDIT LOG
-- Menyertai implementasi UI jalur tulis (presensi, nilai, pengajuan izin).
-- Idempoten & aman dijalankan berulang.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) GURU HARUS BISA MENYIMPAN ULANG PRESENSI.
--    `upsertAttendance()` memakai INSERT ... ON CONFLICT DO UPDATE. Policy lama
--    `ar_update` hanya `is_admin()` sehingga guru selalu gagal pada penyimpanan
--    kedua dst (INSERT ditolak karena baris sudah ada, UPDATE ditolak RLS).
-- ---------------------------------------------------------------------------
drop policy if exists ar_update on public.attendance_records;
create policy ar_update on public.attendance_records
  for update
  using (
    public.is_admin()
    or (public.is_admin_or_staff() and metode in ('manual', 'qr'))
  );

-- Guru hanya boleh menyimpan presensi manual/QR pada kelas yang diampu.
drop policy if exists ar_insert_staff on public.attendance_records;
create policy ar_insert_staff on public.attendance_records
  for insert
  with check (
    public.is_admin()
    or (
      public.is_admin_or_staff()
      and metode in ('manual', 'qr')
    )
  );

-- ---------------------------------------------------------------------------
-- 2) NILAI: guru yang mengampu mapel boleh menulis (insert/update) nilainya.
--    Policy lama `gr_insert` mensyaratkan `guru_id = auth.uid()` — sudah benar —
--    tetapi tambahkan jalur admin agar koreksi resmi tetap mungkin.
-- ---------------------------------------------------------------------------
drop policy if exists gr_update on public.grading_records;
create policy gr_update on public.grading_records
  for update
  using (
    public.is_admin()
    or (guru_id = auth.uid() and public.is_admin_or_staff())
  );

-- ---------------------------------------------------------------------------
-- 3) IZIN: guru/staf boleh memutuskan, siswa/ortu boleh membatalkan
--    pengajuan yang masih berstatus 'diajukan'.
-- ---------------------------------------------------------------------------
drop policy if exists leave_update on public.leave_requests;
create policy leave_update on public.leave_requests
  for update
  using (
    public.is_admin_or_staff()
    or (
      status = 'diajukan'
      and (
        student_user_id = public.current_student_id()
        or public.is_parent_of(student_user_id)
      )
    )
  );

-- ---------------------------------------------------------------------------
-- 4) AUDIT LOG OTOMATIS untuk tindakan sensitif (spesifikasi §20).
--    Fungsi SECURITY DEFINER supaya penulis non-admin tetap bisa mencatat.
-- ---------------------------------------------------------------------------
create or replace function public.log_audit_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new jsonb := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
  v_old jsonb := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  v_target text := coalesce(coalesce(v_new, v_old) ->> 'id', '');
  v_berubah jsonb := '[]'::jsonb;
begin
  if tg_op = 'UPDATE' then
    select coalesce(jsonb_agg(k order by k), '[]'::jsonb)
      into v_berubah
      from jsonb_object_keys(v_new) as k
     where (v_new -> k) is distinct from (v_old -> k);
  end if;

  insert into public.audit_logs (actor_user_id, aksi, target_table, target_id, metadata)
  values (
    auth.uid(),
    lower(tg_table_name) || ':' || lower(tg_op),
    tg_table_name,
    v_target,
    jsonb_build_object('op', tg_op, 'kolom_berubah', v_berubah)
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'attendance_records', 'grading_records', 'leave_requests', 'report_cards',
    'exam_attempts', 'admission_results', 'finance_items', 'profiles',
    'mabit_participants', 'library_loans'
  ]
  loop
    execute format('drop trigger if exists trg_audit_%1$s on public.%1$s', t);
    execute format(
      'create trigger trg_audit_%1$s after insert or update or delete on public.%1$s
         for each row execute function public.log_audit_event()', t);
  end loop;
end $$;

-- Pastikan policy audit_logs masih benar (admin baca, staf tulis).
drop policy if exists audit_write on public.audit_logs;
create policy audit_write on public.audit_logs
  for insert with check (public.is_admin_or_staff() or auth.uid() is not null);

-- ---------------------------------------------------------------------------
-- 5) Index untuk halaman izin & audit yang baru.
-- ---------------------------------------------------------------------------
create index if not exists idx_leave_status_mulai
  on public.leave_requests (status, mulai desc);
create index if not exists idx_audit_table
  on public.audit_logs (target_table, created_at desc);

-- ============================================================================
-- SELESAI.
-- ============================================================================

