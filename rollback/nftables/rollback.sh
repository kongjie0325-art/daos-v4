#!/bin/bash
# ROLLBACK: nftables — restore a pre-snapshot ruleset / 回滚：恢复 nftables 规则快照
# Usage / 用法: ./rollback.sh <snapshot_path>

set -euo pipefail

SNAPSHOT="${1:-}"
if [ -z "$SNAPSHOT" ]; then
  echo "Usage: $0 <snapshot_path>"
  echo "用法：$0 <快照路径>"
  exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
  echo "ERROR: Snapshot not found: $SNAPSHOT"
  echo "错误：快照未找到：$SNAPSHOT"
  exit 1
fi

echo "[ROLLBACK] Restoring nftables from: $SNAPSHOT"
echo "[回滚] 从 $SNAPSHOT 恢复 nftables 规则"
nft -f "$SNAPSHOT" 2>&1
echo "[ROLLBACK] nftables restored successfully"
echo "[回滚] nftables 恢复成功"

# Verify / 验证
CURRENT=$(nft list ruleset | sha256sum | cut -d' ' -f1)
SNAPSHOT_HASH=$(sha256sum "$SNAPSHOT" | cut -d' ' -f1)
if [ "$CURRENT" = "$SNAPSHOT_HASH" ]; then
  echo "[VERIFY] Ruleset hash matches snapshot / 验证：规则哈希匹配"
  exit 0
else
  echo "[VERIFY] Ruleset hash MISMATCH — manual intervention required"
  echo "[验证] 规则哈希不匹配 — 需要手动干预"
  exit 2
fi
