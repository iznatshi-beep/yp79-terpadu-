-- ============================================================================
-- YP79 TERPADU — MIGRATION 0008: CHAT (MULAI PERCAKAPAN) + AKSES NAMA GURU
-- Temuan yang diperbaiki di sini:
--   1) Aplikasi membaca kolom `chat_conversations.nama_pembuat` yang TIDAK ADA
--      di schema (kolomnya: id, dibuat_oleh, guru_user_id, created_at) sehingga
--      daftar chat selalu menampilkan judul "Percakapan".
--   2) Orang tua/siswa TIDAK BOLEH membaca `teacher_profiles`
--      (policy: is_admin() or user_id = auth.uid() or is_admin_or_staff()),
--      sehingga mereka tidak bisa memilih guru untuk memulai percakapan.
--      Solusi: RPC SECURITY DEFINER yang HANYA mengembalikan id + nama
--      (tanpa no_hp/alamat — sesuai aturan privasi pada spesifikasi).
--   3) Tidak ada jalur resmi untuk MEMBUAT percakapan, sehingga chat tidak
--      pernah punya isi. RPC start_conversation() menangani pembuatan
--      percakapan + keanggotaan dalam satu transaksi.
-- Idempoten & aman dijalankan berulang.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Daftar guru: hanya id + nama.
-- ---------------------------------------------------------------------------
create or replace function public.list_guru()
returns table (user_id uuid, nama text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id as user_id, p.nama
    from public.profiles p
   where p.role in ('guru', 'guru_pembimbing')
   order by p.nama;
$$;

revoke all on function public.list_guru() from public;
grant execute on function public.list_guru() to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Mulai percakapan dengan seorang guru.
--    Mengembalikan id percakapan yang sudah ada (kalau sebelumnya pernah
--    dibuat oleh user yang sama untuk guru yang sama) supaya tidak menumpuk.
-- ---------------------------------------------------------------------------
create or replace function public.start_conversation(p_guru uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_guru_role public.user_role;
begin
  if auth.uid() is null then
    raise exception 'Harus login';
  end if;

  select role into v_guru_role from public.profiles where id = p_guru;
  if v_guru_role is null or v_guru_role not in ('guru', 'guru_pembimbing') then
    raise exception 'Tujuan harus seorang guru';
  end if;

  select id into v_id
    from public.chat_conversations
   where dibuat_oleh = auth.uid()
     and guru_user_id = p_guru
   order by created_at desc
   limit 1;

  if v_id is null then
    insert into public.chat_conversations (dibuat_oleh, guru_user_id)
    values (auth.uid(), p_guru)
    returning id into v_id;
  end if;

  -- Pastikan kedua pihak terdaftar sebagai anggota (idempoten).
  insert into public.conversation_members (conversation_id, user_id)
  values (v_id, auth.uid())
  on conflict (conversation_id, user_id) do nothing;

  insert into public.conversation_members (conversation_id, user_id)
  values (v_id, p_guru)
  on conflict (conversation_id, user_id) do nothing;

  return v_id;
end;
$$;

revoke all on function public.start_conversation(uuid) from public;
grant execute on function public.start_conversation(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Nama anggota percakapan (untuk judul daftar chat).
-- ---------------------------------------------------------------------------
create or replace function public.conversation_peers()
returns table (conversation_id uuid, user_id uuid, nama text, peran public.user_role)
language sql
stable
security definer
set search_path = public
as $$
  select cm.conversation_id, cm.user_id, p.nama, p.role
    from public.conversation_members cm
    join public.profiles p on p.id = cm.user_id
   where cm.conversation_id in (
     select c.id from public.chat_conversations c
      where public.is_admin()
         or c.dibuat_oleh = auth.uid()
         or c.guru_user_id = auth.uid()
         or public.is_conversation_member(c.id)
   );
$$;

revoke all on function public.conversation_peers() from public;
grant execute on function public.conversation_peers() to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Index untuk daftar chat + audit log viewer.
-- ---------------------------------------------------------------------------
create index if not exists idx_conv_dibuat
  on public.chat_conversations (dibuat_oleh, created_at desc);
create index if not exists idx_conv_guru
  on public.chat_conversations (guru_user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 5) Audit log: pastikan admin bisa membaca + index pencarian.
-- ---------------------------------------------------------------------------
drop policy if exists audit_read on public.audit_logs;
create policy audit_read on public.audit_logs
  for select
  using (public.is_admin());

create index if not exists idx_audit_aksi on public.audit_logs (aksi, created_at desc);

-- ============================================================================
-- SELESAI.
-- ============================================================================
