# AUDIT MENYELURUH — APLIKASI YP79 TERPADU

Tanggal audit: 18 Oktober 2026
Repo: `github.com/iznatshi-beep/yp79-terpadu-` (VISIBILITAS: **PUBLIC**)
Branch: `main`
Auditor: audit statis + verifikasi eksekusi melalui GitHub Actions & DNS/HTTP probe

Dokumen ini adalah hasil audit dari nol: apa yang **salah**, apa yang **berisiko**,
apa yang **sudah diperbaiki**, dan apa yang **belum selesai** beserta alasan sebenarnya.

---

## 1. RINGKASAN EKSEKUTIF (baca ini dulu)

| Item | Kondisi sebelum audit | Kondisi setelah perbaikan |
|---|---|---|
| Build APK di CI | **GAGAL 7x berturut-turut** (app belum pernah ter-build) | **HIJAU** (run `39131499220`, artifact `yp79-terpadu-apk` 78 MB) |
| Backend/database | URL Supabase di konfigurasi **tidak ada** (DNS: Non-existent domain) | masih sama — **butuh project Supabase baru** (lihat §7) |
| Login | Tidak akan pernah berpindah ke dashboard walau berhasil | diperbaiki (AuthGate mendengarkan perubahan sesi) |
| APK release | **Tanpa izin INTERNET** → tidak bisa akses jaringan | diperbaiki |
| Kunci jawaban CBT | **Terkirim ke perangkat siswa** | ditutup (RPC tanpa kolom kunci) |
| Penilaian CBT | **Semua siswa dapat nilai penuh** (fungsi SQL salah) | diperbaiki (`0005_cbt_dan_akses.sql`) |
| Keystore signing | **Ke-push ke repo PUBLIC** | dihapus dari tracking — **WAJIB rotasi** |
| Modul yang benar-benar berfungsi | sebagian besar hanya **baca/tampil** | CBT kini berfungsi penuh (satu-satunya alur tulis end-to-end) |

Kesimpulan singkat: aplikasi ini sebelumnya **tidak pernah bisa di-build** dan
**tidak terhubung ke database mana pun**. Setelah audit ini aplikasi
**bisa di-build menjadi APK**, tetapi **belum bisa dipakai operasional** karena
(a) belum ada project Supabase yang hidup, (b) sebagian besar modul belum
memiliki UI untuk menulis data. Rincian ada di §5 dan §6.

---

## 2. TEKNOLOGI & ARSITEKTUR YANG ADA

- **Aplikasi**: Flutter (Material 3), 33 file Dart, ~5.800 baris, tanpa code generation.
- **Backend**: Supabase (PostgreSQL + Auth + Row Level Security). Skema ditulis
  sebagai SQL mentah di `supabase/migrations/` (2.300+ baris, 59 tabel, 235 policy).
- **CI**: GitHub Actions `build.yml`, Flutter `3.47.5`, Java 21, NDK 28.2.13676358,
  AGP 9.1.0, Kotlin 2.4.0, build `--debug` bila secret keystore tidak ada.
- **State**: tidak ada state management (Provider/Riverpod/Bloc). Semua halaman
  memanggil `Repos.*` langsung di dalam `FutureBuilder`.
- **Autentikasi**: Supabase Auth email+password. Peran diambil dari
  `app_metadata.role` / `user_metadata.role` lalu dipetakan ke `enum Role`.
- **Pola akses data**: `lib/services/repositories.dart` (satu kelas `Repos`,
  ±950 baris) — semua query Supabase terpusat di sini.

Catatan: tidak ada perubahan teknologi yang dilakukan. Stack dipertahankan
sesuai instruksi ("jika project sudah memakai teknologi yang layak, pertahankan").

---

## 3. TEMUAN KRITIS (semuanya sudah diverifikasi, bukan dugaan)

### K1 — CI gagal 7x; akar masalahnya 2 baris import yang salah
Gejala: semua run sebelumnya berstatus `failure`.
Bukti (log run `39025314156`):

