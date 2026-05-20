#!/usr/bin/env bash
# DAOS v4 Deploy Task — 交给 Hermes AI 执行的部署任务书
# 用法: hermes-task run deploy-daos-v4
set -euo pipefail

# ============================================================
# Phase 0: 环境准备
# ============================================================
PHASE="Phase 0 — Environment Prep"
echo "[$PHASE] Checking prerequisites..."

command -v docker >/dev/null 2>&1 || { echo "Docker not found"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Git not found"; exit 1; }

# 创建 DAOS 目录
mkdir -p /opt/daos/{baseline,policies,schemas,services,memory,rollback,deploy}

# 克隆基线仓库
if [ ! -d /opt/daos/baseline/.git ]; then
  git clone https://github.com/kongjie0325-art/daos-v4.git /opt/daos/repo
  cp -r /opt/daos/repo/baseline/* /opt/daos/baseline/
  cp -r /opt/daos/repo/policies/* /opt/daos/policies/
fi

echo "[$PHASE] ✅ Complete"

# ============================================================
# Phase 1: 核心服务 (PostgreSQL + Redis + NATS + OPA)
# ============================================================
PHASE="Phase 1 — Core Services"
echo "[$PHASE] Deploying core services..."

# PostgreSQL with pgvector
docker run -d --name daos-postgres \
  --network host \
  -e POSTGRES_PASSWORD="${PG_PASSWORD:-changeme}" \
  -e POSTGRES_DB=daos \
  -v /opt/daos/data/postgres:/var/lib/postgresql/data \
  pgvector/pgvector:pg16

# Redis
docker run -d --name daos-redis \
  --network host \
  -v /opt/daos/data/redis:/data \
  redis:7-alpine

# NATS JetStream
docker run -d --name daos-nats \
  --network host \
  -v /opt/daos/data/nats:/data \
  nats:2-alpine -js

# OPA
docker run -d --name daos-opa \
  --network host \
  -v /opt/daos/policies:/policies \
  openpolicyagent/opa:latest run --server --addr :8181 /policies

echo "[$PHASE] ✅ Complete"

# ============================================================
# Phase 2: DAOS 核心服务
# ============================================================
PHASE="Phase 2 — DAOS Core Services"
echo "[$PHASE] Deploying DAOS services..."

# 每个服务作为独立容器 (初始阶段用 busybox + 配置挂载占位)
for svc in drift-detector intent-compiler policy-gateway simulator executor verifier audit-recorder; do
  mkdir -p /opt/daos/services/$svc
  docker run -d --name daos-$svc \
    --network host \
    -v /opt/daos/services/$svc:/config \
    alpine:3.19 sleep infinity
done

echo "[$PHASE] ✅ Complete"

# ============================================================
# Phase 3: 记忆与审计
# ============================================================
PHASE="Phase 3 — Memory & Audit"
echo "[$PHASE] Deploying memory layer..."

mkdir -p /opt/daos/memory/{evidence,episodic,semantic}
mkdir -p /opt/daos/audit

echo "[$PHASE] ✅ Complete"

# ============================================================
# Phase 4: 验收检查
# ============================================================
PHASE="Phase 4 — Smoke Test"
echo "[$PHASE] Running verification..."

# Check OPA
OPA_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8181/v1/health || echo "000")
echo "  OPA: $OPA_HEALTH"

# Check NATS
NATS_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8222/healthz || echo "000")
echo "  NATS: $NATS_HEALTH"

# Check PostgreSQL
PG_HEALTH=$(docker exec daos-postgres pg_isready -q && echo "200" || echo "000")
echo "  PostgreSQL: $PG_HEALTH"

# Check Redis
REDIS_HEALTH=$(docker exec daos-redis redis-cli ping 2>/dev/null || echo "FAIL")
echo "  Redis: $REDIS_HEALTH"

# Simulate OPA policy test
OPA_RESULT=$(curl -s -X POST http://localhost:8181/v1/data/execution/allow \
  -d '{"input": {"action": "observe", "target": "read-only", "risk": "low"}}' 2>/dev/null)
echo "  OPA Policy Test: $OPA_RESULT"

echo "[$PHASE] ✅ Complete"

# ============================================================
# Summary
# ============================================================
echo ""
echo "========================================"
echo " DAOS v4 Deployment Summary"
echo "========================================"
echo " Services:"
docker ps --filter "name=daos-" --format "  {{.Names}} → {{.Status}}"
echo ""
echo " Endpoints:"
echo "  OPA:      http://localhost:8181"
echo "  NATS:     nats://localhost:4222"
echo "  NATS Mon: http://localhost:8222"
echo "  Postgres: localhost:5432"
echo "  Redis:    localhost:6379"
echo ""
echo " Paths:"
echo "  Baseline: /opt/daos/baseline/"
echo "  Policies: /opt/daos/policies/"
echo "  Audit:    /opt/daos/audit/"
echo "  Memory:   /opt/daos/memory/"
echo "========================================"
