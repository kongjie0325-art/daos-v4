#!/bin/bash
# ROLLBACK: DNS — restore zone file from snapshot
# Usage: ./rollback.sh <dns_zone_snapshot> <zone_name>

set -euo pipefail

SNAPSHOT="${1:-}"
ZONE="${2:-}"
if [ -z "$SNAPSHOT" ] || [ -z "$ZONE" ]; then
  echo "Usage: $0 <dns_zone_snapshot> <zone_name>"
  exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
  echo "ERROR: Snapshot not found: $SNAPSHOT"
  exit 1
fi

echo "[ROLLBACK] Restoring DNS zone '$ZONE' from: $SNAPSHOT"
cp "$SNAPSHOT" "/etc/bind/zones/$ZONE.zone"
rndc reload "$ZONE" 2>&1
echo "[ROLLBACK] DNS zone '$ZONE' restored"

# Verify
echo "[VERIFY] Zone '$ZONE' reloaded — check journal for errors"