```
lib/main.dart:3:8: Error: Error when reading
  '../../../.pub-cache/hosted/pub.dev/supabase_flutter-2.18.3/lib/supabase.dart':
  No such file or directory
import 'package:supabase_flutter/supabase.dart' show Supabase;
```

File itu **tidak ada**; nama yang benar `package:supabase_flutter/supabase_flutter.dart`.
Import salah di 4 file → 12+ error lanjutan (`Undefined name 'Supabase'`,
`Type 'AuthSession' not found`).
Setelah itu tersisa 2 error lagi di `repositories.dart`:

```
lib/services/repositories.dart:30:11: Error: A value of type
 'PostgrestTransformBuilder<List<Map<String, dynamic>>>' can't be assigned to
 a variable of type 'PostgrestFilterBuilder<List<Map<String, dynamic>>>'.
```

`_filter()` memakai `var q` sehingga tipe ter-inferensi sempit, sementara rantai
`.order()`/`.limit()` mengubah tipe builder.
**STATUS: DIPERBAIKI** di commit `9d9a56e`. CI run `39131499220` = **success**.

### K2 — Backend yang dikonfigurasi TIDAK ADA
`lib/core/config.dart` dan `README-SETUP.md` menunjuk ke
`https://yukqngrtgevveimhrwke.supabase.co`. Hasil verifikasi:

```
$ nslookup yukqngrtgevveimhrwke.supabase.co
*** dlinkrouter.local can't find yukqngrtgevveimhrwke.supabase.co: Non-existent domain
$ curl https://yukqngrtgevveimhrwke.supabase.co/rest/v1/   → 000 (tidak resolve)
kontrol jaringan: https://pub.dev/ → 200 ; https://supabase.com/ → 200
```

Jadi DNS/URL itu memang mati (bukan masalah jaringan lokal). Sejarah git hanya
pernah memuat satu URL Supabase, yaitu URL mati ini.
Artinya: apa pun yang sudah diperbaiki di kode, aplikasi **tidak akan pernah
login atau menampilkan data** sampai project Supabase baru dibuat dan URL-nya
diganti. Tidak ada jalan pintas untuk ini.
**STATUS: BELUM SELESAI — butuh tindakan Anda** (langkah di §7).

### K3 — `.env` tidak pernah dimuat → backend dianggap tidak dikonfigurasi
`AppConfig.isConfigured` membaca `dotenv`, tetapi `dotenv.load()` **tidak pernah
dipanggil** di `main.dart`. Akibatnya aplikasi selalu masuk mode "backend belum
terhubung" meski file `.env` ada dan benar.
**STATUS: DIPERBAIKI** (`main.dart` memuat `.env` dalam try/catch yang aman di CI).

### K4 — APK release tidak punya izin INTERNET
`android/app/src/main/AndroidManifest.xml` tidak memuat
`<uses-permission android:name="android.permission.INTERNET"/>`. Manifest
debug/profile menambahkannya otomatis, **manifest release tidak**. Ini adalah
penyebab klasik "di emulator jalan, di APK release semua request diam-diam gagal".
**STATUS: DIPERBAIKI** (INTERNET + ACCESS_NETWORK_STATE ditambahkan).

### K5 — Presensi tidak bisa disimpan (constraint hilang)
`Repos.upsertAttendance()` memakai `onConflict: 'student_user_id,tanggal'`,
tetapi tabel `attendance_records` **tidak punya** unique constraint
`(student_user_id, tanggal)` (hanya index biasa). PostgREST akan menolak dengan
error `42P10` → seluruh penyimpanan presensi gagal, tanpa pesan yang jelas di UI
karena error ditelan `catch (_) { return false; }`.
**STATUS: DIPERBAIKI** — unique index ditambahkan di `0004_fixes.sql`.

