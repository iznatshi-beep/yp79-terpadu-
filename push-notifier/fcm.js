/**
 * FCM PUSH NOTIFIER (Opsi B — Node + cron, tanpa edge function)
 *
 * Jalankan:  node push-notifier/fcm.js
 *
 * Cara kerja:
 *   1. Login ke Supabase sebagai admin (admin@yp79.test)
 *   2. Baca notifikasi + izin + nilai baru
 *   3. Temukan FCM token tiap penerima dari tabel push_tokens
 *   4. Kirim via Firebase Admin SDK (service account fcm_service_account.json)
 *   5. Push log (SQLite) mencatat event per-token → idempotent, gak dobel
 *
 * Jadwalkan (Task Scheduler Windows / cron 1 menit):
 *   D:\yp79 terpadu> node push-notifier\fcm.js
 *
 * Catatan:
 *   - Target notification: penerima_user_id (spesifik) ATAU target (broadcast)
 *   - push_tokens: token didaftarkan otomatis dari app siswa/ortu/guru
 *   - Status leave_requests: menunggu/ditolak/dikabulkan (enum)
 *   - grading_records: per siswa, notifikasi juga ke orang tua (parent_student)
 */
const fs = require('fs');
const path = require('path');

// ---------- CONFIG ----------
const SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://kqkemiuqyfhqbwlgguqg.supabase.co';
// service_role key — BUKAN anon key. File .secrets/svc_key.txt (gitignored).
// Bisa juga set env SUPABASE_SERVICE_KEY.
const SVC_KEY_FILE = path.join(__dirname, '..', '.secrets', 'svc_key.txt');
const SUPABASE_SERVICE_KEY =
  process.env.SUPABASE_SERVICE_KEY ||
  fs.readFileSync(SVC_KEY_FILE, 'utf8').trim();
const SA = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '..', '.secrets', 'fcm_service_account.json'),
    'utf8'
  )
);

// ---------- FIREBASE ----------
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: SA.project_id,
    clientEmail: SA.client_email,
    privateKey: SA.private_key.replace(/\\n/g, '\n'),
  }),
});
const messaging = admin.messaging();

// ---------- SUPABASE ----------
// Pakai service_role key langsung (bypass RLS) — gak perlu login admin.
async function supa(qs) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${qs}`, {
    headers: {
      apikey: SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    },
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Supabase ${res.status}: ${t.slice(0, 300)}`);
  }
  return res.json();
}

// ---------- PUSH LOG ----------
const DB_PATH = path.join(__dirname, 'push_log.db');
let _db;
function getPushLog() {
  if (!_db) {
    const { DatabaseSync } = require('node:sqlite');
    _db = new DatabaseSync(DB_PATH);
    _db.exec(`CREATE TABLE IF NOT EXISTS push_log (
      fcm_token TEXT,
      event_key TEXT,
      pushed_at TEXT DEFAULT (datetime('now')),
      PRIMARY KEY (fcm_token, event_key))`);
  }
  return {
    has: (tk, k) =>
      !!_db
        .prepare('SELECT 1 FROM push_log WHERE fcm_token=? AND event_key=?')
        .get(tk, k),
    mark: (tk, k) =>
      _db
        .prepare('INSERT OR IGNORE INTO push_log (fcm_token, event_key) VALUES (?,?)')
        .run(tk, k),
  };
}

// ---------- TARGET MAPPING ----------
const TARGET_ROLES = {
  semua: null, // semua peran
  siswa: ['siswa'],
  guru: ['guru', 'pembimbing'],
  admin: ['admin'],
  orang_tua: ['orang_tua'],
};

