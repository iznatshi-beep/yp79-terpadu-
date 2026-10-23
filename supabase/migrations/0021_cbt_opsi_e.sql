-- 0021: Fix opsi_e hilang di RPC exam_session_start.
-- Editor guru CBT bisa membuat soal dengan 5 opsi (A–E),
-- tetapi RPC exam_session_start sebelumnya hanya mengirim
-- opsi_a s.d. opsi_d. Siswa tidak melihat opsi E.

create or replace function public.exam_session_start(p_exam uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_exam exams%rowtype;
  v_attempt exam_attempts%rowtype;
  v_max int;
  v_n int;
  v_sisa int;
  v_questions jsonb;
  v_answers jsonb;
begin
  select * into v_exam from exams where id = p_exam;
  if v_exam.id is null then
    raise exception 'Ujian tidak ditemukan';
  end if;

  if v_exam.status <> 'aktif'
     or (v_exam.mulai is not null and now() < v_exam.mulai)
     or v_exam.selesai is not null and now() > v_exam.selesai then
    raise exception 'Ujian belum dibuka / sudah ditutup';
  end if;

  select * into v_attempt
    from exam_attempts
   where exam_id = p_exam
     and student_user_id = v_uid
   order by percobaan desc
   limit 1;

  if v_attempt.id is not null and v_attempt.status = 'berlangsung' then
    v_sisa := greatest(
      0,
      extract(epoch from (
        (v_attempt.mulai + make_interval(mins => coalesce(v_exam.durasi_menit, 60))) - now()
      ))::int
    );
  else
    if v_attempt.percobaan >= coalesce(v_exam.jumlah_percobaan, 1) then
      raise exception 'Jumlah percobaan sudah tercapai';
    end if;
    insert into exam_attempts (exam_id, student_user_id, percobaan, mulai, status)
    values (v_exam.id, v_uid, v_attempt.percobaan + 1, now(), 'berlangsung')
    returning * into v_attempt;
    v_sisa := coalesce(v_exam.durasi_menit, 60) * 60;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'sisa_detik', v_sisa,
    'durasi_menit', v_exam.durasi_menit,
    'percobaan', v_attempt.percobaan,
    'soal', coalesce((
      select jsonb_agg(jsonb_build_object(
                 'id', q.id, 'tipe', q.tipe, 'pertanyaan', q.pertanyaan,
                 'opsi_a', q.opsi_a, 'opsi_b', q.opsi_b,
                 'opsi_c', q.opsi_c, 'opsi_d', q.opsi_d,
                 'opsi_e', q.opsi_e,
                 'skor', q.skor, 'gambar_url', q.gambar_url)
                 order by q.urutan)
      from exam_questions q where q.exam_id = p_exam
    ), '[]'::jsonb),
    'jawaban', coalesce((
      select jsonb_object_agg(a.question_id,
               jsonb_build_object('jawaban', a.jawaban, 'ragu', a.ragu))
      from exam_answers a
      where a.attempt_id = v_attempt.id
    ), '{}'::jsonb)
  );
end;
$$;

comment on function public.exam_session_start(uuid) is
  'Mulai/lanjut sesi ujian CBT; return attempt_id, sisa_detik, soal (termasuk opsi_e), dan jawaban tersimpan.';
