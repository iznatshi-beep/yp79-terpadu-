-- ============================================================================
-- YP79 TERPADU — MIGRATION 0007: PERBAIKAN RLS CHAT (REKURSI) + EKSTENSI
-- Temuan audit (terbukti dari server, bukan dugaan):
--   ERROR 500  42P17  infinite recursion detected in policy for relation
--                     "chat_conversations" / "conversation_members" /
--                     "chat_messages"
--
-- Penyebabnya siklus antar policy:
--   policy conv_read         ON chat_conversations  -> SELECT dari conversation_members
--   policy conv_member_read  ON conversation_members -> SELECT dari chat_conversations
--   policy msg_read          ON chat_messages       -> SELECT dari chat_conversations
-- PostgreSQL menerapkan RLS pada subquery di dalam policy, sehingga ketiganya
-- saling memicu tanpa henti. Akibatnya chat TIDAK BISA DIBACA sama sekali
-- (bukan hanya lambat — requestnya ditolak server).
--
-- Solusi: pindahkan pengecekan keanggotaan/kepemilikan ke fungsi SECURITY
-- DEFINER. Fungsi ini berjalan sebagai pemilik tabel sehingga melewati RLS
-- dan memutus siklusnya.
-- Idempoten & aman dijalankan berulang.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Helper pemutus rekursi.
-- ---------------------------------------------------------------------------
create or replace function public.is_conversation_member(p_conv uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.conversation_members cm
     where cm.conversation_id = p_conv
       and cm.user_id = auth.uid()
  );
$$;

create or replace function public.is_conversation_owner(p_conv uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.chat_conversations c
     where c.id = p_conv
       and (c.dibuat_oleh = auth.uid() or c.guru_user_id = auth.uid())
  );
$$;

revoke all on function public.is_conversation_member(uuid) from public;
revoke all on function public.is_conversation_owner(uuid) from public;
grant execute on function public.is_conversation_member(uuid) to authenticated;
grant execute on function public.is_conversation_owner(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Policy chat tanpa subquery lintas-tabel (pakai helper di atas).
-- ---------------------------------------------------------------------------
drop policy if exists conv_read on public.chat_conversations;
create policy conv_read on public.chat_conversations
  for select
  using (
    public.is_admin()
    or dibuat_oleh = auth.uid()
    or guru_user_id = auth.uid()
    or public.is_conversation_member(id)
  );

drop policy if exists conv_member_read on public.conversation_members;
create policy conv_member_read on public.conversation_members
  for select
  using (
    public.is_admin()
    or user_id = auth.uid()
    or public.is_conversation_owner(conversation_id)
  );

drop policy if exists msg_read on public.chat_messages;
create policy msg_read on public.chat_messages
  for select
  using (
    public.is_admin()
    or pengirim_user_id = auth.uid()
    or public.is_conversation_member(conversation_id)
    or public.is_conversation_owner(conversation_id)
  );

-- Mengirim pesan hanya boleh di percakapan sendiri / yang diikuti.
drop policy if exists msg_write on public.chat_messages;
create policy msg_write on public.chat_messages
  for insert
  with check (
    pengirim_user_id = auth.uid()
    and (
      public.is_admin()
      or public.is_conversation_member(conversation_id)
      or public.is_conversation_owner(conversation_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 3) EKSTENSI pgcrypto untuk presensi QR.
--    Fungsi generate_attendance_qr / verify_attendance_qr memakai digest()
--    (sha256), tetapi migrasi sebelumnya TIDAK PERNAH membuat ekstensinya dan
--    tidak mengatur search_path — sehingga fungsi itu gagal saat dipanggil.
-- ---------------------------------------------------------------------------
do $$
begin
  create extension if not exists pgcrypto with schema extensions;
exception when others then
  raise warning 'pgcrypto tidak bisa dibuat otomatis: %', sqlerrm;
end $$;

do $$
begin
  execute 'alter function public.generate_attendance_qr(uuid, public.attendance_method) set search_path = public, extensions';
exception when others then
  raise warning 'generate_attendance_qr: %', sqlerrm;
end $$;

do $$
begin
  execute 'alter function public.verify_attendance_qr(text, uuid) set search_path = public, extensions';
exception when others then
  raise warning 'verify_attendance_qr: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- 4) Index untuk query chat yang sekarang benar-benar bisa jalan.
-- ---------------------------------------------------------------------------
create index if not exists idx_msg_conv_created
  on public.chat_messages (conversation_id, created_at desc);
create index if not exists idx_cm_user
  on public.conversation_members (user_id, conversation_id);

-- ============================================================================
-- SELESAI. Setelah migrasi ini, seluruh 59 tabel harus bisa dibaca
-- (verify_supabase.py: OK 59/59, ERROR 0).
-- ============================================================================