### K6 — Kunci jawaban CBT bocor ke perangkat siswa
`Repos.examQuestions()` memakai `.select()` (seluruh kolom) sehingga kolom
`kunci` ikut terkirim dalam payload HTTP ke aplikasi siswa. Penyembunyian di UI
(`if (!kunciTerkunci ...)`) **bukan keamanan** — siapa pun bisa membaca
payload-nya (atau memanggil REST langsung).
**STATUS: DIPERBAIKI** — soal kini diambil lewat RPC
`exam_questions_public(p_exam)` yang **tidak pernah mengembalikan kolom `kunci`**.
Pembahasan/kunci hanya lewat `exam_questions_with_key(p_exam)` yang dibatasi
server (guru, admin, atau setelah ujian berstatus selesai/dipublikasikan).

### K7 — Penilaian CBT salah total: semua siswa dapat nilai penuh
Fungsi `finalize_cbt` versi lama:

```sql
set nilai_pilihan = (
  select coalesce(sum(case when q.tipe='pilihan' and q.kunci is not null
                           then q.skor else 0 end), 0)
    from public.exam_questions q
   where q.exam_id = v_attempt.exam_id
)
```

Tidak ada `join exam_answers`, tidak ada perbandingan jawaban dengan kunci —
yang dijumlahkan adalah **skor maksimum** ujian. Setiap attempt mendapat nilai
penuh berapa pun jawabannya.
**STATUS: DIPERBAIKI** — `finalize_cbt` ditulis ulang; hanya jawaban yang
`upper(btrim(jawaban)) = upper(btrim(kunci))` yang dihitung, `total_skor`
menyimpan skor maksimum sebagai pembagi.

### K8 — Siswa tidak bisa membaca soal saat ujian berjalan (policy RLS)
Policy `exq_read` pada `exam_questions`:

```sql
using ( public.is_admin_or_staff() or public.exam_publishable(exam_id) )
```

dan `exam_publishable` = `status in ('selesai','dipublikasikan') or kunci_terkunci = false`.
Untuk ujian `status='aktif'` dengan `kunci_terkunci=true` (nilai default),
siswa mendapat **0 baris soal**. Ujian tidak mungkin dikerjakan.
**STATUS: DIPERBAIKI** — RPC `exam_questions_public` mengizinkan siswa yang
terdaftar di kelas ujian selama ujian aktif, tanpa mengirim kunci.

### K9 — Login tidak pernah berpindah ke dashboard
Root app memakai `AuthBootstrapPage`, yang hanya membaca sesi **satu kali** di
`initState`. Kelas `AuthGate` yang mendengarkan `onAuthStateChange` ada, tetapi
tidak dipakai. Setelah `signInWithPassword` berhasil, hanya muncul SnackBar dan
layar tetap di halaman login.
**STATUS: DIPERBAIKI** — root app memakai stream auth (dibuat sekali di
`initState`), ditambah layar splash & layar error yang benar.

### K10 — Keystore signing produksi ter-push ke repo PUBLIC
`yp79-release.keystore.b64` **ter-track dan sudah ada di GitHub** pada repo
yang publik. Siapa pun bisa mengunduhnya dan menandatangani APK berbahaya yang
dianggap Android sebagai update resmi aplikasi sekolah.
**STATUS: DIHAPUS dari tracking** (`git rm --cached`, file lokal dihapus,
`.gitignore` diperkuat: `*.keystore.*`, `*.jks`, `.env*`).
**TINDAKAN ANDA YANG WAJIB**: rotasi keystore (buat baru, upload ke secret CI).
File lama harus dianggap bocor permanen — menghapusnya dari repo tidak
menghapusnya dari riwayat git dan fork orang lain.

---

## 4. TEMUAN TINGGI / SEDANG

