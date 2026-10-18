-- ============================================================================
-- YP79 TERPADU â€” SUPABASE SCHEMA (Migration 0001)
-- Jalankan seluruh isi file ini di Supabase SQL Editor (atau supabase db push).
-- ============================================================================

-- =============================== TYPES ===============================
-- PENTING: PostgreSQL TIDAK mendukung `create or replace type` (itu sintaks
-- Oracle). Versi sebelumnya memakai sintaks itu sehingga SELURUH migrasi 0001
-- gagal di baris ke-7 dengan: ERROR 42601 syntax error at or near "type".
-- Enum dibuat lewat blok DO dengan penangkap duplicate_object agar idempoten.
do $$ begin
  create type public.user_role as enum ('admin','guru','guru_pembimbing','siswa','orang_tua');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.attendance_status as enum ('hadir','terlambat','izin','sakit','alpa');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.attendance_method as enum ('manual','qr','rfid','mabit');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.grading_category as enum ('tugas','ujian','harian','prakarya','karakter');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.assignment_status as enum ('draft','dipublikasikan','dikumpulkan','keterlambatan','dinilai','dikembalikan');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.exam_status as enum ('draft','aktif','selesai','dipublikasikan');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.exam_attempt_status as enum ('menunggu','berlangsung','dikumpulkan','dinilai');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.invoice_status as enum ('menunggu','berhasil','gagal','keterlambatan');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.ppdb_status as enum ('draf','diajukan','pemeriksaan','perlu_perbaikan','lolos','tidak_lolos');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.leave_status as enum ('diajukan','diproses','disetujui','ditolak');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.mabit_participant_status as enum ('terdaftar','check_in','check_out','absen');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.memorization_status as enum ('diajukan','diverifikasi','ditolak','pengulangan');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.consent_status as enum ('menunggu','disetujui','ditolak','kedaluwarsa');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.appointment_status as enum ('diajukan','diterima','ditolak','selesai','dibatalkan');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.report_status as enum ('draf','periksa','dipublikasikan');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.notification_target as enum ('semua','admin','guru','siswa','orang_tua','kelas','mabit');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.bus_status as enum ('aktif','siaga','perjalanan','tidak_tersambung');
exception when duplicate_object then null; end $$;

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