// ---------- MAIN ----------
async function main() {
  console.log('[fcm] start @', new Date().toISOString());
  const log = getPushLog();

  // Data sekali ambil (cache)
  const allPush = await supa(
    'push_tokens?select=user_id,token&limit=500'
  );
  const allProfiles = await supa('profiles?select=id,role&limit=500');
  const roleOf = new Map(allProfiles.map((p) => [p.id, p.role]));

  const tokensByUser = new Map();
  for (const t of allPush) {
    if (!tokensByUser.has(t.user_id)) tokensByUser.set(t.user_id, []);
    tokensByUser.get(t.user_id).push(t.token);
  }

  // ================= 1. NOTIFIKASI =================
  const notifs = await supa(
    'notifications?select=id,penerima_user_id,target,judul,pesan,tipe,created_at&limit=100'
  );
  for (const n of notifs) {
    const eventKey = `notif_${n.id}_${n.penerima_user_id || n.target}`;
    const title = n.judul || 'Pemberitahuan';
    const body = n.pesan || '';
    const data = { type: n.tipe || 'notification', id: String(n.id) };

    // Target spesifik user
    if (n.penerima_user_id) {
      const toks = tokensByUser.get(n.penerima_user_id) || [];
      for (const tk of toks) {
        if (log.has(tk, eventKey)) continue;
        try {
          await messaging.send({ token: tk, notification: { title, body }, data });
          log.mark(tk, eventKey);
          console.log(`[fcm] notif ${n.id} → user ${n.penerima_user_id}`);
        } catch (e) {
          console.error(`[fcm] notif ${n.id} gagal:`, e.message);
        }
      }
      continue;
    }

    // Target broadcast (siswa/guru/admin/orang_tua/semua)
    const roles = TARGET_ROLES[n.target] ?? TARGET_ROLES.semua;
    let sent = 0;
    for (const p of allProfiles) {
      if (roles && !roles.includes(p.role)) continue;
      const toks = tokensByUser.get(p.id) || [];
      for (const tk of toks) {
        if (log.has(tk, eventKey)) continue;
        try {
          await messaging.send({ token: tk, notification: { title, body }, data });
          log.mark(tk, eventKey);
          sent++;
        } catch (e) {
          console.error(`[fcm] broadcast gagal:`, e.message);
        }
      }
    }
    if (sent > 0) console.log(`[fcm] notif ${n.id} (${n.target}) → ${sent} device`);
  }

  // ================= 2. IZIN (leave_requests status=menunggu) =================
  const izin = await supa(
    'leave_requests?select=id,student_user_id,jenis,alasan,status,created_at&status=eq.diajukan&limit=50'
  );
  const adminUsers = allProfiles.filter((p) =>
    ['admin', 'guru', 'pembimbing'].includes(p.role)
  );
  for (const i of izin) {
    const eventKey = `izin_${i.id}`;
    const title = `Izin ${i.jenis || 'Siswa'} Baru`;
    const body = i.alasan ? i.alasan.substring(0, 120) : 'Siswa mengajukan izin';
    const data = { type: 'izin', id: String(i.id) };
    for (const p of adminUsers) {
      const toks = tokensByUser.get(p.id) || [];
      for (const tk of toks) {
        if (log.has(tk, eventKey)) continue;
        try {
          await messaging.send({ token: tk, notification: { title, body }, data });
          log.mark(tk, eventKey);
          console.log(`[fcm] izin ${i.id} → ${p.role}`);
        } catch (e) {
          console.error(`[fcm] izin gagal:`, e.message);
        }
      }
    }
  }

  // ================= 3. NILAI (grading_records terbaru 20) =================
  const nilai = await supa(
    'grading_records?select=id,student_user_id,nilai,subject_id,created_at&order=created_at.desc&limit=20'
  );
  for (const g of nilai) {
    const eventKey = `nilai_${g.id}`;
    const title = 'Nilai Baru Masuk';
    const body = `Nilai: ${g.nilai}`;
    const data = { type: 'nilai', id: String(g.id) };

    const targets = [g.student_user_id];
    // + orang tua
    const rel = await supa(
      `parent_student?select=parent_user_id&student_user_id=eq.${g.student_user_id}`
    );
    targets.push(...rel.map((r) => r.parent_user_id));

    for (const uid of targets) {
      if (!uid) continue;
      const toks = tokensByUser.get(uid) || [];
      for (const tk of toks) {
        if (log.has(tk, eventKey)) continue;
        try {
          await messaging.send({ token: tk, notification: { title, body }, data });
          log.mark(tk, eventKey);
          console.log(`[fcm] nilai ${g.id} → ${roleOf.get(uid) || uid}`);
        } catch (e) {
          console.error(`[fcm] nilai gagal:`, e.message);
        }
      }
    }
  }

  // ================= 4. PENGUMUMAN (announcements dipublikasikan) ==========
  // Broadcast dari admin: kolom target_penerbitan = semua/siswa/guru/
  // orang_tua/admin. Idempotent via event_key `pengumuman_<id>`.
  const anns = await supa(
    'announcements?select=id,judul,isi,target_penerbitan,status,dipublikasikan_pada' +
      '&status=eq.dipublikasikan&order=dipublikasikan_pada.desc&limit=20'
  );
  for (const a of anns) {
    // Hanya pengumuman maksimal 7 hari — jangan spam token lama.
    const umur = Date.now() - new Date(a.dipublikasikan_pada).getTime();
    if (umur > 7 * 24 * 3600 * 1000) continue;
    const eventKey = `pengumuman_${a.id}`;
    const title = a.judul || 'Pengumuman';
    const body = (a.isi || '').substring(0, 120);
    const data = { type: 'pengumuman', id: String(a.id) };

    const roles = TARGET_ROLES[a.target_penerbitan] ?? TARGET_ROLES.semua;
    let sent = 0;
    for (const p of allProfiles) {
      if (roles && !roles.includes(p.role)) continue;
      const toks = tokensByUser.get(p.id) || [];
      for (const tk of toks) {
        if (log.has(tk, eventKey)) continue;
        try {
          await messaging.send({ token: tk, notification: { title, body }, data });
          log.mark(tk, eventKey);
          sent++;
        } catch (e) {
          console.error(`[fcm] pengumuman gagal:`, e.message);
        }
      }
    }
    if (sent > 0) {
      console.log(`[fcm] pengumuman ${a.id} (${a.target_penerbitan}) → ${sent} device`);
    }
  }

  console.log('[fcm] done');
}

main().catch((e) => {
  console.error('[fcm] fatal:', e.message || e);
  process.exit(1);
});
