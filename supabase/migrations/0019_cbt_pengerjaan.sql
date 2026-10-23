-- 0019: Sistem pengerjaan CBT kelas satu (port dari cbt-sekolah).
-- 1) exam_answers.ragu        — flag "ragu-ragu" per jawaban
-- 2) exam_attempts.pelanggaran + rincian — log anti-cheat dari client
-- 3) exam_questions.gambar_url — gambar soal (opsional)
-- 4) RPC ekosistem pengerjaan:
--    - exam_session_start   : buat/lanjut attempt, return attempt_id + soal
--      (tanpa kunci) + jawaban tersimpan + sisa_detik (server-authoritative)
--    - exam_save_answer     : upsert jawaban+ragu (idempotent)
--    - exam_submit          : selesaikan attempt + finalize nilai PG
--    - exam_pelanggaran     : catat pelanggaran anti-cheat per attempt
-- Semua SECURITY DEFINER, eksekusi hanya authenticated.

-- ----------------------------------------------------------------- kolom ---
alter table exam_questions
  add column if not exists gambar_url text,
  add column if not exists opsi_e text;
alter table exam_answers
  add column if not exists ragu boolean not null default false;
alter table exam_attempts
  add column if not exists pelanggaran int not null default 0;
comment on column exam_answers.ragu is 'Siswa menandai soal ragu-ragu (CBT).';
comment on column exam_questions.gambar_url is 'URL gambar soal (storage bucket lampiran).';

-- ---------------------------------------------------------------------------
-- 1) Sesi ujian: ambil soal + jawaban + sisa waktu dalam SATU RPC.
--    - Membuat attempt baru bila belum ada yang berlangsung (respek
--      jumlah_percobaan), atau melanjutkan attempt berstatus 'berlangsung'.
--    - Kunci jawaban tidak pernah dikirim ke client.
--    - sisa_detik dihitung server: durasi - (now - mulai). Timer client
--      hanya tampilan; reload/crash tidak menguntungkan siswa.
-- ---------------------------------------------------------------------------
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

  -- Jendela waktu ujian (server-side, TZ server; siswa tidak bisa mengakali).
  if v_exam.status <> 'aktif'
     or (v_exam.mulai is not null and now() < v_exam.mulai)
     or (v_exam.selesai is not null and now() > v_exam.selesai) then
    raise exception 'Ujian belum dibuka / sudah ditutup';
  end if;

  -- Attempt yang sedang berlangsung (resume) — percobaan terakhir.
  select * into v_attempt
    from exam_attempts
   where exam_id = p_exam
     and student_user_id = v_uid
   order by percobaan desc
   limit 1;

  if v_attempt.id is not null and v_attempt.status = 'berlangsung' then
    -- RESUME: pakai attempt lama + sisa waktu dari server.
    v_sisa := greatest(
      0,
      extract(epoch from (
        (v_attempt.mulai + make_interval(mins => coalesce(v_exam.durasi_menit, 60))) - now()
      ))::int
    );
  else
    -- Attempt baru: cek kuota percobaan.
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

-- ---------------------------------------------------------------------------
-- 2) Simpan satu jawaban (dipanggil flush batch tiap 2 menit / saat submit).
--    Idempotent (upsert); cek attempt milik sendiri + masih berlangsung.
-- ---------------------------------------------------------------------------
create or replace function public.exam_save_answer(
  p_attempt uuid, p_question uuid, p_jawaban text, p_ragu boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from exam_attempts a
     where a.id = p_attempt
       and a.student_user_id = auth.uid()
       and a.status = 'berlangsung'
  ) then
    raise exception 'Attempt tidak aktif';
  end if;

  insert into exam_answers (attempt_id, question_id, jawaban, ragu)
  values (p_attempt, p_question, nullif(trim(coalesce(p_jawaban, '')), ''), p_ragu)
  on conflict (attempt_id, question_id) do update
     set jawaban = excluded.jawaban,
         ragu    = excluded.ragu;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Kumpulkan ujian: idempotent, tandai selesai + langsung nilai PG.
-- ---------------------------------------------------------------------------
create or replace function public.exam_submit(p_attempt uuid)
returns numeric(5,2)
language plpgsql security definer set search_path = public as $$
declare
  v_attempt exam_attempts%rowtype;
  v_nilai numeric(5,2);
begin
  select * into v_attempt from exam_attempts where id = p_attempt;
  if v_attempt.id is null then
    raise exception 'Attempt tidak ditemukan';
  end if;
  if v_attempt.student_user_id <> auth.uid()
     and not exists (select 1 from profiles where id = auth.uid()
                      and role in ('admin','guru','guru_pembimbing')) then
    raise exception 'Akses ditolak';
  end if;

  -- idempotent: kalau sudah selesai, cukup kembalikan nilai lama.
  if v_attempt.status <> 'berlangsung' then
    select nilai_pilihan into v_nilai from exam_attempts where id = p_attempt;
    return coalesce(v_nilai, 0);
  end if;

  update exam_attempts
     set selesai = now(), status = 'dikumpulkan'
   where id = p_attempt;

  -- Nilai PG via finalize_cbt yang sudah ada.
  v_nilai := public.finalize_cbt(p_attempt);
  return v_nilai;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Catat pelanggaran anti-cheat (keluar app / overlay / back-button).
--    Idempotent per kejadian; siswa hanya boleh untuk attempt-nya sendiri.
-- ---------------------------------------------------------------------------
create or replace function public.exam_pelanggaran(p_attempt uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update exam_attempts
     set pelanggaran = pelanggaran + 1
   where id = p_attempt
     and student_user_id = auth.uid()
     and status = 'berlangsung';
end;
$$;

grant execute on function public.exam_session_start(uuid) to authenticated;
grant execute on function public.exam_save_answer(uuid, uuid, text, boolean) to authenticated;
grant execute on function public.exam_submit(uuid) to authenticated;
grant execute on function public.exam_pelanggaran(uuid) to authenticated;
