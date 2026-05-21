package daos.network  # Network policy package | 网络策略包

import future.keywords.if
import future.keywords.in

# Default deny | 默认拒绝
default allow = false

# Allow action on target node if all checks pass
# 如果所有检查通过，则允许对目标节点执行操作
allow if {
    action_in_allowed_set(input.action, input.target_node)
    within_change_window(time.now_ns())
    not in_blackout_period(time.now_ns())
    not exceeds_concurrent_limit
}

# Check if action is in the node's allowed set | 检查操作是否在节点的允许集中
action_in_allowed_set(action, node) if {
    action in node.allowed_actions
}

# Check if current time falls within a change window | 检查当前时间是否在变更窗口内
within_change_window(now_ns) if {
    window := data.baseline.change_window.windows[_]
    day_name := time.weekday(now_ns)
    lower(day_name) in window.days
    time_in_range(window.start_utc, window.end_utc, now_ns)
}

# Check if current time falls in a blackout period | 检查当前时间是否在封禁期内
in_blackout_period(now_ns) if {
    bp := data.baseline.change_window.blackout_periods[_]
    now_ns >= time.parse_rfc3339_ns(bp.start)
    now_ns <= time.parse_rfc3339_ns(bp.end)
}

# Check if concurrent change limit exceeded | 检查是否超过并发变更限制
exceeds_concurrent_limit if {
    count(data.runtime.active_changes) >= data.baseline.change_window.default_max_concurrent_changes
}

# Helper: check if now_ns is within [start_hour:min, end_hour:min] on the same day
# 辅助函数：检查当前时间是否在同一天 [start, end] 时间段内
time_in_range(start, end, now_ns) if {
    clk := time.clock(now_ns)
    now_date := sprintf("%d-%02d-%02d", [clk[0], clk[1], clk[2]])
    start_full := sprintf("%sT%s", [now_date, start])
    end_full := sprintf("%sT%s", [now_date, end])
    start_ns := time.parse_rfc3339_ns(sprintf("%s:00Z", [start_full]))
    end_ns := time.parse_rfc3339_ns(sprintf("%s:00Z", [end_full]))
    now_ns >= start_ns
    now_ns <= end_ns
}
