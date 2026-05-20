package daos.network  # Network policy package / 网络策略包

import future.keywords.if
import future.keywords.in

# Allow an action on a target node if within change window and permitted
# 如果在变更窗口内且允许，则允许对目标节点执行操作
allow_change(action, node) if {
    action_in_allowed_set(action, node)     # Action permitted for this node / 该节点允许此操作
    within_change_window(time.now_ns())     # Within change window / 在变更窗口内
    not in_blackout_period(time.now_ns())   # Not in blackout / 不在封禁期内
    not exceeds_concurrent_limit()           # Not exceeding concurrent limit / 未超并发限制
}

# Check if action is in the node's allowed set / 检查操作是否在节点的允许集中
action_in_allowed_set(action, node) if {
    action in node.allowed_actions
}

# Check if current time falls within a change window / 检查当前时间是否在变更窗口内
within_change_window(now_ns) if {
    window := data.baseline.change_window.windows[_]  # Get a change window / 获取变更窗口
    day_name := format_date(now_ns, "Monday")          # Get day name / 获取星期几
    lower(day_name) in window.days                      # Check day / 检查日期
    time_in_range(window.start_utc, window.end_utc, now_ns)  # Check time range / 检查时间段
}

# Check if current time falls in a blackout period / 检查当前时间是否在封禁期内
in_blackout_period(now_ns) if {
    bp := data.baseline.change_window.blackout_periods[_]  # Get a blackout period / 获取封禁期
    now_ns >= time.parse_rfc3339_ns(bp.start)               # After start / 起始之后
    now_ns <= time.parse_rfc3339_ns(bp.end)                  # Before end / 结束之前
}

# Check if concurrent change limit exceeded / 检查是否超过并发变更限制
exceeds_concurrent_limit if {
    count(data.runtime.active_changes) >= data.baseline.change_window.default_max_concurrent_changes
}

# Helper: check if now is within a time range on the same day / 辅助函数：检查当前时间是否在同一天的时间段内
time_in_range(start, end, now_ns) {
    now_date := format_date(now_ns, "2006-01-02")          # Today's date / 今天的日期
    start_full := concat("T", [now_date, start])            # Full start time / 完整起始时间
    end_full := concat("T", [now_date, end])                # Full end time / 完整结束时间
    start_ns := time.parse_rfc3339_ns(concat("", [start_full, ":00Z"]))  # Parse start / 解析起始时间
    end_ns := time.parse_rfc3339_ns(concat("", [end_full, ":00Z"]))      # Parse end / 解析结束时间
    now_ns >= start_ns                                       # After start / 在起始之后
    now_ns <= end_ns                                         # Before end / 在结束之前
}
