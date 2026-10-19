-- =============================================================================
-- 0010 — ORANG TUA DAPAT MEMBACA DATA ANAKNYA (dan perbaikan tab shell)
-- =============================================================================
-- Masalah yang diperbaiki:
--   1. Dashboard orang tua menampilkan pilihan "Anak 1", "Anak 2" — bukan nama
--      anak. Penyebabnya: aplikasi hanya tahu daftar UUID anak, sedangkan
--      kebijakan RLS `profiles` hanya mengizinkan membaca profil SENDIRI
--      (`id = auth.uid()`) atau profil apa pun bagi admin. Jadi nama anak tidak
--      pernah bisa diambil, walaupun relasinya sudah diverifikasi admin.
--   2. Halaman guru tidak bisa menampilkan nama siswa di kelas yang diampu,
--      karena alasan yang sama.
--   3. Preferensi notifikasi pengguna tidak punya jalan baca/tulis sama sekali.
--
-- Prinsip yang dipegang: akses dibuka SESEMpit mungkin dan tetap terverifikasi
-- di server. Orang tua hanya boleh membaca profil siswa yang relasinya sudah
-- tercatat DAN `diverifikasi = true`; guru hanya membaca siswa yang berada di
-- kelas yang benar-benar diampu (wali kelas atau punya penugasan mengajar).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Pembantu: apakah saya orang tua/wali dari siswa ini?
--    SECURITY DEFINER supaya tidak terjadi rekursi RLS pada `parent_student`.
-- ---------------------------------------------------------------------------
create or replace function public.is_ortu_dari(p_student uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.parent_student ps
     where ps.parent_user_id = auth.uid()
       and ps.student_user_id = p_student
       and ps.diverifikasi = true
  );
$$;

