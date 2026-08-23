#!/bin/bash
# Installs an App Store Connect API key so the tooling can use it.
#
# Run this in your OWN Terminal, not in the Claude session: the private key
# should never pass through a transcript. It is moved (not copied) out of
# Downloads into credentials/, which is gitignored and outside the git repo.
set -euo pipefail

ROOT="/Users/emanuelflury/Documents/tagalogue.tv"
CRED="$ROOT/credentials"
mkdir -p "$CRED"

KEY=$(ls -t ~/Downloads/AuthKey_*.p8 2>/dev/null | head -1 || true)
if [ -z "$KEY" ]; then
  echo "No AuthKey_*.p8 found in ~/Downloads."
  echo "App Store Connect → Users and Access → Integrations → App Store Connect API"
  echo "→ Team Keys → + → Access: App Manager → Generate → Download."
  echo "Apple lets you download it exactly once."
  exit 1
fi

BASE=$(basename "$KEY")
KEY_ID="${BASE#AuthKey_}"; KEY_ID="${KEY_ID%.p8}"
echo "Found $BASE  (Key ID: $KEY_ID)"

read -r -p "Issuer ID (the UUID on that same page): " ISSUER
[ -n "$ISSUER" ] || { echo "Issuer ID is required."; exit 1; }

mv "$KEY" "$CRED/$BASE"
chmod 600 "$CRED/$BASE"
cat > "$CRED/asc.json" <<JSON
{
  "keyId": "$KEY_ID",
  "issuerId": "$ISSUER",
  "keyFile": "$BASE"
}
JSON
chmod 600 "$CRED/asc.json"

echo
echo "Installed. Checking it works…"
"$ROOT/tools/asc/asc.py" GET "/v1/apps?limit=3" | head -20