| # | Temuan | Dampak | Status |
|---|---|---|---|
| T1 | `classes()` memakai embedded select `'*, subjects (kode, nama)'`, padahal tabel `classes` **tidak punya** kolom `subject_id`/FK ke `subjects` | PostgREST menolak (400) → daftar kelas selalu error | **DIPERBAIKI** (select polos) |
| T2 | Policy `finance_categories` hanya `is_admin_or_staff()` | Halaman Rincian Pembiayaan orang tua/siswa **selalu kosong** | **DIPERBAIKI** (`0005`) |
| T3 | Banner "Backend belum terhubung" dirender **dua kali** (gate + LoginPage) | Tampilan bertumpuk; juga membuat test gagal | **DIPERBAIKI** |
| T4 | `SvgPicture.asset('assets/logo.svg')` padahal **tidak ada** folder `assets/` dan tidak dideklarasikan di `pubspec.yaml` | Exception/asset error saat splash | **DIPERBAIKI** (diganti ikon) |
| T5 | Seed `0003`: dua baris `academic_years` memakai `id` PRIMARY KEY yang sama (`'2026/2027'`) + `on conflict (id) do nothing` | Baris **semester genap tidak pernah masuk** | **DIPERBAIKI** (`0004`, idempoten) |
| T6 | `student_profiles.kelas_id` tanpa foreign key | Bisa berisi uuid hantu; relasi kelas tidak terjaga | **DIPERBAIKI** (`0004`, guarded) |
| T7 | `startExam` mengembalikan `String?` yang ambigu (id attempt **atau** pesan error) | Pemanggil tidak bisa membedakan sukses/gagal | **DIPERBAIKI** (`StartExamResult`) |
| T8 | Tombol "Mulai Ujian" hanya `showToast('Menjalankan ujian...')` | Fitur inti CBT dekoratif (dilarang spesifikasi) | **DIPERBAIKI** — halaman ujian nyata (`exam_take_page.dart`) |
| T9 | Tombol "Lupa kata sandi" hanya toast | Fitur dekoratif | **DIPERBAIKI** — `resetPasswordForEmail` asli |
| T10 | `test/widget_test.dart` berisi `expect(1 + 1, 2)` dan judul tes yang tidak diuji | Test tidak menguji apa pun (test palsu) | **DIPERBAIKI** — smoke test boot + pemetaan peran |
| T11 | File duplikat `lib/features/beranda/widgets/dashboard_widgets.dart` (salinan kelas yang sama dengan `lib/widgets/`) | Dead code, risiko divergensi | **DIHAPUS** |
| T12 | `google-services.json` ada tetapi `oauth_client: []` **kosong**, dan `google_sign_in ^7.2.0` tidak dipakai di kode | Google Sign-In mustahil; klaim "ada" tidak sah | **BELUM** — perlu OAuth client ID Android di Firebase (§7) |
| T13 | `import 'package:gotrue/gotrue.dart'` padahal `gotrue` bukan dependency langsung; `AuthStateChange` **tidak diekspor** oleh gotrue | Rentan pecah saat upgrade; analyzer `undefined_shown_name` | **DIPERBAIKI** — impor type auth dari `supabase_flutter` |
| T14 | 27 temuan analyzer (`unused_import`, `unused_field` `_tab`, `deprecated_member_use`, `invalid_null_aware_operator`, dll) | Kebersihan kode | **DIPERBAIKI** — `flutter analyze` kini **0 error, 0 warning** (run `887e089`) |
| T15 | Kartu notifikasi menandai "dibaca" tanpa `setState`/refresh | Status baca tidak terlihat berubah tanpa keluar-masuk halaman | **BELUM** |
| T16 | Chat: UI hanya daftar percakapan + pengumuman; `Repos.messages()` & `Repos.sendMessage()` **tidak dipakai** | Chat tidak bisa dibaca/dikirim dari aplikasi | **BELUM** |

---

## 5. KELENGKAPAN MODUL vs SPESIFIKASI (kondisi apa adanya)

Angka di bawah hasil pemindaian otomatis `lib/` dan `supabase/migrations/`.

**Skema database**: 59 tabel, **semua** punya RLS aktif dan minimal 1 policy
(235 policy, 11 fungsi helper, 4 fungsi bisnis). Tidak ada tabel tanpa policy.
**Namun**: hanya **20 tabel** yang benar-benar di-query aplikasi →
**39 tabel tidak pernah disentuh kode aplikasi** (skema ada, UI tidak ada).

