#!/usr/bin/env python
"""Deploy backend YP79 Terpadu ke Supabase lewat Management API.

Yang dilakukan (berurutan, berhenti begitu ada yang gagal):
  1. Baca token dari .secrets/sbp_token.txt (tidak pernah di-echo).
  2. Pilih organisasi (atau pakai ORG_ID dari env).
  3. Buat project baru (name/region/password DB bisa diatur via env).
  4. Tunggu project ACTIVE_HEALTHY.
  5. Push supabase/migrations/000*.sql berurutan lewat endpoint
     POST /v1/projects/{ref}/database/query. Gagal = stop (tidak setengah jalan).
  6. Ambil publishable/anon key dari /v1/projects/{ref}/api-keys.
  7. Simpan ke .env (lokal, gitignored) dan (opsional) set GitHub secret.
  8. Jalankan tools/verify_supabase.py kalau ada.

Token TIDAK pernah dicetak, TIDAK pernah ditulis ke file repo, dan hanya
dipakai untuk request ke api.supabase.com.

Pakai:
  python tools/deploy_supabase.py                # bikin project + migrasi + verifikasi
  python tools/deploy_supabase.py --ref <ref>    # project sudah ada, hanya migrasi
"""
from __future__ import annotations

import argparse
import json
import os
import re
import secrets
import string
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIGRATIONS = ROOT / "supabase" / "migrations"
TOKEN_FILE = ROOT / ".secrets" / "sbp_token.txt"
DBPASS_FILE = ROOT / ".secrets" / "db_pass.txt"
ENV_FILE = ROOT / ".env"
API = "https://api.supabase.com/v1"

NAMA_PROJECT = os.environ.get("PROJECT_NAME", "yp79-terpadu")
REGION = os.environ.get("REGION", "ap-southeast-1")  # Singapore


def baca_token() -> str:
    if not TOKEN_FILE.exists():
        print(f"Token tidak ada di {TOKEN_FILE}")
        print('Simpan token dengan:  notepad "D:\\yp79 terpadu\\.secrets\\sbp_token.txt"')
        sys.exit(2)
    token = TOKEN_FILE.read_text(encoding="utf-8").strip()
    if not token:
        print(f"{TOKEN_FILE} kosong.")
        sys.exit(2)
    if not token.startswith("sbp_"):
        print("Peringatan: token tidak diawali 'sbp_' — lanjut tapi cek dulu.")
    return token


def api(token: str, method: str, path: str, body: dict | None = None) -> tuple[int, object]:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{API}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            txt = r.read().decode("utf-8", "replace")
            try:
                return r.status, json.loads(txt) if txt else None
            except json.JSONDecodeError:
                return r.status, txt
    except urllib.error.HTTPError as e:
        txt = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(txt)
        except json.JSONDecodeError:
            return e.code, txt
    except Exception as e:
        return 0, str(e)


def gen_password(n: int = 24) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(n))


def pilih_org(token: str) -> tuple[str, str]:
    if os.environ.get("ORG_ID"):
        return os.environ["ORG_ID"], "(dari ORG_ID)"
    code, res = api(token, "GET", "/organizations")
    if code == 200 and isinstance(res, list) and res:
        for o in res:
            print(f"  org: {o.get('name')}  id={o.get('id')}  plan={o.get('plan')}")
        return res[0]["id"], res[0].get("name", "")

    # Token bertipe project-scope tidak boleh membaca /organizations.
    # Ambil organization_id dari project yang sudah ada.
    print(f"/organizations kosong (HTTP {code}) — fallback ke project yang ada.")
    code2, projs = api(token, "GET", "/projects?limit=50")
    if code2 == 200 and isinstance(projs, list) and projs:
        p = projs[0]
        print(f"  project terlihat: {p.get('ref')} ({p.get('name')})")
        print(f"  organization_id : {p.get('organization_id')}")
        return p["organization_id"], p.get("name", "")
    print(f"Tidak bisa menentukan organisasi (HTTP {code2}): {projs}")
    sys.exit(1)


def bikin_project(token: str, org_id: str) -> str:
    db_pass = gen_password()
    body = {
        "organization_id": org_id,
        "name": NAMA_PROJECT,
        "region": REGION,
        "db_pass": db_pass,
    }
    print(f"Membuat project '{NAMA_PROJECT}' di region {REGION} ...")
    code, res = api(token, "POST", "/projects", body)
    if code not in (200, 201):
        print(f"GAGAL membuat project (HTTP {code}): {res}")
        pesan = json.dumps(res)
        if code in (401, 403) or "scope" in pesan.lower() or "permission" in pesan.lower():
            print()
            print("Token ini tidak punya izin membuat project (scope-nya project-level).")
            print("Opsi:")
            print("  1. Bikin project manual di dashboard, lalu:")
            print("     python tools/deploy_supabase.py --ref <ref-baru>")
            print("  2. Pakai project yang sudah ada + wipe bersih:")
            print("     python tools/deploy_supabase.py --ref kqkemiuqyfhqbwlgguqg --reset")
            print("  3. Bikin token baru dengan scope Organization: All + Read/Write,")
            print("     simpan lagi ke .secrets/sbp_token.txt")
        sys.exit(1)
    ref = res.get("id") or res.get("ref")
    DBPASS_FILE.parent.mkdir(parents=True, exist_ok=True)
    DBPASS_FILE.write_text(db_pass + "\n", encoding="utf-8")
    print(f"Project dibuat: {ref}")
    print(f"Password DB disimpan di {DBPASS_FILE} (jangan hilang).")
    return ref


