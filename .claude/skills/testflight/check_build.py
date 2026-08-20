#!/usr/bin/env python3
"""Check processing state of the latest TestFlight build for Clearspace Mobile.

Usage: python3 check_build.py
Prints the newest build's version and processingState (PROCESSING -> VALID).
Requires the `cryptography` package (preinstalled on macOS system Python via brew).
"""
import time, json, base64, urllib.request
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from pathlib import Path

KEY_ID = "342DVT6RFF"
ISSUER = "48a9d8c2-81f0-43e1-a7cb-10a8c146a5ae"
APP_ID = "6803644015"  # Clearspace Mobile
KEY_PATH = Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{KEY_ID}.p8"


def _b64(x: bytes) -> bytes:
    return base64.urlsafe_b64encode(x).rstrip(b"=")


def token() -> str:
    key = serialization.load_pem_private_key(KEY_PATH.read_bytes(), password=None)
    header = _b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    now = int(time.time())
    payload = _b64(json.dumps({"iss": ISSUER, "iat": now, "exp": now + 1000,
                               "aud": "appstoreconnect-v1"}).encode())
    signing_input = header + b"." + payload
    r, s = decode_dss_signature(key.sign(signing_input, ec.ECDSA(hashes.SHA256())))
    return (signing_input + b"." + _b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()


def get(path: str):
    req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path,
                                 headers={"Authorization": "Bearer " + token()})
    return json.load(urllib.request.urlopen(req))


if __name__ == "__main__":
    builds = get(f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=3"
                 "&fields[builds]=version,processingState,uploadedDate")["data"]
    if not builds:
        print("No builds found (a fresh upload can take a few minutes to appear).")
    for b in builds:
        a = b["attributes"]
        print(f"build {a['version']}: {a['processingState']} (uploaded {a['uploadedDate']})")
