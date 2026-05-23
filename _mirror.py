#!/usr/bin/env python3
"""Mirror every plugin in manifest.json into the local repo under plugins/,
and rewrite download_url to point to raw.githubusercontent.com of this repo.

Run on the server inside /root/vexor-plugin-catalog/.
"""
from __future__ import annotations
import json, os, re, sys, time, hashlib
from urllib import request, error

ROOT = "/root/vexor-plugin-catalog"
PLUGINS = os.path.join(ROOT, "plugins")
MANIFEST = os.path.join(ROOT, "manifest.json")
REPO_RAW = "https://raw.githubusercontent.com/sayonarase/vexor-plugin-catalog/main/plugins"

LANG_EXT = {
    "python": ".py", "python3": ".py", "py": ".py",
    "perl": ".pl", "pl": ".pl",
    "shell": ".sh", "bash": ".sh", "sh": ".sh",
    "ruby": ".rb", "rb": ".rb",
    "php": ".php",
    "go": ".go", "golang": ".go",
    "javascript": ".js", "js": ".js", "node": ".js",
    "c": ".c", "cpp": ".cpp",
    "powershell": ".ps1", "ps1": ".ps1",
}

# Headers must look like a regular user agent and (when available) carry the token.
TOKEN = os.environ.get("GH_TOKEN", "").strip()
HEADERS = {"User-Agent": "vexor-catalog-mirror/1.0"}
if TOKEN:
    HEADERS["Authorization"] = f"token {TOKEN}"

os.makedirs(PLUGINS, exist_ok=True)

def safe(name: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9._-]+", "_", name)
    return s.strip("._-") or "plugin"

def pick_ext(entry: dict, url: str) -> str:
    base = url.split("?")[0].rsplit("/", 1)[-1]
    if "." in base:
        ext = "." + base.rsplit(".", 1)[-1].lower()
        if 2 <= len(ext) <= 6:
            return ext
    lang = (entry.get("language") or "").lower()
    return LANG_EXT.get(lang, ".sh")

def fetch(url: str, retries: int = 3) -> bytes | None:
    for i in range(retries):
        try:
            req = request.Request(url, headers=HEADERS)
            with request.urlopen(req, timeout=20) as r:
                return r.read()
        except error.HTTPError as e:
            if e.code in (403, 429):
                wait = 30 * (i + 1)
                print(f"  rate limit {e.code}; sleep {wait}s", flush=True)
                time.sleep(wait)
                continue
            print(f"  HTTP {e.code} {url}", flush=True)
            return None
        except Exception as e:
            print(f"  ERR {type(e).__name__} {url}", flush=True)
            time.sleep(2)
    return None

def main() -> int:
    with open(MANIFEST) as f:
        entries = json.load(f)
    total = len(entries)
    ok = skip = fail = 0
    seen_names: dict[str, int] = {}
    for i, e in enumerate(entries, 1):
        name = e.get("name") or f"plugin_{i}"
        url = e.get("download_url") or ""
        if not url:
            fail += 1
            print(f"[{i}/{total}] {name}: no download_url", flush=True)
            continue
        # If already mirrored to our repo, skip
        if "sayonarase/vexor-plugin-catalog" in url:
            ok += 1
            continue
        ext = pick_ext(e, url)
        fname = safe(name)
        if not fname.lower().endswith(ext):
            fname += ext
        # Disambiguate dupes
        if fname in seen_names:
            seen_names[fname] += 1
            stem, dot, e2 = fname.rpartition(".")
            fname = f"{stem}_{seen_names[fname]}.{e2}"
        else:
            seen_names[fname] = 0
        dst = os.path.join(PLUGINS, fname)
        if os.path.exists(dst) and os.path.getsize(dst) > 0:
            # Already downloaded; just rewrite URL
            e["original_url"] = e.get("original_url") or url
            e["download_url"] = f"{REPO_RAW}/{fname}"
            skip += 1
            continue
        print(f"[{i}/{total}] {name} <- {url}", flush=True)
        data = fetch(url)
        if data is None:
            fail += 1
            continue
        # Skip HTML/error pages (size sanity check)
        if len(data) < 30 or data.lstrip().startswith(b"<!DOCTYPE html"):
            print(f"  bad content for {name}", flush=True)
            fail += 1
            continue
        with open(dst, "wb") as fh:
            fh.write(data)
        e["original_url"] = e.get("original_url") or url
        e["download_url"] = f"{REPO_RAW}/{fname}"
        e["sha256"] = hashlib.sha256(data).hexdigest()
        e["size"] = len(data)
        ok += 1
        time.sleep(0.15)  # be polite

    with open(MANIFEST, "w") as f:
        json.dump(entries, f, indent=2, ensure_ascii=False)
    print(f"\nDone. ok={ok} skip={skip} fail={fail} total={total}", flush=True)
    return 0

if __name__ == "__main__":
    sys.exit(main())
