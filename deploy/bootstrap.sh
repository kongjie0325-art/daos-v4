#!/bin/bash
# DAOS v4 bootstrap.sh — Initial environment setup
# Run once on the control VPS to prepare for docker-compose up

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== DAOS v4 Bootstrap ==="

# 1. Check prerequisites
echo "[CHECK] docker..."
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }

echo "[CHECK] docker compose..."
docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose not found"; exit 1; }

echo "[CHECK] git..."
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }

# 2. Create required directories
echo "[SETUP] Creating data directories..."
mkdir -p "${SCRIPT_DIR}/../data/audit"
mkdir -p "${SCRIPT_DIR}/../data/prometheus"

# 3. Copy env if not exists
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
  echo "[SETUP] Creating .env from env.example..."
  cp "${SCRIPT_DIR}/env.example" "${SCRIPT_DIR}/.env"
  echo "!! IMPORTANT: Edit ${SCRIPT_DIR}/.env and set a strong PG_PASSWORD !!"
fi

# 4. Pull images
echo "[PULL] Pulling Docker images..."
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" pull

# 5. Initialize database
echo "[DB] Creating PostgreSQL init script..."
cat > "${SCRIPT_DIR}/init-db.sh" << 'EOF'
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS vector;
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    -- Evidence table (append-only)
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

    -- Episodic table (low-freq summaries)
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

    -- Semantic table (multi-verified knowledge)
    CREATE TABLE IF NOT EXISTS semantic (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        knowledge TEXT NOT NULL,
        embedding VECTOR(768),
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

    -- Trust registry (multi-dimensional)
    CREATE TABLE IF NOT EXISTS trust_registry (
        node_id VARCHAR(64) PRIMARY KEY,
        reliability FLOAT DEFAULT 0.5,
        reversibility FLOAT DEFAULT 0.5,
        blast_radius FLOAT DEFAULT 0.5,
        stability FLOAT DEFAULT 0.5,
        hallucination_risk FLOAT DEFAULT 0.5,
        mean_time_to_recover_hours FLOAT DEFAULT 24,
        last_updated TIMESTAMPTZ DEFAULT NOW(),
        updated_by VARCHAR(128) DEFAULT 'daos'
    );

    -- Audit log table (structured)
    CREATE TABLE IF NOT EXISTS audit_log (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        intent_id VARCHAR(64) NOT NULL,
        timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        actor VARCHAR(128) NOT NULL,
        action VARCHAR(64) NOT NULL,
        outcome VARCHAR(32) NOT NULL,
        rollback_used BOOLEAN DEFAULT FALSE,
        policy_results JSONB,
        prev_hash VARCHAR(64),
        details JSONB
    );

    -- Indexes
    CREATE INDEX IF NOT EXISTS idx_evidence_timestamp ON evidence(timestamp DESC);
    CREATE INDEX IF NOT EXISTS idx_evidence_source ON evidence(source);
    CREATE INDEX IF NOT EXISTS idx_episodic_session ON episodic(session_id);
    CREATE INDEX IF NOT EXISTS idx_semantic_category ON semantic(category);
    CREATE INDEX IF NOT EXISTS idx_audit_intent ON audit_log(intent_id);
    CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp DESC);
    CREATE INDEX IF NOT EXISTS idx_audit_outcome ON audit_log(outcome);
EOSQL

echo "Database initialized successfully."
EOF
chmod +x "${SCRIPT_DIR}/init-db.sh"

echo "=== Bootstrap complete ==="
echo "Next steps:"
echo "  1. Edit deploy/.env and set a strong PG_PASSWORD"
echo "  2. cd deploy && docker compose up -d"
echo "  3. Verify: docker compose ps"
