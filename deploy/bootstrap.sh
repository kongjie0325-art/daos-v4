#!/bin/bash
# DAOS v4 bootstrap.sh — Initial environment setup | 初始环境配置
# Run once on the control VPS to prepare for docker-compose up
# 在控制 VPS 上运行一次，为 docker-compose up 做准备

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== DAOS v4 Bootstrap | 引导 ==="

# 1. Check prerequisites | 检查前提条件
echo "[CHECK] docker..."
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }

echo "[CHECK] docker compose..."
docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose not found"; exit 1; }

echo "[CHECK] git..."
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }

# 2. Create required directories | 创建所需目录
echo "[SETUP] Creating data directories | 创建数据目录..."
mkdir -p "${SCRIPT_DIR}/../data/audit"
mkdir -p "${SCRIPT_DIR}/../data/prometheus"

# 3. Copy env if not exists | 复制环境变量文件
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
  echo "[SETUP] Creating .env from env.example | 从 env.example 创建 .env..."
  cp "${SCRIPT_DIR}/env.example" "${SCRIPT_DIR}/.env"
  echo "!! IMPORTANT: Edit ${SCRIPT_DIR}/.env and set a strong PG_PASSWORD !!"
  echo "!! 重要：编辑 ${SCRIPT_DIR}/.env 设置强密码 !!"
fi

# 4. Pull images | 拉取镜像
echo "[PULL] Pulling Docker images | 拉取 Docker 镜像..."
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" pull

# 5. Initialize database | 初始化数据库
echo "[DB] Creating PostgreSQL init script | 创建 PostgreSQL 初始化脚本..."
cat > "${SCRIPT_DIR}/init-db.sh" << 'EOF'
#!/bin/bash
set -e

# DAOS v4 Database Initialization | 数据库初始化
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Enable extensions | 启用扩展
    CREATE EXTENSION IF NOT EXISTS vector;    -- Vector for embeddings | 向量嵌入
    CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- UUID generation / UUID 生成

    -- Evidence table (append-only) | 证据表（仅追加）
    CREATE TABLE IF NOT EXISTS evidence (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        source VARCHAR(128) NOT NULL,
        raw_artifact_path VARCHAR(512),
        timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        metric_type VARCHAR(64),
        value JSONB,
        verified_by VARCHAR(128),
        verification_method VARCHAR(128),
        retention_until TIMESTAMPTZ,
        policy_version VARCHAR(32),
        source_hash VARCHAR(64),
        created_by VARCHAR(128) NOT NULL DEFAULT 'daos',
        provenance JSONB
    );

    -- Episodic table (low-freq summaries) | 事件表（低频摘要）
    CREATE TABLE IF NOT EXISTS episodic (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        session_id VARCHAR(64) NOT NULL,
        summary TEXT,
        start_time TIMESTAMPTZ NOT NULL,
        end_time TIMESTAMPTZ,
        event_count INTEGER DEFAULT 0,
        outcome VARCHAR(32),
        policy_version VARCHAR(32),
        source_hash VARCHAR(64),
        created_by VARCHAR(128) DEFAULT 'daos',
        provenance JSONB
    );

    -- Semantic table (multi-verified knowledge) | 语义表（多源验证知识）
    CREATE TABLE IF NOT EXISTS semantic (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        knowledge TEXT NOT NULL,
        embedding VECTOR(768),            -- 768-dim embedding | 768 维向量
        category VARCHAR(64),
        last_verified_at TIMESTAMPTZ,
        support_count INTEGER DEFAULT 1,
        reject_count INTEGER DEFAULT 0,
        confidence_floor FLOAT DEFAULT 0.6,
        policy_version VARCHAR(32),
        source_hash VARCHAR(64),
        created_by VARCHAR(128) DEFAULT 'daos',
        provenance JSONB
    );

    -- Trust registry (multi-dimensional) | 信任注册表（多维度）
    CREATE TABLE IF NOT EXISTS trust_registry (
        node_id VARCHAR(64) PRIMARY KEY,
        reliability FLOAT DEFAULT 0.5,          -- Historical reliability | 历史可靠性
        reversibility FLOAT DEFAULT 0.5,        -- Reversibility score | 可逆性评分
        blast_radius FLOAT DEFAULT 0.5,         -- Damage scope | 破坏范围
        stability FLOAT DEFAULT 0.5,            -- Behavioral stability | 行为稳定性
        hallucination_risk FLOAT DEFAULT 0.5,   -- LLM hallucination risk / LLM 幻觉风险
        mean_time_to_recover_hours FLOAT DEFAULT 24,  -- Average recovery time | 平均恢复时间（小时）
        last_updated TIMESTAMPTZ DEFAULT NOW(),
        updated_by VARCHAR(128) DEFAULT 'daos'
    );

    -- Audit log table (structured) | 审计日志表（结构化）
    CREATE TABLE IF NOT EXISTS audit_log (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        intent_id VARCHAR(64) NOT NULL,     -- Intent id / Intent ID
        timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        actor VARCHAR(128) NOT NULL,        -- Who acted | 操作者
        action VARCHAR(64) NOT NULL,        -- What action | 操作类型
        outcome VARCHAR(32) NOT NULL,       -- pass/fail/rollback | 结果
        rollback_used BOOLEAN DEFAULT FALSE,
        policy_results JSONB,               -- OPA check results / OPA 检查结果
        prev_hash VARCHAR(64),              -- Chain hash | 链式哈希
        details JSONB
    );

    -- Indexes | 索引
    CREATE INDEX IF NOT EXISTS idx_evidence_timestamp ON evidence(timestamp DESC);
    CREATE INDEX IF NOT EXISTS idx_evidence_source ON evidence(source);
    CREATE INDEX IF NOT EXISTS idx_episodic_session ON episodic(session_id);
    CREATE INDEX IF NOT EXISTS idx_semantic_category ON semantic(category);
    CREATE INDEX IF NOT EXISTS idx_audit_intent ON audit_log(intent_id);
    CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp DESC);
    CREATE INDEX IF NOT EXISTS idx_audit_outcome ON audit_log(outcome);
EOSQL

echo "Database initialized successfully. | 数据库初始化成功"
EOF
chmod +x "${SCRIPT_DIR}/init-db.sh"

echo "=== Bootstrap complete | 引导完成 ==="
echo "Next steps | 下一步:"
echo "  1. Edit deploy/.env and set a strong PG_PASSWORD | 编辑 deploy/.env 设置强密码"
echo "  2. cd deploy && docker compose up -d"
echo "  3. Verify: docker compose ps | 验证：docker compose ps"
