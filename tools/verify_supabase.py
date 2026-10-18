#!/usr/bin/env python3
"""Verifikasi deployment schema YP79 Terpadu ke project Supabase.

Cek satu per satu tabel yang dibutuhkan aplikasi lewat REST API (publishable key).
Hasil:
  OK      -> tabel ada (HTTP 200)
  MISSING -> PostgREST balas PGRST205 (tabel tidak ada di schema cache)
  ERROR   -> error lain (mis. RLS rekursi 42P17, kolom bentrok 42P01)

Pakai:
  python3 tools/verify_supabase.py <SUPABASE_URL> <PUBLISHABLE_KEY>
  python3 tools/verify_supabase.py   # baca dari .env
"""
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

# 59 tabel sesuai supabase/migrations/0001_schema.sql
TABLES = [
    "profiles", "student_profiles", "parent_profiles", "teacher_profiles",
    "parent_student", "academic_years", "classes", "subjects",
    "class_enrollments", "teacher_assignments", "schedules", "academic_calendar",
    "attendance_sessions", "attendance_records", "leave_requests",
    "learning_materials", "assignments", "assignment_submissions",
    "grading_records", "report_cards", "report_card_items", "exams",
    "exam_questions", "exam_attempts", "exam_answers", "finance_categories",
    "finance_items", "admissions", "admission_parents", "admission_documents",
    "admission_results", "mabit_events", "mabit_participants", "mabit_groups",
    "mabit_group_members", "mabit_rooms", "mabit_room_assignments",
    "mabit_rundown_items", "mabit_media", "mutabaah_entries",
    "memorization_targets", "memorization_submissions", "consent_forms",
    "consent_responses", "library_books", "library_loans", "digital_resources",
    "vehicles", "vehicle_assignments", "vehicle_locations", "notifications",
    "announcements", "chat_conversations", "conversation_members",
    "chat_messages", "appointments", "character_records", "audit_logs",
    "school_settings",
]

# Kolom wajib per tabel (subset kritis) — mendeteksi tabel "bentrok bentuk"
# seperti school_settings milik aplikasi lama.
REQUIRED_COLUMNS = {
    "school_settings": {"key", "value"},
    "profiles": {"id", "role", "nama"},
    "exam_questions": {"exam_id", "urutan", "tipe", "kunci"},
    "attendance_records": {"student_user_id", "tanggal", "status", "metode"},
    "grading_records": {"student_user_id", "subject_id", "kategori", "nilai"},
    "leave_requests": {"student_user_id", "jenis", "alasan", "status"},
    "chat_messages": {"conversation_id", "pengirim_user_id", "isi"},
}


def baca_env(path: Path = Path(".env")) -> tuple[str, str]:
    url = key = ""
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("SUPABASE_URL="):
                url = line.split("=", 1)[1].strip()
            elif line.startswith("SUPABASE_ANON_KEY="):
                key = line.split("=", 1)[1].strip()
    return url, key


def get(url: str, key: str, path: str) -> tuple[int, str]:
    req = urllib.request.Request(
        f"{url}/rest/v1/{path}",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:  # jaringan / DNS
        return 0, str(e)


def main() -> int:
    if len(sys.argv) >= 3:
        url, key = sys.argv[1], sys.argv[2]
    else:
        url, key = baca_env()
    if not url or not key:
        print("Butuh SUPABASE_URL dan publishable key (argumen atau .env).")
        return 2

    print(f"Verifikasi schema YP79 di {url}\n")
    ok: list[str] = []
    missing: list[str] = []
    error: list[str] = []

    for t in TABLES:
        code, body = get(url, key, f"{t}?select=*&limit=1")
        if code == 200:
            ok.append(t)
            status = "OK"
        elif "PGRST205" in body:
            missing.append(t)
            status = "MISSING"
        else:
            error.append(t)
            status = f"ERROR {code} {body[:100]}"
        print(f"  {status:<12} {t}")

    # Cek bentuk kolom tabel rawan bentrok.
    print("\nCek bentuk kolom tabel kritis:")
    for t, cols in REQUIRED_COLUMNS.items():
        code, body = get(url, key, f"{t}?select={','.join(sorted(cols))}&limit=1")
        if code == 200:
            print(f"  OK        {t} kolom {sorted(cols)}")
        else:
            print(f"  MASALAH   {t} -> {body[:160]}")
            error.append(f"{t}:kolom")

    print("\n=== RINGKASAN ===")
    print(f"OK      : {len(ok)}/{len(TABLES)}")
    print(f"MISSING : {len(missing)}" + (f" -> {missing}" if missing else ""))
    print(f"ERROR   : {len(error)}" + (f" -> {error}" if error else ""))
    return 0 if not missing and not error else 1


if __name__ == "__main__":
    raise SystemExit(main())
