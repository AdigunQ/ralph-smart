#!/bin/bash

###############################################################################
# External Docs Fetcher
# Pulls documentation from a list of URLs into specs/external_docs/
###############################################################################

set -euo pipefail

URLS_FILE="${URLS_FILE:-specs/external_docs/urls.txt}"
OUT_DIR="${OUT_DIR:-specs/external_docs/raw}"
TEXT_DIR="${TEXT_DIR:-specs/external_docs/text}"
MANIFEST_FILE="${MANIFEST_FILE:-specs/external_docs/manifest.csv}"
USER_AGENT="${USER_AGENT:-RalphDocsFetcher/1.0}"

log() {
    echo "[docs] $1"
}

if [ ! -f "$URLS_FILE" ]; then
    log "URL list not found: $URLS_FILE"
    exit 1
fi

mkdir -p "$OUT_DIR"
mkdir -p "$TEXT_DIR"
mkdir -p "$(dirname "$MANIFEST_FILE")"

if command -v curl >/dev/null 2>&1; then
    FETCH_TOOL="curl"
elif command -v wget >/dev/null 2>&1; then
    FETCH_TOOL="wget"
else
    log "Neither curl nor wget found."
    exit 1
fi

echo "url,file,status" > "$MANIFEST_FILE"

while IFS= read -r url; do
    url="$(echo "$url" | tr -d '\r')"
    [ -z "$url" ] && continue
    [[ "$url" == \#* ]] && continue

    safe_name="$(python3 - <<'PY' "$url"
import re
import sys
import urllib.parse as up

u = sys.argv[1].strip()
parsed = up.urlparse(u)
path = parsed.path.strip("/") or "index"
base = f"{parsed.netloc}_{path}"
base = re.sub(r"[^A-Za-z0-9._-]", "_", base)
if len(base) > 120:
    base = base[:120]
ext = ""
for candidate in [".md", ".markdown", ".txt", ".html", ".htm", ".pdf"]:
    if base.lower().endswith(candidate):
        ext = ""
        break
if not any(base.lower().endswith(x) for x in [".md", ".markdown", ".txt", ".html", ".htm", ".pdf"]):
    ext = ".html"
print(base + ext)
PY
)"

    out_path="$OUT_DIR/$safe_name"
    status="ok"

    if [ "$FETCH_TOOL" = "curl" ]; then
        if ! curl -L --fail --retry 3 -A "$USER_AGENT" "$url" -o "$out_path" >/dev/null 2>&1; then
            status="error"
        fi
    else
        if ! wget -qO "$out_path" "$url"; then
            status="error"
        fi
    fi

    echo "\"$url\",\"$out_path\",\"$status\"" >> "$MANIFEST_FILE"

    if [ "$status" = "ok" ]; then
        ext="${out_path##*.}"
        if [ "$ext" = "html" ] || [ "$ext" = "htm" ]; then
            text_out="$TEXT_DIR/$(basename "${out_path%.*}").txt"
            if command -v python3 >/dev/null 2>&1; then
                python3 - <<'PY' "$out_path" "$text_out" || true
import html
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
data = src.read_text(encoding="utf-8", errors="ignore")

# Strip scripts/styles
data = re.sub(r"<script[\\s\\S]*?</script>", " ", data, flags=re.IGNORECASE)
data = re.sub(r"<style[\\s\\S]*?</style>", " ", data, flags=re.IGNORECASE)

# Drop tags
text = re.sub(r"<[^>]+>", " ", data)
text = html.unescape(text)
text = re.sub(r"\\s+", " ", text).strip()

dst.write_text(text, encoding="utf-8")
PY
            fi
        elif [ "$ext" = "md" ] || [ "$ext" = "markdown" ] || [ "$ext" = "txt" ]; then
            cp "$out_path" "$TEXT_DIR/$(basename "$out_path")" 2>/dev/null || true
        fi
    fi
    log "$url -> $out_path ($status)"
done < "$URLS_FILE"

log "Manifest: $MANIFEST_FILE"
