#!/bin/bash
# ROLLBACK: DNS — restore zone file from snapshot | 回滚：恢复 DNS 区域文件快照
# Usage | 用法: ./rollback.sh <dns_zone_snapshot> <zone_name>

set -euo pipefail

SNAPSHOT="${1:-}"
ZONE="${2:-}"
if [ -z "$SNAPSHOT" ] || [ -z "$ZONE" ]; then
  echo "Usage: $0 <dns_zone_snapshot> <zone_name>"
  echo "用法：$0 <DNS区域快照路径> <区域名称>"
  exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
  echo "ERROR: Snapshot not found: $SNAPSHOT"
  echo "错误：快照未找到：$SNAPSHOT"
  exit 1
fi

echo "[ROLLBACK] Restoring DNS zone '$ZONE' from: $SNAPSHOT"
echo "[回滚] 从 $SNAPSHOT 恢复 DNS 区域 '$ZONE'"
cp "$SNAPSHOT" "/etc/bind/zones/$ZONE.zone"
rndc reload "$ZONE" 2>&1  # Reload zone in BIND | 在 BIND 中重新加载区域
echo "[ROLLBACK] DNS zone '$ZONE' restored"
echo "[回滚] DNS 区域 '$ZONE' 恢复成功"

# Verify | 验证
echo "[VERIFY] Zone '$ZONE' reloaded — check journal for errors"
echo "[验证] 区域 '$ZONE' 已重新加载 — 检查日志确认无错误"
