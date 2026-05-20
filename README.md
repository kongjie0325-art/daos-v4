# DAOS v4 — Distributed Autonomous Operating System / 分布式自治操作系统

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **English** | [中文](#chinese)

---

## <a id="english"></a> English

**DAOS v4** is a declarative, GitOps-driven infrastructure control plane with seven separated layers:

```
Source of Truth → Observation → Control → Safety → Simulation → Execution → Audit
```

### Design Philosophy

**Static baseline = production source of truth. Dynamic suggestion = calibration layer (never directly effective).**

- **Static baseline** — auditable, rollbackable, signable. Only lives in Git.
- **Dynamic suggestion** — observed by agents silently, outputs period distribution, avg metrics, P95/P99 deviation, anomaly clusters, suggested threshold corrections.
- **Dynamic suggestion can NEVER override the production baseline directly.**

### Seven-Layer Architecture

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

| Step | Role |
|---|---|
| Observe | Collect only, no reasoning |
| Normalize | Dirty logs → structured events |
| Drift Detect | Compute deviation from baseline |
| Propose | LLM suggests only (never decides) |
| Compile Intent | Strict JSON with pre_snapshot + rollback |
| Policy Check | OPA hard deny |
| Simulate | Digital twin pre-flight |
| Execute | Sandbox (Docker low-risk, Firecracker high-risk) |
| Verify | Hard-metric acceptance |
| Record | Structured JSONL + hash chain |

### Memory Architecture

| Layer | Role | Write Rule |
|---|---|---|
| Evidence | Raw observations | Append-only, no rewrite |
| Episodic | Event summaries | Low-frequency update |
| Semantic | Stable knowledge | Multi-verified (≥3 confirmations) |
| Suggested Baseline | Dynamic calibration | Never directly effective |

### Execution Runtimes

| Risk Level | Task | Runtime |
|---|---|---|
| Low | Observe, Diagnose, Read, Simulate | Docker (read-only) |
| High | nftables, Route, DNS, Gateway changes | Firecracker MicroVM |

Default: Docker. Critical changes only → MicroVM. Host never directly exposed to LLM.

### Development Priority

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

## <a id="chinese"></a> 中文

**DAOS v4** 是一个声明式、GitOps 驱动的基础设施控制平面，采用七层分离架构：

```
真源 → 观察 → 控制 → 安全 → 模拟 → 执行 → 审计
```

### 设计哲学

**静态基线 = 生产真源；动态建议 = 校准层（永不直接生效）**

- **静态基线（Git）** — 可审计、可回滚、可签名。仅存在于 Git 仓库中。
- **动态建议层** — 由观察代理静默生成，只输出时段分布、平均指标、P95/P99 偏差、异常簇和建议阈值修正。
- **动态建议永不直接覆盖生产基线。**

### 七层架构

```
┌─────────────────────────────────────────────────────────────┐
│  1. 真源层 (Source of Truth)                                │
│     GitOps 基线 + 签名策略包                                │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. 观测层 (Observation)                                    │
│     指标 / 日志 / 链路追踪 / 快照 / 心跳                     │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  3. 控制层 (Control)                                        │
│     漂移检测 → DSE → LLM 协处理器 → Intent 编译            │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  4. 安全层 (Safety)                                         │
│     OPA + 信任矩阵 + 速率限制 + 隔离区                       │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  5. 模拟层 (Simulation)                                     │
│     数字孪生 / 网络命名空间 / 预飞验证                        │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  6. 执行层 (Execution)                                      │
│     Saga 协调器 + 沙箱执行器 + 回滚钩子                      │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  7. 审计与学习层 (Audit & Learning)                          │
│     黑匣子 + 证据存储 + 语义存储                             │
└─────────────────────────────────────────────────────────────┘
```

### 控制循环

```
观测 → 标准化 → 漂移检测 → 提议 → 编译 Intent
→ 策略检查 → 模拟 → 执行 → 验证 → 记录 → 休眠
```

| 步骤 | 职责 |
|---|---|
| Observe | 只收集，不推理 |
| Normalize | 脏日志 → 结构化事件 |
| Drift Detect | 计算与基线的偏差 |
| Propose | LLM 只提建议（不做决策） |
| Compile Intent | 严格 JSON，含 pre_snapshot + rollback |
| Policy Check | OPA 硬拦截 |
| Simulate | 数字孪生预演 |
| Execute | 沙箱执行（Docker 低风险，Firecracker 高风险）|
| Verify | 硬指标验收 |
| Record | 结构化 JSONL + 哈希链 |

### 记忆架构

| 层级 | 角色 | 写入规则 |
|---|---|---|
| Evidence | 原始证据 | 只追加，不改写 |
| Episodic | 事件摘要 | 低频更新 |
| Semantic | 稳定知识 | 多次验证（≥3 次确认）|
| Suggested Baseline | 动态建议 | 永不直接生效 |

### 执行运行时

| 风险等级 | 任务 | 运行时 |
|---|---|---|
| 低风险 | 观测、诊断、读取、模拟 | Docker（只读） |
| 高风险 | nftables、路由、DNS、网关变更 | Firecracker MicroVM |

默认 Docker。关键变更才进 MicroVM。生产宿主机不直接暴露给 LLM。

### 开发优先级

| 优先级 | 项目 |
|---|---|
| P0 | GitOps 基线 |
| P0 | OPA 策略包 |
| P0 | PostgreSQL + pgvector |
| P0 | NATS JetStream |
| P0 | 审计记录器 |
| P1 | 漂移检测器 |
| P1 | Intent 编译器 |
| P1 | 模拟器 |
| P1 | 沙箱执行器 |
| P2 | 信任注册表 |
| P2 | 回放引擎 |
| P3 | 自动基线建议 |

---

## Repository Structure / 仓库结构

```
daos-v4/
├── baseline/            # GitOps Source of Truth / GitOps 真源
│   ├── nodes.yaml       # Node inventory + network zones
│   ├── thresholds.yaml  # Latency/throughput/packet loss thresholds
│   └── change-window.yaml # Allowed change windows + blackout periods
├── policies/            # OPA Rego policy bundles / OPA 策略包
│   ├── network.rego     # Network change gate
│   ├── execution.rego   # Execution safety gate
│   ├── trust.rego       # Multi-dimensional trust evaluation
│   └── limiter.rego     # Rate limiter
├── schemas/
│   └── intent.schema.json # Strict intent JSON schema
├── services/            # Service configs / 服务配置
│   ├── drift-detector/  # 漂移检测
│   ├── intent-compiler/ # Intent 编译
│   ├── policy-gateway/  # 策略网关
│   ├── simulator/       # 模拟器
│   ├── executor/        # 执行器
│   ├── verifier/        # 验证器
│   ├── audit-recorder/  # 审计记录
│   └── replay-engine/   # 回放引擎
├── memory/              # Memory layer configs / 记忆层配置
│   ├── evidence/        # Raw, append-only / 原始证据，只追加
│   ├── episodic/        # Low-freq event summaries / 低频事件摘要
│   ├── semantic/        # Multi-verified stable knowledge / 多次验证的稳定知识
│   └── trust-registry.yaml # Multi-dimensional trust matrix
├── rollback/            # Pre-built rollback templates / 预置回滚模板
│   ├── nftables/        # NFTables ruleset restore
│   ├── route/           # Route table restore
│   └── dns/             # DNS zone restoration
└── deploy/              # Deployment artifacts / 部署制品
    ├── docker-compose.yml
    ├── env.example
    ├── prometheus.yml
    └── bootstrap.sh
```

---

## Deployment / 部署

### Prerequisites / 前置条件

- Docker + Docker Compose
- Git
- VPS with public IP (or local machine for development)

### Quick Start / 快速启动

```bash
cd deploy
cp env.example .env
# Edit .env — set a strong PG_PASSWORD / 设置强密码
./bootstrap.sh
docker compose up -d
```

### Health Check / 健康检查

```bash
docker compose ps
curl http://localhost:8181/v1/health  # OPA
curl http://localhost:8222/healthz     # NATS
```

---

## Verification Checklist / 验收清单

- [ ] GitOps baseline readable from Git / GitOps 基线可从 Git 读取
- [ ] Telemetry readable from Prometheus / 遥测可从 Prometheus 读取
- [ ] Intent JSON compiles + passes schema validation / Intent JSON 编译通过
- [ ] OPA policy check passes / OPA 策略检查通过
- [ ] Simulation sandbox runs without side effects / 模拟沙箱无副作用
- [ ] Auto-rollback on verification failure / 验证失败自动回滚
- [ ] Replay-able audit trail / 可回放的审计轨迹
- [ ] Clear separation: production / simulation / evidence / semantic data / 生产、模拟、证据、语义数据严格分离

---

## License / 许可证

MIT
