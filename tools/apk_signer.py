#!/usr/bin/env python
"""Cetak SHA-1 / SHA-256 sertifikat penanda tangan sebuah APK — tanpa JDK/keytool.

Dipakai untuk mengisi fingerprint di Firebase (Google Sign-In, Analytics,
Crashlytics) dan untuk memastikan APK benar-benar ditandatangani keystore rilis
yang sama setiap update (SHA harus stabil).

Membaca skema tanda tangan APK v2 (APK Signing Block) dan, bila ada, v1
(META-INF/*.RSA).

Pakai:
  python tools/apk_signer.py <file.apk>
  python tools/apk_signer.py build/app/outputs/flutter-apk/app-release.apk
"""
from __future__ import annotations

import struct
import sys
import zipfile
from pathlib import Path

try:
    from cryptography import x509
    from cryptography.hazmat.primitives.serialization import Encoding, pkcs7
except ImportError:
    print("Butuh paket 'cryptography' (pip install cryptography).")
    raise SystemExit(2)


def u32(b: bytes, o: int) -> int:
    return struct.unpack_from("<I", b, o)[0]


def u64(b: bytes, o: int) -> int:
    return struct.unpack_from("<Q", b, o)[0]


def certs_from_signing_block(data: bytes) -> list[tuple[str, x509.Certificate]]:
    """Ambil sertifikat dari APK Signing Block (v2/v3)."""
    out: list[tuple[str, x509.Certificate]] = []
    magic = data.rfind(b"APK Sig Block 42")
    if magic == -1:
        return out

    size_value = u64(data, magic - 8)
    end_pairs = magic - 8
    # Layout blok: [u64 size][pairs][u64 size][16 byte magic]
    pos = magic + 16 - size_value
    blocks: dict[int, bytes] = {}
    while pos + 12 <= end_pairs:
        ln = u64(data, pos)
        pos += 8
        pid = u32(data, pos)
        pos += 4
        if ln < 4 or pos + ln - 4 > len(data):
            break
        blocks[pid] = data[pos:pos + ln - 4]
        pos += ln - 4

    for pid, label in ((0x7109871A, "v2"), (0xF05368C0, "v3")):
        blob = blocks.get(pid)
        if not blob:
            continue
        # Blok ini berisi struktur ber-prefix panjang; cara paling tahan banting
        # adalah mencari DER X.509 valid di dalamnya.
        i = 0
        while i < len(blob) - 6:
            if blob[i] == 0x30 and blob[i + 1] in (0x81, 0x82, 0x83):
                lb = blob[i + 1]
                if lb == 0x81:
                    total = 3 + blob[i + 2]
                else:
                    n = lb - 0x80
                    total = (2 + n + int.from_bytes(blob[i + 2:i + 2 + n], "big")
                             if i + 2 + n <= len(blob) else 0)
                if total and i + total <= len(blob):
                    cand = blob[i:i + total]
                    try:
                        out.append((label, x509.load_der_x509_certificate(cand)))
                        i += total
                        continue
                    except Exception:
                        pass
            i += 1
    return out


def certs_from_meta_inf(apk: Path) -> list[tuple[str, x509.Certificate]]:
    """Skema v1 (APK lama / minSdk rendah)."""
    out: list[tuple[str, x509.Certificate]] = []
    try:
        with zipfile.ZipFile(apk) as z:
            for name in z.namelist():
                up = name.upper()
                if up.startswith("META-INF/") and up.endswith((".RSA", ".DSA", ".EC")):
                    for c in pkcs7.load_der_pkcs7_certificates(z.read(name)):
                        out.append(("v1 " + name, c))
    except Exception:
        pass
    return out


def fingerprint(cert: x509.Certificate) -> tuple[str, str]:
    import hashlib

    der = cert.public_bytes(Encoding.DER)
    s1 = ":".join(f"{b:02X}" for b in hashlib.sha1(der).digest())
    s256 = ":".join(f"{b:02X}" for b in hashlib.sha256(der).digest())
    return s1, s256


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    apk = Path(sys.argv[1])
    if not apk.exists():
        print("APK tidak ditemukan:", apk)
        return 2

    data = apk.read_bytes()
    found = certs_from_signing_block(data) + certs_from_meta_inf(apk)
    if not found:
        print("Tidak menemukan sertifikat (APK belum ditandatangani?).")
        return 1

    print(f"APK: {apk}  ({len(data):,} byte)")
    for label, cert in found:
        s1, s256 = fingerprint(cert)
        print(f"\n  skema      : {label}")
        print(f"  subject    : {cert.subject.rfc4514_string()}")
        print(f"  issuer     : {cert.issuer.rfc4514_string()}")
        print(f"  SHA-1      : {s1}")
        print(f"  SHA-256    : {s256}")
    print("\nDaftarkan SHA-1 dan SHA-256 di Firebase -> Project Settings -> Your apps.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
