#!/usr/bin/env python3
"""
App Store Connect API client.

Small on purpose: no third-party packages are installed on this machine, so the
ES256 token is minted with the openssl binary and the DER signature converted
to the raw r||s pair JWT requires. Everything else is plain HTTPS.

The private key never leaves credentials/ and is never printed.

    ./asc.py GET  /v1/apps
    ./asc.py GET  /v1/builds?filter[app]=<id>&limit=5
    ./asc.py POST /v1/betaGroups '{"data": {...}}'
"""

import base64, json, pathlib, subprocess, sys, time, urllib.request, urllib.error

CRED = pathlib.Path(__file__).resolve().parents[2] / "credentials"
CONFIG = CRED / "asc.json"
API = "https://api.appstoreconnect.apple.com"


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """ECDSA signatures come out of openssl as DER; JWT wants raw r||s, 32 bytes each."""
    if der[0] != 0x30:
        raise ValueError("not a DER sequence")
    # Skip SEQUENCE header (handling the long-form length byte).
    i = 2 + (1 if der[1] & 0x80 else 0)

    def integer(pos):
        assert der[pos] == 0x02, "expected INTEGER"
        length = der[pos + 1]
        value = der[pos + 2 : pos + 2 + length].lstrip(b"\x00")
        return value.rjust(32, b"\x00"), pos + 2 + length

    r, i = integer(i)
    s, _ = integer(i)
    return r + s


def token() -> str:
    if not CONFIG.exists():
        sys.exit(f"No {CONFIG}. Run tools/asc/setup.sh first.")
    cfg = json.loads(CONFIG.read_text())
    key = CRED / cfg["keyFile"]
    if not key.exists():
        sys.exit(f"Private key missing: {key}")

    now = int(time.time())
    header = {"alg": "ES256", "kid": cfg["keyId"], "typ": "JWT"}
    # Apple rejects anything longer than 20 minutes.
    payload = {
        "iss": cfg["issuerId"],
        "iat": now,
        "exp": now + 19 * 60,
        "aud": "appstoreconnect-v1",
    }
    signing_input = f"{b64(json.dumps(header, separators=(',', ':')).encode())}." \
                    f"{b64(json.dumps(payload, separators=(',', ':')).encode())}"

    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key)],
        input=signing_input.encode(), capture_output=True, check=True
    ).stdout
    return f"{signing_input}.{b64(der_to_raw(der))}"


def call(method: str, path: str, body: str | None = None):
    request = urllib.request.Request(
        API + path,
        method=method,
        data=body.encode() if body else None,
        headers={
            "Authorization": f"Bearer {token()}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return response.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw.decode("utf-8", "ignore")[:500]}


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    status, data = call(sys.argv[1].upper(), sys.argv[2],
                        sys.argv[3] if len(sys.argv) > 3 else None)
    # Full body, not truncated: callers pipe this into json.loads, and a cut
    # response is invalid JSON rather than a shorter one.
    print(f"HTTP {status}", file=sys.stderr)
    print(json.dumps(data, indent=2) if data is not None else "")
