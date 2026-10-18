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