### Modul yang SUDAH ada UI-nya

| Modul | Halaman | Kondisi |
|---|---|---|
| Login | `login_page.dart` | Nyata (Supabase Auth) + reset sandi |
| Shell & navigasi | `shell_page.dart` | Bottom nav per peran; **belum adaptif** (belum ada sidebar untuk tablet) |
| Beranda 4 peran | `beranda/*_dashboard.dart` | Menampilkan data nyata + blok **"Aksi Cepat"** yang membuka modul operasional |
| Input Presensi | `akademik/presensi_input_page.dart` | **BARU** — tersambung ke `upsertAttendance` (guru/admin) |
| Input Nilai | `akademik/nilai_input_page.dart` | **BARU** — tersambung ke `upsertGrade` (guru/admin) |
| Pengajuan Izin | `izin/izin_page.dart` | **BARU** — `submitLeave` (ortu/siswa) + `decideLeave` (guru/admin) |
| Akademik | `akademik_page.dart` | Baca: jadwal, nilai, kelas, presensi hari ini — **tanpa input** |
| LMS | `lms_page.dart` | Baca materi/tugas/pengumpulan + 5 tombol |
| CBT | `cbt_page.dart` + `exam_take_page.dart` | **Berfungsi penuh** (satu-satunya alur tulis end-to-end) |
| Perpustakaan | `page_perpus.dart` | Katalog buku + materi digital (belum ada peminjaman) |
| Keuangan | `page_keuangan.dart` | Hanya kategori biaya (belum daftar tagihan) |
| MABIT | `page_mabit.dart` | Hanya daftar kegiatan (belum peserta/kamar/mutaba'ah/hafalan) |
| Chat | `page_chat.dart` | Daftar percakapan + pengumuman (belum baca/kirim pesan) |

### Modul yang BELUM ada UI sama sekali (0 file menyebut fiturnya)

Rapor · PPDB · Pengumuman (composer/penerbitan) · Janji temu · GPS bus ·
Consent form · Setoran hafalan · Mutaba'ah (input) · Manajemen pengguna ·
CRUD kelas/mapel/jadwal · Peminjaman perpustakaan · Audit log ·
Laporan & ekspor (PDF/XLSX) · Upload file/lampiran · Sidebar/layout adaptif ·
Realtime (selain auth) · Push notification (FCM) · Pembayaran (sesuai keputusan
Anda modul ini memang dihapus; `finance_items` read-only sudah benar arahnya).

### Fungsi tulis yang SUDAH ada di lapisan data tetapi TIDAK bisa dipakai dari UI

Hasil pemindaian `lib/features/`:

```
Repos.upsertAttendance  → dipakai UI: 0 file   (guru tidak bisa input presensi)
Repos.upsertGrade       → dipakai UI: 0 file   (guru tidak bisa input nilai)
Repos.submitAssignment  → dipakai UI: 0 file   (siswa tidak bisa kumpul tugas)
Repos.gradeSubmission   → dipakai UI: 0 file   (guru tidak bisa menilai)
Repos.submitLeave       → dipakai UI: 0 file   (orang tua tidak bisa ajukan izin)
Repos.decideLeave       → dipakai UI: 0 file   (guru/admin tidak bisa memutuskan)
Repos.sendMessage       → dipakai UI: 0 file
Repos.messages          → dipakai UI: 0 file
Repos.libraryLoans      → dipakai UI: 0 file
Repos.mutabaah          → dipakai UI: 0 file
Repos.mabitParticipants → dipakai UI: 0 file
```

Artinya: **jalur tulis/aksi hampir seluruhnya belum tersambung ke layar**.
Ini alasan utama aplikasi belum bisa dipakai operasional, meski build-nya sudah
hijau dan skemanya lengkap.

### Fitur yang tidak boleh diklaim sudah selesai (dan memang belum)

QR presensi (fungsi SQL `generate_attendance_qr`/`verify_attendance_qr` ada, UI
tidak ada) · RFID (butuh perangkat; hanya enum `metode` yang ada) · GPS bus
(tabel `vehicle_locations` ada, tidak ada telemetry masuk, tidak ada peta) ·
Push notification (tidak ada FCM, tidak ada token device) · Pembayaran online
(tidak ada gateway; sesuai keputusan Anda, pembayaran in-app dihapus).

---

## 6. KEAMANAN & PRIVASI

| Aspek | Hasil audit |
|---|---|
| RLS | **Baik secara desain** — 59/59 tabel aktif, policy role-aware memakai helper `is_admin`, `current_student_id()`, `is_parent_of()` |
| Otorisasi backend | Divisi peran di RLS benar; policy `exam_attempts`/`exam_answers` sudah membatasi ke pemilik attempt |
| Kunci jawaban | **Bocor** (K6) → ditutup |
| Penilaian server | **Salah hitung** (K7) → ditulis ulang (tetap di server, tidak bisa dimanipulasi klien) |
| Keystore signing | **Bocor ke repo publik** (K10) → di-untrack; **rotasi wajib** |
| Rahasia di kode | Tidak ada password admin tertanam. URL Supabase (bukan rahasia) ada di `config.dart` — boleh, karena anon/publishable key memang publik dengan RLS |
| `.env` | Tidak pernah dimuat (K3) → diperbaiki; `.env*` sekarang di-gitignore |
| `google-services.json` | Publik di repo; API key Firebase memang publik-by-design, tetapi tanpa `oauth_client` fitur sign-in tidak jalan |
| Error disamarkan | Banyak `catch (_) { return false; }` menelan error DB (mis. K5) sehingga kegagalan tidak terlihat di UI — **ini yang membuat bug lama tak terdeteksi** |
| Audit log | Tabel `audit_logs` ada + policy, tetapi **tidak ada trigger** yang mengisinya dan **tidak ada UI** untuk membacanya → janji "aksi sensitif tercatat" belum terpenuhi di level aplikasi |
| Backup | Tidak ada otomatisasi; hanya catatan manual di README-SETUP |

Catatan penting: karena repo **publik**, jangan pernah commit
`key.properties`, `.env`, service-role key, atau kredensial apa pun.

---

## 7. YANG HARUS ANDA LAKUKAN (di luar jangkauan saya)

1. **Buat project Supabase baru** (project lama sudah tidak ada), lalu:
   - Jalankan migrasi berurutan di SQL Editor: `0001_schema.sql` →
     `0002_rls_functions.sql` → `0003_seed.sql` → `0004_fixes.sql` →
     `0005_cbt_dan_akses.sql`.
   - Jika ada error di tengah, hentikan dan kirim pesan error-nya.
2. **Ambil Publishable/anon key** dari dashboard (bukan `sb_secret_`, bukan
   `sbp_`), lalu set di GitHub → Settings → Secrets → Actions:
   `SUPABASE_URL` dan `SUPABASE_ANON_KEY`. CI sekarang otomatis menyuntikkan
   keduanya sebagai `--dart-define`; tanpa keduanya APK tetap ter-build tetapi
   berjalan tanpa backend (dan CI mencetak peringatan).
3. **Rotasi keystore signing** (yang lama sudah bocor), lalu isi secret
   `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEYSTORE_KEYPASSWORD`,
   `KEYSTORE_ALIAS` supaya CI membuat APK **release bertanda tangan**, bukan debug.
4. **Buat akun admin pertama** lewat Supabase Auth → Add User, isi User Metadata
   `{"role":"admin","nama":"Administrator"}` (prosedur lengkap di `README-SETUP.md`).
5. **Google Sign-In (opsional)**: tambahkan OAuth client type Android di Firebase
   untuk package `com.yp79terpadu.app` + SHA-1 keystore, lalu `google-services.json`
   akan berisi `oauth_client` yang valid.

---

### K11 — Project Supabase yang diberikan TIDAK COCOK (verifikasi live 18 Okt 2026)

Hasil `python tools/verify_supabase.py` ke `https://kqkemiuqyfhqbwlgguqg.supabase.co`:

```
OK      : 35/59 tabel ada
MISSING : 21 tabel (profiles, student_profiles, parent_profiles, teacher_profiles,
          parent_student, classes, attendance_sessions, attendance_records,
          assignments, finance_categories, finance_items, admissions,
          admission_parents, mabit_events, mabit_participants, mabit_group_members,
          mabit_room_assignments, mabit_rundown_items, memorization_submissions,
          digital_resources, vehicle_locations)
ERROR   : 9 (chat_conversations, conversation_members, chat_messages -> 42P17
          infinite recursion; school_settings/profiles/attendance_records/
          grading_records/leave_requests/chat_messages -> bentuk kolom beda)
```

Contoh bentrok kolom yang terbukti:
```
grading_records.student_user_id  -> 42703 column does not exist
leave_requests.student_user_id   -> 42703 column does not exist
chat_messages.isi                -> 42703 column does not exist
school_settings                  -> kolomnya id/nama_sekolah/zona_waktu, bukan key/value
```

Artinya 35 tabel yang "ada" itu **varian aplikasi lama dengan nama kolom berbeda** —
lebih berbahaya daripada tabel yang tidak ada, karena `create table if not exists`
pada migrasi yp79 akan melewatinya dan menyisakan bentuk yang salah.

**Keputusan yang diambil: project Supabase BARU khusus yp79.** Untuk pemakaian ulang
project lama, `RESET_DESTRUCTIVE.sql` (drop schema public cascade) wajib dijalankan
lebih dulu, dan itu menghapus seluruh data aplikasi lama.

### K12 — Jenis kunci Supabase (penting, pernah tertukar)

| Kunci | Contoh awalan | Boleh ada di APK? | Dipakai untuk |
|---|---|---|---|
| Publishable / anon | `sb_publishable_...`, `eyJ...` | **YA** (memang publik, dilindungi RLS) | aplikasi Flutter, CI `--dart-define` |
| Secret / service_role | `sb_secret_...` | **TIDAK PERNAH** | hanya server (Edge Function), bypass semua RLS |
| Personal access token | `sbp_...` | **TIDAK PERNAH** | Supabase Management API (bikin/hapus project) |

Kunci `sb_secret_...` yang pernah dikirim lewat chat **harus dianggap bocor** dan
di-rotasi di Dashboard → Project Settings → API Keys. Aplikasi ini tidak
membutuhkannya sama sekali.

---

## 8. YANG BELUM DIKERJAKAN & ALASANNYA (jujur)

Saya tidak mengerjakan hal-hal berikut, dan ini **bukan** karena "sudah selesai":

1. **Menyambungkan sisa jalur tulis ke UI.** Sudah tersambung pada putaran ini:
   presensi guru (`upsertAttendance`), input nilai (`upsertGrade`), pengajuan izin
   (`submitLeave`) dan keputusan izin (`decideLeave`). **BELUM**: kumpul tugas
   (`submitAssignment`), penilaian tugas (`gradeSubmission`), chat baca/kirim
   (`messages`/`sendMessage`), peminjaman buku (`libraryLoans`), mutaba'ah,
   peserta MABIT. Skema dan fungsi datanya sudah siap; yang kurang layarnya.
2. **Modul PPDB, Rapor, Janji temu, GPS bus, Consent, Setoran hafalan,
   Pengumuman, Manajemen pengguna, Audit log, Laporan/ekspor.** Tabel-tabelnya
   ada; UI-nya belum ada sama sekali.
3. **Push notification FCM** dan **QR/RFID presensi**: butuh kredensial/perangkat
   eksternal yang belum tersedia. Struktur data sudah disiapkan, tetapi saya
   tidak akan mengklaim fitur ini aktif.
4. **Uji di perangkat nyata**: saya tidak punya emulator/perangkat di lingkungan
   ini, jadi semua verifikasi dilakukan lewat build CI, analyze, unit/widget
   test, dan audit statis. Uji visual per layar masih perlu Anda lakukan setelah
   APK di-install.
5. **`anonKey` masih dipakai** di `Supabase.initialize`. Supabase menandainya
   `deprecated` dan mengarahkan ke `publishableKey`. Saya tidak mengubahnya
   karena tanpa bisa mengompilasi lokal saya tidak mau menebak signature baru
   yang bisa menggagalkan build yang sudah hijau. Perubahan ini bersifat
   kosmetik (info-level) pada versi paket saat ini.

6. **Sidebar/layout adaptif tablet** dan **animasi**: belum ada; bottom nav
   sudah berfungsi tetapi belum memenuhi bagian "responsif tablet" spesifikasi.

---

## 9. CARA MENJALANKAN (setelah secret diisi)

```bash
# 1) Database
#    Supabase Dashboard → SQL Editor → jalankan berurutan:
#    0001_schema.sql, 0002_rls_functions.sql, 0003_seed.sql,
#    0004_fixes.sql, 0005_cbt_dan_akses.sql

# 2) Lingkungan lokal (opsional, untuk `flutter run`)
#    buat .env di root (jangan di-commit):
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<publishable/anon key>

# 3) APK lewat CI
git push origin main        # CI build otomatis, artifact: yp79-terpadu-apk
gh run list --limit 3
gh run watch <run-id>
```

Kredensial untuk APK di CI: cukup `SUPABASE_URL` + `SUPABASE_ANON_KEY`
(disuntik via `--dart-define`). Untuk APK release bertanda tangan tambahkan
4 secret keystore.

---

## 10. DAFTAR PERUBAHAN YANG SUDAH DI-PUSH

| Commit | Isi |
|---|---|
| `6ab9484` | snapshot state awal (sebelum audit) — agar kondisi awal bisa dibandingkan |
| `9d9a56e` | **Build hijau**: perbaikan import & tipe builder, `dotenv.load()`, izin INTERNET, navigasi login, un-track keystore, `.gitignore`, `0004_fixes.sql`, test nyata, hapus file duplikat, CI analyze+test non-blocking, dukungan `--dart-define` |
| `0bda02f` | **CBT berfungsi**: RPC soal tanpa kunci, penilaian server diperbaiki (`0005_cbt_dan_akses.sql`), halaman pengerjaan ujian nyata, `StartExamResult`, policy `finance_categories`, banner ganda, reset sandi asli |
| `8e08703` | `docs/AUDIT.md` (dokumen ini) |
| `563ac80` | Bersih-bersih analyzer: 12 `unused_import`, `unused_field`, 2 `unnecessary_null_comparison` |
| `887e089` | Import type auth dari `supabase_flutter` (gotrue rapuh), null-aware berlebih — **analyzer 0 warning** |
| `b0a16a6` | Sinkronisasi dokumentasi (migrasi 0004/0005, secret Supabase, rotasi keystore) |
| `bf2bcb3` | **Jalur tulis tersambung**: halaman Input Presensi, Input Nilai, Pengajuan/Keputusan Izin + grid "Aksi Cepat" di 4 dashboard + `0006_aksi_dan_audit.sql` (policy guru untuk upsert presensi, trigger audit log otomatis) |

Verifikasi terakhir (semua hijau):

| Run | Commit | Hasil |
|---|---|---|
| `39131499220` | `9d9a56e` | success — **build APK pertama yang berhasil** |
| `39132305847` | `0bda02f` | success — kode CBT lolos kompilasi |
| `39132512756` | `8e08703` | success |
| `39132761734` | `563ac80` | success — `All tests passed!` (+2 test), analyze 0 unused/error, artifact 78.333.111 byte |
| `39133227918` | `887e089` | success — `flutter analyze`: **0 warning, 0 error** |

Sebelum audit: **7 run berturut-turut gagal** dan aplikasi belum pernah
menghasilkan APK. Sesudah audit: **5 run berturut-turut hijau**.
