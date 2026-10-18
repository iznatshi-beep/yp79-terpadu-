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
    -- Perbaikan audit: kolomnya `diverifikasi_oleh`, bukan `verified_by`
    -- (migrasi 0002 selalu gagal dengan ERROR 42703 di sini).
    or (diverifikasi = true and diverifikasi_oleh = auth.uid())
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
    -- Perbaikan audit: `target_penerbitan` bertipe enum notification_target.
    -- Membandingkan enum dengan hasil `role::text` butuh cast eksplisit,
    -- kalau tidak: ERROR 42883 operator does not exist: notification_target = text.
    or target_penerbitan::text = (select role::text from public.profiles where id = auth.uid())
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

-- Perbaikan audit: sebelumnya ditulis
--   create trigger <nama> on <tabel> before update for each row ...
-- PostgreSQL MENOLAK bentuk itu karena BEFORE/AFTER wajib mendahului ON
-- (ERROR 42601 syntax error at or near "on"). Urutan sudah dibetulkan dan
-- diberi drop-if-exists supaya migrasi aman dijalankan ulang.
drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_student_updated on public.student_profiles;
create trigger trg_student_updated
  before update on public.student_profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_parent_updated on public.parent_profiles;
create trigger trg_parent_updated
  before update on public.parent_profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_teacher_updated on public.teacher_profiles;
create trigger trg_teacher_updated
  before update on public.teacher_profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_att_updated on public.attendance_records;
create trigger trg_att_updated
  before update on public.attendance_records
  for each row execute function public.set_updated_at();

drop trigger if exists trg_leave_updated on public.leave_requests;
create trigger trg_leave_updated
  before update on public.leave_requests
  for each row execute function public.set_updated_at();

drop trigger if exists trg_lm_updated on public.learning_materials;
create trigger trg_lm_updated
  before update on public.learning_materials
  for each row execute function public.set_updated_at();

drop trigger if exists trg_asg_updated on public.assignments;
create trigger trg_asg_updated
  before update on public.assignments
  for each row execute function public.set_updated_at();

drop trigger if exists trg_gr_updated on public.grading_records;
create trigger trg_gr_updated
  before update on public.grading_records
  for each row execute function public.set_updated_at();

drop trigger if exists trg_rc_updated on public.report_cards;
create trigger trg_rc_updated
  before update on public.report_cards
  for each row execute function public.set_updated_at();

drop trigger if exists trg_exam_updated on public.exams;
create trigger trg_exam_updated
  before update on public.exams
  for each row execute function public.set_updated_at();

drop trigger if exists trg_adm_updated on public.admissions;
create trigger trg_adm_updated
  before update on public.admissions
  for each row execute function public.set_updated_at();

drop trigger if exists trg_mabit_updated on public.mabit_events;
create trigger trg_mabit_updated
  before update on public.mabit_events
  for each row execute function public.set_updated_at();

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
