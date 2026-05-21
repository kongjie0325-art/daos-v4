package daos.execution  # Execution safety policy | 执行安全策略

import future.keywords.if
import future.keywords.in

# Execution policy: gate every action through pre-flight checks | 执行策略：每个操作必须通过预检
default deny = true

# Allow execution only if ALL checks pass | 仅当所有检查通过时才允许执行
allow if {
    not deny
}

# Deny: intent must have rollback steps | 拒绝：Intent 必须有回滚步骤
deny if {
    not has_rollback(input)
}

# Deny: high-risk changes must pass simulation first | 拒绝：高风险变更必须通过模拟
deny if {
    risk_level(input) == "high"
    not simulation_passed(input)
}

# Deny: critical-risk changes are auto-denied (human only) | 拒绝：严重风险变更自动拒绝（仅限人工）
deny if {
    risk_level(input) == "critical"
}

# Deny: trust score below threshold | 拒绝：信任分数低于阈值
deny if {
    trust_score_below_threshold(input.target_node)
}

# Deny: invalid network zone | 拒绝：无效的网络分区
deny if {
    not valid_network_zone(input.target_network)
}

# Every intent must carry rollback steps | 每个 Intent 必须有回滚步骤
has_rollback(intent) if {
    count(intent.rollback_steps) > 0
}

# Get risk level from intent | 获取 Intent 的风险等级
risk_level(intent) = level if {
    level := intent.risk_level
}

# Check if simulation passed | 检查模拟是否通过
simulation_passed(intent) if {
    data.simulation.results[intent.id] == "pass"
}

# Check if node trust score is below minimum | 检查节点信任分数是否低于最低阈值
trust_score_below_threshold(node) if {
    node.trust_score < data.baseline.nodes.min_trust_for_execution
}

# Check if target network CIDR is in a valid zone | 检查目标网络 CIDR 是否在有效分区内
valid_network_zone(network_cidr) if {
    zone := data.baseline.network_zones[_]
    net.cidr_contains(zone.cidr[_], network_cidr)
}
