# DAOS v4 — Distributed Autonomous Operating System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**DAOS v4** is a declarative, GitOps-driven infrastructure control plane with seven
separated layers: Source of Truth → Observation → Control → Safety → Simulation →
Execution → Audit.

The core design principle: **静态基线 = 生产真源；动态建议 = 校准层（永不直接生效）**

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  1. Source of Truth Plane                                   │
│     GitOps Baseline + Signed Policy Bundles                │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Observation Plane                                       │
│     Metrics / Logs / Traces / Snapshots / Heartbeats        │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Control Plane                                           │
│     Drift Detector → DSE → LLM Co-processor → Intent Compiler│
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Safety Plane                                            │
│     OPA + Trust Matrix + Rate Limiter + Quarantine         │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Simulation Plane                                        │
│     Digital Twin / Network Namespace / Pre-flight Validation│
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Execution Plane                                         │
│     Saga Coordinator + Sandbox Runner + Rollback Hooks      │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Audit & Learning Plane                                  │
│     Flight Recorder + Evidence Store + Semantic Store       │
└─────────────────────────────────────────────────────────────┘
```

### Control Loop

```
Observe → Normalize → Drift Detect → Propose → Compile Intent
→ Policy Check → Simulate → Execute → Verify → Record → Sleep
```

- **Observe**: collect only, no reasoning
- **Normalize**: dirty logs → structured events
- **Drift Detect**: compute deviation from baseline
- **Propose**: LLM suggests only (never decides)
- **Compile Intent**: strict JSON with pre_snapshot + rollback
- **Policy Check**: OPA hard deny
- **Simulate**: digital twin pre-flight
- **Execute**: sandbox (Docker low-risk, Firecracker high-risk)
- **Verify**: hard-metric acceptance
- **Record**: structured JSONL + hash chain

---

## Repository Structure

```
daos-v4/
├── baseline/            # GitOps Source of Truth (signed, versioned)
│   ├── nodes.yaml       # Node inventory + network zones
│   ├── thresholds.yaml  # Latency/throughput/packet loss thresholds
│   └── change-window.yaml # Allowed change windows + blackout periods
├── policies/            # OPA Rego policy bundles
│   ├── network.rego     # Network change gate
│   ├── execution.rego   # Execution safety gate
│   ├── trust.rego       # Multi-dimensional trust evaluation
│   └── limiter.rego     # Rate limiter
├── schemas/
│   └── intent.schema.json # Strict intent JSON schema
├── services/            # Service configs (one dir per service)
│   ├── drift-detector/
│   ├── intent-compiler/
│   ├── policy-gateway/
│   ├── simulator/
│   ├── executor/
│   ├── verifier/
│   ├── audit-recorder/
│   └── replay-engine/
├── memory/              # Memory layer configs
│   ├── evidence/        # Raw, append-only
│   ├── episodic/        # Low-freq event summaries
│   ├── semantic/        # Multi-verified stable knowledge
│   └── trust-registry.yaml # Multi-dimensional trust matrix
├── rollback/            # Pre-built rollback templates
│   ├── nftables/        # NFTables ruleset restore
│   ├── route/           # Route table restore
│   └── dns/             # DNS zone restoration
└── deploy/              # Deployment artifacts
    ├── docker-compose.yml
    ├── env.example
    ├── prometheus.yml
    └── bootstrap.sh
```

---

## Memory Architecture

| Layer | Role | Write Rule |
|---|---|---|
| Evidence | Raw observations | Append-only, no rewrite |
| Episodic | Event summaries | Low-frequency update |
| Semantic | Stable knowledge | Multi-verified (≥3 confirmations) |
| Suggested Baseline | Dynamic calibration | Never directly effective |

---

## Execution Runtimes

| Risk Level | Task | Runtime |
|---|---|---|
| Low | Observe, Diagnose, Read, Simulate | Docker (read-only) |
| High | nftables, Route, DNS, Gateway changes | Firecracker MicroVM |

Default: Docker. Critical changes only → MicroVM. Host never directly exposed to LLM.

---

## Deployment

### Prerequisites

- Docker + Docker Compose
- Git
- VPS with public IP (or local machine for development)

### Quick Start

```bash
cd deploy
cp env.example .env
# Edit .env — set a strong PG_PASSWORD
./bootstrap.sh
docker compose up -d
```

### Health Check

```bash
docker compose ps
curl http://localhost:8181/v1/health  # OPA
curl http://localhost:8222/healthz     # NATS
```

---

## Verification Checklist

- [ ] GitOps baseline readable from Git
- [ ] Telemetry readable from Prometheus
- [ ] Intent JSON compiles + passes schema validation
- [ ] OPA policy check passes
- [ ] Simulation sandbox runs without side effects
- [ ] Auto-rollback on verification failure
- [ ] Replay-able audit trail
- [ ] Clear separation: production / simulation / evidence / semantic data

---

## Development Priority

| Priority | Project |
|---|---|
| P0 | GitOps baseline |
| P0 | OPA policy bundle |
| P0 | PostgreSQL + pgvector |
| P0 | NATS JetStream |
| P0 | Audit recorder |
| P1 | Drift detector |
| P1 | Intent compiler |
| P1 | Simulator |
| P1 | Sandbox executor |
| P2 | Trust registry |
| P2 | Replay engine |
| P3 | Automated baseline suggestion |

---

## License

MIT
