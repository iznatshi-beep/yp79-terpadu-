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
