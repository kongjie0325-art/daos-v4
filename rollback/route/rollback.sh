#!/bin/bash
# ROLLBACK: Route — restore saved routing table | 回滚：恢复路由表快照
# Usage | 用法: ./rollback.sh <route_table_snapshot>

set -euo pipefail

SNAPSHOT="${1:-}"
if [ -z "$SNAPSHOT" ]; then
  echo "Usage: $0 <route_table_snapshot>"
  echo "用法：$0 <路由表快照路径>"
  exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
  echo "ERROR: Snapshot not found: $SNAPSHOT"
  echo "错误：快照未找到：$SNAPSHOT"
  exit 1
fi

echo "[ROLLBACK] Restoring route table from: $SNAPSHOT"
echo "[回滚] 从 $SNAPSHOT 恢复路由表"
while IFS= read -r route; do
  ip route add $route 2>/dev/null || true  # Idempotent | 幂等操作
done < "$SNAPSHOT"
echo "[ROLLBACK] Route table restored / [回滚] 路由表恢复完成"

# Verify | 验证
ip route show > /tmp/route_current.txt
if diff -q /tmp/route_current.txt "$SNAPSHOT" >/dev/null 2>&1; then
  echo "[VERIFY] Route table matches snapshot / [验证] 路由表与快照一致"
  rm /tmp/route_current.txt
  exit 0
else
  echo "[VERIFY] Route table MISMATCH — manual intervention required"
  echo "[验证] 路由表不匹配 — 需要手动干预"
  rm /tmp/route_current.txt
  exit 2
fi