def tunggu_healthy(token: str, ref: str, maks_detik: int = 600) -> None:
    mulai = time.time()
    while time.time() - mulai < maks_detik:
        code, res = api(token, "GET", f"/projects/{ref}")
        status = res.get("status") if isinstance(res, dict) else res
        print(f"  status: {status}")
        if status == "ACTIVE_HEALTHY":
            return
        if status in ("INIT_FAILED", "PAUSE_FAILED", "REMOVED"):
            print(f"Project gagal init: {status}")
            sys.exit(1)
        time.sleep(15)
    print("Timeout menunggu project healthy — cek dashboard.")
    sys.exit(1)


def push_migrasi(token: str, ref: str) -> None:
    files = sorted(p for p in MIGRATIONS.glob("000*.sql"))
    if not files:
        print("Tidak ada file migrasi.")
        sys.exit(1)
    for f in files:
        print(f"=== {f.name} ===")
        sql = f.read_text(encoding="utf-8")
        code, res = api(token, "POST", f"/projects/{ref}/database/query", {"query": sql})
        teks = json.dumps(res)[:1500] if not isinstance(res, str) else res[:1500]
        print(f"  HTTP {code}: {teks}")
        if code not in (200, 201):
            print(f"GAGAL pada {f.name} — stop, tidak lanjut supaya tidak setengah jalan.")
            sys.exit(1)
    print("Semua migrasi sukses.")


def ambil_key(token: str, ref: str) -> str:
    code, res = api(token, "GET", f"/projects/{ref}/api-keys?reveal=true")
    if code != 200 or not isinstance(res, list):
        code, res = api(token, "GET", f"/projects/{ref}/api-keys")
    if code != 200 or not isinstance(res, list):
        print(f"Gagal ambil API keys (HTTP {code}): {res}")
        sys.exit(1)
    kandidat = []
    for k in res:
        name = str(k.get("name", "")).lower()
        val = k.get("api_key") or k.get("key") or ""
        print(f"  key name={name} tipe={k.get('type')} panjang={len(str(val))}")
        if "publishable" in name or "anon" in name:
            kandidat.append((name, val))
    if not kandidat:
        print("Tidak menemukan publishable/anon key lewat API (mungkin scope token terbatas).")
        return ""
    return kandidat[0][1]


def ambil_key_dari_env() -> str:
    if not ENV_FILE.exists():
        return ""
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        if line.startswith("SUPABASE_ANON_KEY="):
            return line.split("=", 1)[1].strip()
    return ""


def tulis_env(url: str, key: str) -> None:
    ENV_FILE.write_text(
        f"SUPABASE_URL={url}\nSUPABASE_ANON_KEY={key}\n", encoding="utf-8"
    )
    print(f".env diperbarui: {url}")


def set_gh_secret(nama: str, nilai: str) -> None:
    try:
        subprocess.run(
            ["gh", "secret", "set", nama, "--repo", REPO, "--body", nilai],
            check=True,
            capture_output=True,
        )
        print(f"  GitHub secret {nama}: OK")
    except Exception as e:
        print(f"  GitHub secret {nama}: gagal ({e}) — set manual di GitHub.")


REPO = "iznatshi-beep/yp79-terpadu-"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", help="project ref yang sudah ada (lewati pembuatan)")
    ap.add_argument(
        "--reset",
        action="store_true",
        help="DESTRUKTIF: hapus seluruh schema public di project target sebelum migrasi "
             "(dipakai kalau memakai project aplikasi lama).",
    )
    ap.add_argument("--skip-gh", action="store_true", help="jangan set GitHub secret")
    args = ap.parse_args()

    token = baca_token()

    if args.ref:
        ref = args.ref
        print(f"Pakai project yang ada: {ref}")
    else:
        org_id, org_name = pilih_org(token)
        print(f"Organisasi dipakai: {org_name} ({org_id})")
        ref = bikin_project(token, org_id)

    tunggu_healthy(token, ref)

    if args.reset:
        reset_file = MIGRATIONS / "RESET_DESTRUCTIVE.sql"
        print(f"!! MODE RESET: mengosongkan schema public di project {ref}")
        code, res = api(
            token,
            "POST",
            f"/projects/{ref}/database/query",
            {"query": reset_file.read_text(encoding="utf-8")},
        )
        print(f"  HTTP {code}: {json.dumps(res)[:600] if not isinstance(res, str) else res[:600]}")
        if code not in (200, 201):
            print("Reset gagal — berhenti.")
            sys.exit(1)
        print("  Schema public dikosongkan.")

    push_migrasi(token, ref)

    url = f"https://{ref}.supabase.co"
    key = ambil_key(token, ref)
    if not key:
        key = ambil_key_dari_env()
        if key:
            print("  Memakai publishable key yang sudah ada di .env.")
    if not key:
        print("Publishable key tidak bisa diambil otomatis — isi .env manual lalu jalankan verify.")
        return 1
    tulis_env(url, key)

    if not args.skip_gh:
        print("Menyetel GitHub secret ...")
        set_gh_secret("SUPABASE_URL", url)
        set_gh_secret("SUPABASE_ANON_KEY", key)

    print("\n=== VERIFIKASI SCHEMA ===")
    subprocess.run([sys.executable, str(ROOT / "tools" / "verify_supabase.py"), url, key])

    print("\n=== SELESAI ===")
    print(f"URL   : {url}")
    print(f"ref   : {ref}")
    print("Langkah manual yang tersisa: bikin akun admin pertama di Supabase Auth")
    print('(User Metadata: {"role":"admin","nama":"Administrator"}).')
    print("PENTING: revoke token sbp_ yang dipakai ini setelah selesai.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
