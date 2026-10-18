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
