package daos.limiter

import future.keywords.if

# Rate limiter: prevent action storms
default allow = true

deny if {
    rate_exceeded(input.actor, input.action_type)
}

deny if {
    target_quarantined(input.target_node)
}

deny if {
    global_rate_exceeded()
}

rate_exceeded(actor, action_type) if {
    recent := data.runtime.actor_actions[actor][action_type]
    count(recent) >= max_rate(action_type)
    some i
    time.now_ns() - recent[i] < rate_window_ns(action_type)
}

target_quarantined(node) if {
    data.runtime.quarantine[node]
}

global_rate_exceeded if {
    all_actions := [a | a = data.runtime.actor_actions[_][_][_]]
    recent := [t | some t in all_actions; time.now_ns() - t < 600000000000]
    count(recent) >= data.baseline.change_window.default_max_concurrent_changes * 5
}

max_rate(action_type) = 5 if { action_type == "observe" }
max_rate(action_type) = 2 if { action_type == "execute" }
max_rate(action_type) = 1 if { action_type == "modify_baseline" }

rate_window_ns(action_type) = 60000000000 if {   # 60s
    action_type == "observe"
}
rate_window_ns(action_type) = 300000000000 if {  # 5min
    action_type == "execute"
}
rate_window_ns(action_type) = 86400000000000 if { # 24h
    action_type == "modify_baseline"
}
