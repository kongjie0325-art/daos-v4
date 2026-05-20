#!/bin/bash
# ROLLBACK: nftables — restore a pre-snapshot ruleset
# Usage: ./rollback.sh <snapshot_path>

set -euo pipefail

SNAPSHOT="${1:-}"
if [ -z "$SNAPSHOT" ]; then
  echo "Usage: $0 <snapshot_path>"
  exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
  echo "ERROR: Snapshot not found: $SNAPSHOT"
  exit 1
fi

echo "[ROLLBACK] Restoring nftables from: $SNAPSHOT"
nft -f "$SNAPSHOT" 2>&1
echo "[ROLLBACK] nftables restored successfully"

# Verify
CURRENT=$(nft list ruleset | sha256sum | cut -d' ' -f1)
SNAPSHOT_HASH=$(sha256sum "$SNAPSHOT" | cut -d' ' -f1)
if [ "$CURRENT" = "$SNAPSHOT_HASH" ]; then
  echo "[VERIFY] Ruleset hash matches snapshot"
  exit 0
else
  echo "[VERIFY] Ruleset hash MISMATCH — manual intervention required"
  exit 2
fi