-- ---------------------------------------------------------------------------
-- 2. Pembantu: apakah saya guru dari siswa ini?
--    Benar bila saya wali kelasnya, atau siswa terdaftar di kelas tempat saya
--    punya penugasan mengajar (tabel `teacher_assignments`).
-- ---------------------------------------------------------------------------
create or replace function public.is_guru_dari(p_student uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    -- wali kelas
    select 1
      from public.classes k
      join public.student_profiles sp on sp.kelas_id = k.id
     where sp.user_id = p_student
       and k.wali_kelas_id = auth.uid()
  ) or exists (
    -- punya penugasan mengajar di kelas siswa tersebut
    select 1
      from public.teacher_assignments ta
      join public.student_profiles sp on sp.kelas_id = ta.class_id
     where sp.user_id = p_student
       and ta.teacher_user_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- 3. Kebijakan baca `profiles`: tambah jalur orang tua dan guru.
--    Kebijakan lama (`profiles_baca_sendiri`) dibiarkan: PostgreSQL
--    menggabungkan kebijakan SELECT dengan OR, jadi ini murni menambah.
-- ---------------------------------------------------------------------------
drop policy if exists profiles_baca_anak on public.profiles;
create policy profiles_baca_anak on public.profiles
  for select to authenticated using (
    public.is_ortu_dari(id) or public.is_guru_dari(id)
  );

-- Nama guru perlu terlihat oleh orang tua (mis. wali kelas anak) untuk
-- menampilkan info kelas. Batasi hanya kolom yang aman lewat RPC, bukan
-- membuka seluruh tabel.
alter table public.teacher_profiles enable row level security;
drop policy if exists teacher_profiles_baca_semua on public.teacher_profiles;
drop policy if exists teacher_profiles_baca_guru on public.teacher_profiles;
create policy teacher_profiles_baca_guru on public.teacher_profiles
  for select to authenticated using (public.is_admin());
-- Semua pengguna yang sudah masuk boleh melihat DAFTAR GURU lewat RPC
-- `list_guru` (hanya id + nama, tanpa NIP/nomor HP). Jadi tabel mentahnya
-- tetap tertutup.

-- ---------------------------------------------------------------------------
-- 4. Kebijakan `student_profiles`: orang tua & guru boleh membaca siswa terkait.
-- ---------------------------------------------------------------------------
drop policy if exists student_profiles_baca_semua on public.student_profiles;
drop policy if exists student_profiles_baca_terkait on public.student_profiles;
create policy student_profiles_baca_terkait on public.student_profiles
  for select to authenticated using (
    user_id = auth.uid()
    or public.is_admin()
    or public.is_ortu_dari(user_id)
    or public.is_guru_dari(user_id)
  );

-- ---------------------------------------------------------------------------
-- 5. Kebijakan `parent_student`: orang tua hanya melihat relasinya sendiri.
-- ---------------------------------------------------------------------------
drop policy if exists parent_student_baca_semua on public.parent_student;
drop policy if exists parent_student_baca_terkait on public.parent_student;
create policy parent_student_baca_terkait on public.parent_student
  for select to authenticated using (
    parent_user_id = auth.uid()
    or student_user_id = auth.uid()
    or public.is_admin()
  );

-- ---------------------------------------------------------------------------
-- 6. Kebijakan `parent_profiles`: hanya dirinya + admin.
-- ---------------------------------------------------------------------------
drop policy if exists parent_profiles_baca_semua on public.parent_profiles;
drop policy if exists parent_profiles_baca_terkait on public.parent_profiles;
create policy parent_profiles_baca_terkait on public.parent_profiles
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- 7. RPC `anak_saya` — daftar anak bagi akun orang tua, lengkap dengan nama,
--    NIS, dan kelas. Inilah yang dipakai dashboard orang tua supaya menampilkan
--    NAMA ANAK, bukan "Anak 1".
-- ---------------------------------------------------------------------------
create or replace function public.anak_saya()
returns table (
  student_user_id uuid,
  nama text,
  nis text,
  kelas text,
  hubungan text
)
language sql stable security definer set search_path = public as $$
  select ps.student_user_id,
         coalesce(p.nama, sp.nama_lengkap, 'Siswa') as nama,
         sp.nis,
         k.nama as kelas,
         ps.hubungan
    from public.parent_student ps
    left join public.profiles p on p.id = ps.student_user_id
    left join public.student_profiles sp on sp.user_id = ps.student_user_id
    left join public.classes k on k.id = sp.kelas_id
   where ps.parent_user_id = auth.uid()
     and ps.diverifikasi = true
   order by coalesce(p.nama, sp.nama_lengkap, 'Siswa');
$$;

-- ---------------------------------------------------------------------------
-- 8. RPC `kelas_saya` — kelas yang diampu guru beserta jumlah siswanya.
-- ---------------------------------------------------------------------------
create or replace function public.kelas_saya()
returns table (
  class_id uuid,
  nama text,
  jenjang text,
  tahun_ajaran text,
  jumlah_siswa bigint
)
language sql stable security definer set search_path = public as $$
  select k.id, k.nama, k.jenjang, k.tahun_ajaran,
         (select count(*) from public.student_profiles sp where sp.kelas_id = k.id)
    from public.classes k
   where k.wali_kelas_id = auth.uid()
      or exists (select 1 from public.teacher_assignments ta
                  where ta.class_id = k.id and ta.teacher_user_id = auth.uid())
   order by k.nama;
$$;

-- ---------------------------------------------------------------------------
-- 9. CATATAN: `notification_preferences` dan `user_settings` TIDAK dibuat.
--    Keduanya ada di daftar rancangan awal, tetapi tidak pernah dipakai satu
--    halaman pun, jadi tidak dibuatkan tabel + kebijakan yang tidak berfungsi.
--    Preferensi notifikasi saat ini cukup dari `notifications.status_baca`.
--    Tambahkan tabelnya saat benar-benar ada halaman pengaturannya.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 10. Hak eksekusi RPC baru.
--     HANYA `authenticated`: policy di atas berjalan sebagai `anon` ketika
--     permintaan datang tanpa token, dan memanggil is_ortu_dari/is_guru_dari
--     sebagai anon ditolak. Fungsi-fungsi itu tidak perlu untuk pengguna yang
--     belum masuk (halaman login tidak menampilkan data sekolah).
-- ---------------------------------------------------------------------------
revoke all on function public.is_ortu_dari(uuid) from public, anon;
revoke all on function public.is_guru_dari(uuid) from public, anon;
revoke all on function public.anak_saya() from public, anon;
revoke all on function public.kelas_saya() from public, anon;

grant execute on function public.anak_saya() to authenticated;
grant execute on function public.kelas_saya() to authenticated;
grant execute on function public.is_ortu_dari(uuid) to authenticated;
grant execute on function public.is_guru_dari(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 12. Penanda migrasi.
-- ---------------------------------------------------------------------------
insert into public.schema_migrations (versi) values ('0010_akses_anak_dan_guru')
on conflict (versi) do nothing;
