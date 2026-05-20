# DAOS v4 — Hermes AI Deployment Task / Hermes AI 部署任务书

> 此文件是交给 Hermes AI 执行的 **部署任务书**。
> 在 Hermes 对话中执行: `hermes task deploy-daos-v4` 或按下面的 Phase 逐步执行。

## Task Overview / 任务概述

目标：在指定 VPS/容器环境中部署 **DAOS v4 最小可行版**（MVP）。

**核心原则：**
1. 只改动指定目录和容器
2. 所有变更必须可回滚
3. 任何高风险操作先进入沙箱
4. 任何策略文件必须签名
5. 任何生产变更必须先模拟
6. 任何失败必须写入审计日志

## Deployment Phases / 部署阶段

---

### Phase 0: Environment Preparation / 环境准备

```
目标: 安装基础依赖 + 创建专用目录 + 防火墙白名单
```

**Hermes 指令：**
```bash
# 检查 Docker
docker info

# 创建 DAOS 目录
mkdir -p /opt/daos/{baseline,policies,schemas,services,memory,rollback,deploy,audit,data/{postgres,redis,nats}}

# 克隆仓库
gh repo clone kongjie0325-art/daos-v4 /opt/daos/repo
# 或
git clone https://github.com/kongjie0325-art/daos-v4.git /opt/daos/repo

# 复制基线文件
cp -r /opt/daos/repo/baseline/* /opt/daos/baseline/
cp -r /opt/daos/repo/policies/* /opt/daos/policies/
cp -r /opt/daos/repo/deploy/* /opt/daos/deploy/
```

**验收标准：**
- [ ] Docker 运行中
- [ ] `/opt/daos/` 目录结构完整
- [ ] baseline 文件可读
- [ ] OPA 策略文件 (`.rego`) 存在

---

### Phase 1: Core Services / 核心服务

```
目标: 部署 PostgreSQL + pgvector、Redis、NATS JetStream、OPA
```

**Hermes 指令：**
```bash
cd /opt/daos

# PostgreSQL with pgvector
docker run -d --name daos-postgres \
  --restart unless-stopped \
  --network host \
  -e POSTGRES_PASSWORD="${PG_PASSWORD:?must be set}" \
  -e POSTGRES_DB=daos \
  -v /opt/daos/data/postgres:/var/lib/postgresql/data \
  pgvector/pgvector:pg16

# Redis
docker run -d --name daos-redis \
  --restart unless-stopped \
  --network host \
  -v /opt/daos/data/redis:/data \
  redis:7-alpine redis-server --appendonly yes

# NATS JetStream
docker run -d --name daos-nats \
  --restart unless-stopped \
  --network host \
  -v /opt/daos/data/nats:/data \
  nats:2-alpine -js -sd /data

# OPA
docker run -d --name daos-opa \
  --restart unless-stopped \
  --network host \
  -v /opt/daos/policies:/policies \
  openpolicyagent/opa:latest run --server --addr :8181 /policies
```

**验收标准：**
- [ ] `docker ps` 显示 4 个容器全部 Healthy
- [ ] `curl localhost:8181/v1/health` → 200
- [ ] `curl localhost:8222/healthz` → 200
- [ ] `docker exec daos-postgres pg_isready` → 0
- [ ] `docker exec daos-redis redis-cli ping` → PONG

---

### Phase 2: DAOS Services / DAOS 服务

```
目标: 部署 7 个 DAOS 核心服务（drift-detector / intent-compiler / policy-gateway / simulator / executor / verifier / audit-recorder）
```

每个服务初始阶段以配置挂载 + 健康检查占位运行。服务实际代码在后续迭代中开发。

**Hermes 指令：**
```bash
for svc in drift-detector intent-compiler policy-gateway simulator executor verifier audit-recorder; do
  mkdir -p /opt/daos/services/$svc
  cp /opt/daos/repo/services/$svc/*.yaml /opt/daos/services/$svc/ 2>/dev/null || true
done
```

**验收标准：**
- [ ] `/opt/daos/services/` 下 7 个服务目录
- [ ] 每个目录包含 config.yaml

---

