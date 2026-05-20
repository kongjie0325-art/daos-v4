# DAOS v4 — Distributed Autonomous Operating System / 分布式自治操作系统

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**DAOS v4** is a declarative, GitOps-driven infrastructure control plane with seven separated layers. / DAOS v4 是一个声明式、GitOps 驱动的分布式自治基础设施控制平面，采用七层分离架构。

---

## Design Philosophy / 设计哲学

**Static baseline = production source of truth. Dynamic suggestion = calibration layer (never directly effective).** / **静态基线 = 生产真源；动态建议 = 校准层（永不直接生效）**

- **Static baseline** — auditable, rollbackable, signable. Only lives in Git. / **静态基线** — 可审计、可回滚、可签名。仅存在于 Git 仓库中。
- **Dynamic suggestion** — observed by agents silently, outputs period distribution, avg metrics, P95/P99 deviation, anomaly clusters, suggested threshold corrections. / **动态建议层** — 由观察代理静默生成，只输出时段分布、平均指标、P95/P99 偏差、异常簇和建议阈值修正。
- **Dynamic suggestion can NEVER override the production baseline directly.** / **动态建议永不直接覆盖生产基线。**

---

## Seven-Layer Architecture / 七层架构

```
┌─────────────────────────────────────────────────────────────┐
│  1. Source of Truth Plane / 真源层                          │
│     GitOps Baseline + Signed Policy Bundles                 │
│     GitOps 基线 + 签名策略包                                │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Observation Plane / 观测层                              │
│     Metrics / Logs / Traces / Snapshots / Heartbeats        │
│     指标 / 日志 / 链路追踪 / 快照 / 心跳                     │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Control Plane / 控制层                                  │
│     Drift Detector → DSE → LLM Co-processor → Intent Compiler│
│     漂移检测 → DSE → LLM 协处理器 → Intent 编译            │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Safety Plane / 安全层                                   │
│     OPA + Trust Matrix + Rate Limiter + Quarantine         │
│     OPA + 信任矩阵 + 速率限制 + 隔离区                       │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Simulation Plane / 模拟层                               │
│     Digital Twin / Network Namespace / Pre-flight Validation│
│     数字孪生 / 网络命名空间 / 预飞验证                        │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Execution Plane / 执行层                                │
│     Saga Coordinator + Sandbox Runner + Rollback Hooks      │
│     Saga 协调器 + 沙箱执行器 + 回滚钩子                      │
└─────────────────────────────────────────────────────────┬───┘
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Audit & Learning Plane / 审计与学习层                    │
│     Flight Recorder + Evidence Store + Semantic Store       │
│     黑匣子 + 证据存储 + 语义存储                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Control Loop / 控制循环

```
Observe → Normalize → Drift Detect → Propose → Compile Intent
→ Policy Check → Simulate → Execute → Verify → Record → Sleep
观测 → 标准化 → 漂移检测 → 提议 → 编译 Intent
→ 策略检查 → 模拟 → 执行 → 验证 → 记录 → 休眠
```

| Step / 步骤 | Role / 职责 |
|---|---|
| Observe / 观测 | Collect only, no reasoning / 只收集，不推理 |
| Normalize / 标准化 | Dirty logs → structured events / 脏日志 → 结构化事件 |
| Drift Detect / 漂移检测 | Compute deviation from baseline / 计算与基线的偏差 |
| Propose / 提议 | LLM suggests only (never decides) / LLM 只提建议（不做决策）|
| Compile Intent / 编译 Intent | Strict JSON with pre_snapshot + rollback / 严格 JSON，含预快照 + 回滚 |
| Policy Check / 策略检查 | OPA hard deny / OPA 硬拦截 |
| Simulate / 模拟 | Digital twin pre-flight / 数字孪生预演 |
| Execute / 执行 | Sandbox (Docker low-risk, Firecracker high-risk) / 沙箱执行（Docker 低风险，MicroVM 高风险）|
| Verify / 验证 | Hard-metric acceptance / 硬指标验收 |
| Record / 记录 | Structured JSONL + hash chain / 结构化 JSONL + 哈希链 |

---

## Memory Architecture / 记忆架构

| Layer / 层级 | Role / 角色 | Write Rule / 写入规则 |
|---|---|---|
| Evidence / 证据 | Raw observations / 原始证据 | Append-only, no rewrite / 只追加，不改写 |
| Episodic / 事件 | Event summaries / 事件摘要 | Low-frequency update / 低频更新 |
| Semantic / 语义 | Stable knowledge / 稳定知识 | Multi-verified (≥3 confirmations) / 多次验证（≥3 次确认）|
| Suggested Baseline / 动态建议 | Dynamic calibration / 校准层 | Never directly effective / 永不直接生效 |

**Key optimization:** Evidence is append-only (no rewrite). Semantic knowledge requires ≥3 verifications before consolidation. Suggested baseline is observed silently and never overrides production. / **关键优化：** 证据只追加不改写，语义知识需≥3次验证才能固化，动态建议静默观察永不覆盖生产。

---

## Execution Runtimes / 执行运行时

| Risk Level / 风险等级 | Task / 任务 | Runtime / 运行时 |
|---|---|---|
| Low / 低风险 | Observe, Diagnose, Read, Simulate / 观测、诊断、读取、模拟 | Docker (read-only) / Docker（只读）|
| High / 高风险 | nftables, Route, DNS, Gateway changes / nftables、路由、DNS、网关变更 | Firecracker MicroVM |

Default: Docker. Critical changes only → MicroVM. Host never directly exposed to LLM. / 默认 Docker。关键变更才进 MicroVM。生产宿主机不直接暴露给 LLM。

**Every executable tool must include:** / **每个可执行工具必须附带：**
```
pre_snapshot → execute → verify → rollback → rollback_verify
```

If any step is missing, the tool cannot enter the auto-execution pool. / 如果缺一个步骤，工具就不能进入自动执行池。

---

## Development Priority / 开发优先级

| Priority / 优先级 | Project / 项目 |
|---|---|
| P0 | GitOps baseline / GitOps 基线 |
| P0 | OPA policy bundle / OPA 策略包 |
| P0 | PostgreSQL + pgvector |
| P0 | NATS JetStream |
| P0 | Audit recorder / 审计记录器 |
| P1 | Drift detector / 漂移检测器 |
| P1 | Intent compiler / Intent 编译器 |
| P1 | Simulator / 模拟器 |
| P1 | Sandbox executor / 沙箱执行器 |
| P2 | Trust registry / 信任注册表 |
| P2 | Replay engine / 回放引擎 |
| P3 | Automated baseline suggestion / 自动基线建议 |

---

## Recommended Tech Stack / 推荐技术栈

| Layer / 层级 | Component / 组件 | Purpose / 用途 |
|---|---|---|
| Message Bus / 消息总线 | NATS JetStream | Event stream, task dispatch, state notification / 事件流、任务分发、状态通知 |
| Primary DB / 主数据库 | PostgreSQL + pgvector | Evidence, memory, state, baseline / 证据、记忆、状态、基线 |
| Hot Cache / 热缓存 | Redis | TTL working memory, distributed locks / TTL 工作记忆、分布式锁 |
| Policy Engine / 策略引擎 | OPA | Safety review, hard deny / 安全审查、硬拒绝 |
| Execution Isolation / 执行隔离 | Docker + Firecracker | Sandbox & high-risk execution / 沙箱与高风险执行 |
| Observability / 观测 | Prometheus + Blackbox Exporter | Metrics & probing / 指标与探测 |
| Audit / 审计 | Structured JSONL + hash chain | Black box replay / 黑匣子回放 |

**Not recommended for MVP:** Neo4j, Kafka, multi-vector stores, complex multi-model routers, auto-training models. / **MVP 阶段不建议上：** Neo4j、Kafka、多套向量库、复杂多模型路由器、自动训练主模型。

---

## Repository Structure / 仓库结构

```
daos-v4/
├── baseline/              # GitOps Source of Truth / GitOps 真源
│   ├── nodes.yaml         # Node inventory + network zones / 节点清单 + 网络分区
│   ├── thresholds.yaml    # Latency/throughput/packet loss thresholds / 时延/吞吐量/丢包阈值
│   └── change-window.yaml # Allowed change windows + blackout periods / 允许变更窗口 + 封禁区
├── policies/              # OPA Rego policy bundles / OPA 策略包
│   ├── network.rego       # Network change gate / 网络变更门禁
│   ├── execution.rego     # Execution safety gate / 执行安全门禁
│   ├── trust.rego         # Multi-dimensional trust evaluation / 多维信任评估
│   └── limiter.rego       # Rate limiter / 速率限制
├── schemas/
│   └── intent.schema.json # Strict intent JSON schema / 严格 Intent JSON Schema
├── services/              # Service configs / 服务配置
│   ├── drift-detector/    # Drift detection / 漂移检测器
│   ├── intent-compiler/   # Intent compiler / Intent 编译器
│   ├── policy-gateway/    # Policy gateway / 策略网关
│   ├── simulator/         # Simulator / 模拟器
│   ├── executor/          # Sandbox executor / 沙箱执行器
│   ├── verifier/          # Verifier / 验证器
│   ├── audit-recorder/    # Audit recorder / 审计记录器
│   └── replay-engine/     # Replay engine / 回放引擎
├── memory/                # Memory layer / 记忆层
│   ├── evidence/          # Raw evidence, append-only / 原始证据，只追加
│   ├── episodic/          # Event summaries / 事件摘要
│   ├── semantic/          # Stable knowledge / 稳定知识
│   └── trust-registry.yaml # Trust matrix / 信任矩阵
├── rollback/              # Rollback templates / 回滚模板
│   ├── nftables/          # NFTables restore / NFTables 规则恢复
│   ├── route/             # Route table restore / 路由表恢复
│   └── dns/               # DNS zone restore / DNS 区域恢复
└── deploy/                # Deployment artifacts / 部署制品
    ├── docker-compose.yml # Container orchestration / 容器编排
    ├── env.example        # Environment variables / 环境变量模板
    ├── prometheus.yml     # Monitoring config / 监控配置
    ├── bootstrap.sh       # Bootstrap script / 引导脚本
    ├── bootstrap-daos.sh  # DAOS deploy script / DAOS 部署脚本
    └── TASKBOOK.md        # Hermes AI task book / Hermes 任务书
```

---

## Deployment / 部署

### Prerequisites / 前置条件

- Docker + Docker Compose
- Git
- VPS with public IP (or local machine for development) / 公网 VPS（或本地开发机）

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
