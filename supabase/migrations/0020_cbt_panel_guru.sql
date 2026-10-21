-- 0020: Panel guru CBT — koreksi esai + daftar peserta.
-- 1) exam_answers.nilai_esai   — nilai manual guru untuk soal esai
-- 2) exam_attempts.nilai_esai  — subtotal esai (disimpan agar laporan cepat)
-- 3) RPC guru:
--    - exam_peserta(p_exam)     : daftar attempt + nama/NIS siswa + pelanggaran
--    - exam_esai_jawaban(p_att) : jawaban esai milik attempt (untuk dikoreksi)
--    - exam_nilai_esai          : simpan nilai esai 1 soal + recompute subtotal

alter table exam_answers
  add column if not exists nilai_esai numeric(5,2);
alter table exam_attempts
  add column if not exists nilai_esai numeric(5,2) default 0;

comment on column exam_answers.nilai_esai is
  'Nilai manual guru untuk soal esai (0..skor soal).';
comment on column exam_attempts.nilai_esai is
  'Subtotal nilai esai; nilai total = nilai_pilihan + nilai_esai.';

-- ---------------------------------------------------------------------------
-- Daftar peserta satu ujian (staff only): attempt + nama + NIS + pelanggaran.
-- ---------------------------------------------------------------------------
create or replace function public.exam_peserta(p_exam uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.nama), '[]'::jsonb)
  from (
    select a.id, a.percobaan, a.status, a.mulai, a.selesai,
           a.pelanggaran, a.nilai_pilihan, a.nilai_esai, a.total_skor,
           p.nama_lengkap as nama, p.nis
    from exam_attempts a
    left join student_profiles p on p.user_id = a.student_user_id
    where a.exam_id = p_exam
  ) x;
$$;

-- ---------------------------------------------------------------------------
-- Jawaban esai satu attempt (untuk halaman koreksi).
-- ---------------------------------------------------------------------------
create or replace function public.exam_esai_jawaban(p_attempt uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.urutan), '[]'::jsonb)
  from (
    select q.id as question_id, q.urutan, q.pertanyaan, q.skor,
           a.jawaban, a.nilai_esai
    from exam_answers a
    join exam_questions q on q.id = a.question_id
    where a.attempt_id = p_attempt and q.tipe = 'esai'
  ) x;
$$;

-- ---------------------------------------------------------------------------
-- Simpan nilai esai satu soal (guru/admin pemilik ujian), lalu recompute
-- subtotal esai attempt. Nilai final = nilai_pilihan + nilai_esai.
-- ---------------------------------------------------------------------------
create or replace function public.exam_nilai_esai(
  p_attempt uuid, p_question uuid, p_nilai numeric)
returns numeric(5,2)
language plpgsql security definer set search_path = public as $$
declare
  v_exam uuid;
  v_max numeric;
begin
  if not public.is_admin_or_staff() then
    raise exception 'Akses ditolak';
  end if;

  select exam_id into v_exam from exam_attempts where id = p_attempt;
  if v_exam is null then raise exception 'Attempt tidak ditemukan'; end if;

  select skor into v_max from exam_questions where id = p_question;
  if v_max is null then raise exception 'Soal tidak ditemukan'; end if;
  if p_nilai < 0 or p_nilai > v_max then
    raise exception 'Nilai harus 0..%', v_max;
  end if;

  update exam_answers
     set nilai_esai = p_nilai
   where attempt_id = p_attempt and question_id = p_question;

  update exam_attempts a
     set nilai_esai = coalesce((
       select sum(x.nilai_esai)
       from exam_answers x
       join exam_questions q2 on q2.id = x.question_id
       where x.attempt_id = p_attempt and q2.tipe = 'esai'
     ), 0)
   where a.id = p_attempt;

  select (a.nilai_pilihan + a.nilai_esai) into v_max
    from exam_attempts a where a.id = p_attempt;
  return v_max;
end;
$$;

grant execute on function public.exam_peserta(uuid) to authenticated;
grant execute on function public.exam_esai_jawaban(uuid) to authenticated;
grant execute on function public.exam_nilai_esai(uuid, uuid, numeric) to authenticated;
