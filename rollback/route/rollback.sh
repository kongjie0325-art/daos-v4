#!/bin/bash
# ROLLBACK: Route — restore saved routing table
# Usage: ./rollback.sh <route_table_snapshot>

set -euo pipefail

SNAPSHOT="${1:-}"
if [ -z "$SNAPSHOT" ]; then
  echo "Usage: $0 <route_table_snapshot>"
  exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
  echo "ERROR: Snapshot not found: $SNAPSHOT"
  exit 1
fi

echo "[ROLLBACK] Restoring route table from: $SNAPSHOT"
while IFS= read -r route; do
  ip route add $route 2>/dev/null || true
done < "$SNAPSHOT"
echo "[ROLLBACK] Route table restored"

# Verify
ip route show > /tmp/route_current.txt
if diff -q /tmp/route_current.txt "$SNAPSHOT" >/dev/null 2>&1; then
  echo "[VERIFY] Route table matches snapshot"
  rm /tmp/route_current.txt
  exit 0
else
  echo "[VERIFY] Route table MISMATCH — manual intervention required"
  rm /tmp/route_current.txt
  exit 2
fi
