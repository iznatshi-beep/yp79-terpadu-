-- =============================================================================
-- 0017 — PEMINJAMAN PERPUSTAKAAN OLEH SISWA
-- =============================================================================
-- Sebelumnya hanya admin yang bisa membuat baris peminjaman (ll_write =
-- is_admin()). Siswa sekarang dapat meminjam langsung dari aplikasi untuk
-- dirinya sendiri; pengurangan stok dilakukan di sisi klien setelah insert
-- (RLS update stok hanya admin — siswa tetap tidak bisa mengubah stok).
-- =============================================================================

drop policy if exists ll_write on public.library_loans;
create policy ll_write on public.library_loans
  for insert with check (
    is_admin() or student_user_id = current_student_id()
  );
