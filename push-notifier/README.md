# FCM Push Notifier (Opsi B — Node + cron)

Jembatan antara Supabase (DB) dan Firebase FCM (kurir push) **tanpa**
edge function Supabase.

## Arsitektur

```
App siswa  →  FCM token disimpan di Supabase (push_tokens)
   .
   .
Supabase DB → [node fcm.js] → FCM API → HP siswa/ortu/guru/admin
```

Setiap kali ada notifikasi/izin/nilai baru di Supabase, script ini
mencari FCM token terkait & mengirim push.

## Struktur

| File | Fungsi |
|---|---|
| `fcm.js` | Entry point: baca Supabase, kirim FCM, catat ke SQLite |
| `package.json` | Dep: `firebase-admin` |
| `push_log.db` | SQLite idempotensi (auto-generated, gitignored) |

## Prasyarat

1. **Node.js 22+** (butuh `node:sqlite` built-in)
2. `npm install` di root repo → `node_modules` (gitignored)
3. `.secrets/fcm_service_account.json` — service account Firebase (gitignored)
4. `.secrets/svc_key.txt` — Supabase service_role key (gitignored)

   Ambil service_role key dari dashboard Supabase → Settings → API
   Keys → Legacy Keys → service_role.

## Menjalankan

```bash
# Sekali (manual test)
node push-notifier/fcm.js

# Output contoh:
# [fcm] start @ 2026-10-20T...
# [fcm] notif 3b23... → user 853c...
# [fcm] done
```

## Jadwal otomatis (cron / Task Scheduler)

**Windows (Task Scheduler):**
```
Program:     D:\Program Files\nodejs\node.exe
Argument:    "D:\yp79 terpadu\push-notifier\fcm.js"
Start in:    D:\yp79 terpadu
Interval:    1 menit
```

**Linux / Mac (crontab -e):**
```
* * * * * cd /path/to/yp79-terpadu && node push-notifier/fcm.js >> push-notifier/push.log 2>&1
```

## Yang dideteksi

| Event | Siapa yang dapat push |
|---|---|
| `notifications` (broadcast) | Semua user sesuai `target` (siswa/guru/admin/ortu) |
| `notifications` (individual) | User spesifik `penerima_user_id` |
| `leave_requests` status=diajukan | Semua admin, guru, pembimbing |
| `grading_records` terbaru 20 | Siswa pemilik + orang tuanya |

## Catatan

- Push log disimpan di `push-notifier/push_log.db` (SQLite).
  Tiap FCM token + event key dicatat sekali — **tidak dobel kirim**
  meski script jalan berulang kali.
- Bila FCM token sudah invalid (user uninstall app), FCM return
  `messaging/registration-token-not-registered`. Script log-nya
  tapi tidak crash. Bisa manual bersihkan `push_log.db` atau
  tabel `push_tokens` di Supabase.
- Untuk reset log: `del push-notifier\push_log.db` (Windows) atau
  `rm push-notifier/push_log.db` (Linux).
