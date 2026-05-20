package daos.network

import future.keywords.if
import future.keywords.in

# Allow an action on a target node if within change window and permitted
allow_change(action, node) if {
    action_in_allowed_set(action, node)
    within_change_window(time.now_ns())
    not in_blackout_period(time.now_ns())
    not exceeds_concurrent_limit()
}

action_in_allowed_set(action, node) if {
    action in node.allowed_actions
}

within_change_window(now_ns) if {
    window := data.baseline.change_window.windows[_]
    day_name := format_date(now_ns, "Monday")
    lower(day_name) in window.days
    time_in_range(window.start_utc, window.end_utc, now_ns)
}

in_blackout_period(now_ns) if {
    bp := data.baseline.change_window.blackout_periods[_]
    now_ns >= time.parse_rfc3339_ns(bp.start)
    now_ns <= time.parse_rfc3339_ns(bp.end)
}

exceeds_concurrent_limit if {
    count(data.runtime.active_changes) >= data.baseline.change_window.default_max_concurrent_changes
}

time_in_range(start, end, now_ns) {
    now_date := format_date(now_ns, "2006-01-02")
    start_full := concat("T", [now_date, start])
    end_full := concat("T", [now_date, end])
    start_ns := time.parse_rfc3339_ns(concat("", [start_full, ":00Z"]))
    end_ns := time.parse_rfc3339_ns(concat("", [end_full, ":00Z"]))
    now_ns >= start_ns
    now_ns <= end_ns
}
