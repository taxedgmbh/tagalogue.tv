#!/usr/bin/env python3
"""
Upload a folder of videos to Cloudflare Stream and record the playback URLs.

Source files are expected to come from an official export of your own channel
(Google Takeout, or YouTube Studio's per-video download) — not from scraping
youtube.com.

Usage:
    export CF_ACCOUNT_ID=...
    export CF_API_TOKEN=...          # token scoped to Stream:Edit only
    python3 tools/upload_to_cloudflare.py ./takeout/videos --out uploads.json

For each <name>.mp4 it will also upload <name>.en.vtt / <name>.tl.vtt as
caption tracks when they sit alongside it.

Writes uploads.json:  {"<filename>": {"uid": ..., "hls": ..., "duration": ...}}
Re-running skips anything already present in that file, so an interrupted
run resumes rather than duplicating uploads.
"""

import argparse, json, os, sys, urllib.request, urllib.error, mimetypes, uuid, base64, time

API = "https://api.cloudflare.com/client/v4"
TUS_THRESHOLD = 200 * 1024 * 1024      # Cloudflare requires tus above 200 MB
CHUNK = 50 * 1024 * 1024               # tus chunk size (must be a multiple of 256 KiB)

VIDEO_EXTS = {".mp4", ".mov", ".m4v", ".mkv", ".webm", ".avi"}


def env(name):
    v = os.environ.get(name)
    if not v:
        sys.exit(f"error: {name} is not set. Export it before running.")
    return v


def request(method, url, *, headers=None, data=None):
    req = urllib.request.Request(url, method=method, data=data)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req) as r:
            body = r.read()
            return r.status, dict(r.headers), body
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read()


def multipart(fields, files):
    """Build a multipart/form-data body. files: [(field, filename, bytes)]"""
    boundary = uuid.uuid4().hex
    out = b""
    for k, v in fields.items():
        out += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n").encode()
    for field, filename, blob in files:
        ctype = mimetypes.guess_type(filename)[0] or "application/octet-stream"
        out += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field}\"; "
                f"filename=\"{filename}\"\r\nContent-Type: {ctype}\r\n\r\n").encode()
        out += blob + b"\r\n"
    out += f"--{boundary}--\r\n".encode()
    return f"multipart/form-data; boundary={boundary}", out


def upload_direct(account, token, path):
    """Simple multipart upload, for files under the tus threshold."""
    blob = open(path, "rb").read()
    ctype, body = multipart({}, [("file", os.path.basename(path), blob)])
    status, _, resp = request(
        "POST", f"{API}/accounts/{account}/stream",
        headers={"Authorization": f"Bearer {token}", "Content-Type": ctype},
        data=body,
    )
    payload = json.loads(resp or b"{}")
    if status != 200 or not payload.get("success"):
        raise RuntimeError(f"upload failed ({status}): {payload.get('errors') or resp[:300]}")
    return payload["result"]


def upload_tus(account, token, path, name):
    """Resumable upload — required by Cloudflare for files over 200 MB."""
    size = os.path.getsize(path)
    meta = base64.b64encode(name.encode()).decode()
    status, headers, resp = request(
        "POST", f"{API}/accounts/{account}/stream",
        headers={
            "Authorization": f"Bearer {token}",
            "Tus-Resumable": "1.0.0",
            "Upload-Length": str(size),
            "Upload-Metadata": f"name {meta}",
        },
    )
    if status not in (200, 201) or "Location" not in headers:
        raise RuntimeError(f"tus create failed ({status}): {resp[:300]}")
    location = headers["Location"]
    uid = headers.get("stream-media-id")

    offset = 0
    with open(path, "rb") as fh:
        while offset < size:
            chunk = fh.read(CHUNK)
            st, hd, rb = request(
                "PATCH", location,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Tus-Resumable": "1.0.0",
                    "Upload-Offset": str(offset),
                    "Content-Type": "application/offset+octet-stream",
                },
                data=chunk,
            )
            if st != 204:
                raise RuntimeError(f"tus chunk at {offset} failed ({st}): {rb[:300]}")
            offset = int(hd.get("Upload-Offset", offset + len(chunk)))
            print(f"      {offset / size * 100:5.1f}%", end="\r", flush=True)
    print("      100.0%")
    return {"uid": uid}


def fetch_details(account, token, uid, tries=30):
    """Poll until Cloudflare finishes encoding, so we can record duration + HLS."""
    for _ in range(tries):
        st, _, rb = request("GET", f"{API}/accounts/{account}/stream/{uid}",
                            headers={"Authorization": f"Bearer {token}"})
        d = json.loads(rb or b"{}")
        if st == 200 and d.get("success"):
            r = d["result"]
            if r.get("status", {}).get("state") == "ready":
                return r
        time.sleep(10)
    return None


def upload_caption(account, token, uid, lang, path):
    blob = open(path, "rb").read()
    ctype, body = multipart({}, [("file", os.path.basename(path), blob)])
    st, _, rb = request(
        "POST", f"{API}/accounts/{account}/stream/{uid}/captions/{lang}",
        headers={"Authorization": f"Bearer {token}", "Content-Type": ctype},
        data=body,
    )
    ok = st == 200 and json.loads(rb or b"{}").get("success")
    print(f"      caption {lang}: {'ok' if ok else 'FAILED ' + rb[:200].decode(errors='replace')}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder", help="folder of exported video files")
    ap.add_argument("--out", default="uploads.json")
    ap.add_argument("--dry-run", action="store_true", help="list what would upload, touch nothing")
    args = ap.parse_args()

    account, token = env("CF_ACCOUNT_ID"), env("CF_API_TOKEN")

    done = json.load(open(args.out)) if os.path.exists(args.out) else {}
    files = sorted(f for f in os.listdir(args.folder)
                   if os.path.splitext(f)[1].lower() in VIDEO_EXTS)
    if not files:
        sys.exit(f"no video files found in {args.folder}")

    print(f"{len(files)} video(s); {len(done)} already uploaded\n")
    for name in files:
        if name in done:
            print(f"  skip  {name}")
            continue
        path = os.path.join(args.folder, name)
        size = os.path.getsize(path)
        mode = "tus" if size > TUS_THRESHOLD else "direct"
        print(f"  {mode:6s} {name}  ({size / 1e6:.0f} MB)")
        if args.dry_run:
            continue

        result = (upload_tus if size > TUS_THRESHOLD else upload_direct)(
            *( (account, token, path, name) if size > TUS_THRESHOLD else (account, token, path) )
        )
        uid = result.get("uid")
        stem = os.path.splitext(name)[0]
        for lang in ("en", "tl"):
            vtt = os.path.join(args.folder, f"{stem}.{lang}.vtt")
            if os.path.exists(vtt):
                upload_caption(account, token, uid, lang, vtt)

        details = fetch_details(account, token, uid) or {}
        done[name] = {
            "uid": uid,
            "hls": (details.get("playback") or {}).get("hls"),
            "duration": details.get("duration"),
            "ready": bool(details),
        }
        json.dump(done, open(args.out, "w"), indent=2)
        print(f"      uid={uid}  hls={done[name]['hls']}")

    print(f"\nwrote {args.out} ({len(done)} entries)")
    if any(not v.get("ready") for v in done.values()):
        print("note: some videos were still encoding — re-run to fill in their HLS URLs.")


if __name__ == "__main__":
    main()