### Phase 3: Memory & Audit / 记忆与审计

```
目标: 部署证据存储、事件存储、语义存储、信任注册表
```

**Hermes 指令：**
```bash
mkdir -p /opt/daos/memory/{evidence,episodic,semantic}

# Evidence 存储 (PostgreSQL 建表)
docker exec -i daos-postgres psql -U postgres -d daos << 'EOSQL'
CREATE TABLE IF NOT EXISTS evidence (
  id BIGSERIAL PRIMARY KEY,
  event_id UUID NOT NULL DEFAULT gen_random_uuid(),
  source TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  raw_artifact_path TEXT,
  verified_by TEXT,
  verification_method TEXT,
  retention_until TIMESTAMPTZ,
  policy_version TEXT,
  source_hash TEXT NOT NULL,
  created_by TEXT DEFAULT 'daos-agent',
  provenance JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_evidence_source ON evidence(source);
CREATE INDEX idx_evidence_type ON evidence(event_type);
CREATE INDEX idx_evidence_created ON evidence(created_at DESC);
EOSQL
```

**验收标准：**
- [ ] `evidence` 表存在
- [ ] 字段包含 `policy_version`, `source_hash`, `created_by`, `provenance`

---

### Phase 4: Verification / 验收

```
目标: 运行 smoke test，验证整个控制循环可用
```

**Hermes 指令：**
```bash
# 1. 读取基线
cat /opt/daos/baseline/thresholds.yaml

# 2. 测试 OPA 策略
curl -s -X POST http://localhost:8181/v1/data/execution/allow \
  -d '{"input": {"action": "observe", "target": "read-only", "risk": "low"}}'

# 3. 验证 OPA 拒绝高风险操作
curl -s -X POST http://localhost:8181/v1/data/execution/allow \
  -d '{"input": {"action": "modify", "target": "nftables", "risk": "high", "has_snapshot": false}}'

# 4. 验证 simulation 数据独立
docker exec daos-postgres psql -U postgres -d daos -c "SELECT 'Evidence table ready' AS status;"

# 5. 验证审计日志可写
echo "{\"event\":\"audit-test\",\"ts\":\"$(date -Iseconds)\"}" > /opt/daos/audit/$(date +%Y%m%d).jsonl
```

**验收清单：**

| # | 检查项 | 预期 |
|---|---|---|
| 1 | GitOps 基线可读取 | ✅ |
| 2 | OPA 策略检查通过 | ✅ |
| 3 | OPA 拒绝缺失回滚的操作 | ✅ |
| 4 | PostgreSQL 表已建 | ✅ |
| 5 | 审计日志可追加 | ✅ |
| 6 | 模拟与生产数据分离 | ✅ |

---

## Verification Output / 验收输出

部署完成后，Hermes AI 应输出以下验收报告：

```json
{
  "deployment": "DAOS v4 MVP",
  "timestamp": "",
  "services": [
    {"name": "daos-postgres", "status": "healthy", "port": 5432},
    {"name": "daos-redis", "status": "healthy", "port": 6379},
    {"name": "daos-nats", "status": "healthy", "ports": [4222, 8222]},
    {"name": "daos-opa", "status": "healthy", "port": 8181}
  ],
  "paths": {
    "baseline": "/opt/daos/baseline/",
    "policies": "/opt/daos/policies/",
    "audit": "/opt/daos/audit/",
    "memory": "/opt/daos/memory/"
  },
  "verification": {
    "baseline_readable": true,
    "opa_policy_allow": true,
    "opa_policy_deny": true,
    "pg_table_exists": true,
    "audit_writable": true
  }
}
```

## Rollback / 回滚

如需回滚整个部署：

```bash
# 停止并删除所有 DAOS 容器
docker rm -f daos-postgres daos-redis daos-nats daos-opa

# 停止 DAOS 服务容器
for svc in drift-detector intent-compiler policy-gateway simulator executor verifier audit-recorder; do
  docker rm -f daos-$svc 2>/dev/null || true
done

# 保留数据目录，仅删除运行时
echo "DAOS v4 rolled back. Data preserved at /opt/daos/data/"
```
