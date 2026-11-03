#!/bin/bash
# MangoTime：PROGRESS.md → dashboard HTML → rsync 上 VPS。每完成一步跑一次。
set -euo pipefail
cd "$(dirname "$0")/.."
TOKEN=$(cat scripts/dashboard_token.txt)
OUT=/tmp/mt-dash-out
rm -rf "$OUT"; mkdir -p "$OUT/p/$TOKEN"
python3 scripts/render_progress.py PROGRESS.md "$OUT/p/$TOKEN/index.html"
rsync -az --delete -e "ssh -i /Users/simon/.ssh/hermes_vps_ed25519 -o BatchMode=yes" \
  "$OUT/" root@149.28.154.219:/opt/mangotime-dashboard/
echo "deployed: http://mangotime-dash.149-28-154-219.sslip.io/p/$TOKEN/"
