package daos.limiter  # Rate limiter: prevent action storms | 速率限制：防止操作风暴

import future.keywords.if
import future.keywords.in

# Rate limiter: prevent action storms | 速率限制：防止操作风暴
default allow = true

# Deny: actor exceeded per-action rate | 拒绝：执行者超过单操作速率
deny if {
    rate_exceeded(input.actor, input.action_type)
}

# Deny: target node is quarantined | 拒绝：目标节点被隔离
deny if {
    target_quarantined(input.target_node)
}

# Deny: global rate exceeded | 拒绝：全局速率超限
deny if {
    global_rate_exceeded
}

# Check if an actor exceeded the max rate for a specific action type
# 检查执行者是否超过特定操作类型的最大速率
rate_exceeded(actor, action_type) if {
    recent := object.get(data.runtime.actor_actions, [actor, action_type], [])
    count(recent) >= max_rate(action_type)
    some i
    time.now_ns() - recent[i] < rate_window_ns(action_type)
}

# Check if target node is quarantined | 检查目标节点是否被隔离
target_quarantined(node) if {
    object.get(data.runtime.quarantine, [node], false) == true
}

# Check if global rate is exceeded across all actors | 检查全局速率是否超限
global_rate_exceeded if {
    data.baseline.change_window.default_max_concurrent_changes * 5 <=
    count([ts | some ts in data.runtime.actor_actions[_][_][_]; time.now_ns() - ts < 600000000000])
}

# Max rate per action type | 各操作类型的最大速率
max_rate(action_type) = 5  if { action_type == "observe" }
max_rate(action_type) = 2  if { action_type == "execute" }
max_rate(action_type) = 1  if { action_type == "modify_baseline" }

# Rate window (nanoseconds) | 速率窗口（纳秒）
rate_window_ns(action_type) = 60000000000  if {   # 60s
    action_type == "observe"
}
rate_window_ns(action_type) = 300000000000  if {  # 5min
    action_type == "execute"
}
rate_window_ns(action_type) = 86400000000000  if { # 24h
    action_type == "modify_baseline"
}
