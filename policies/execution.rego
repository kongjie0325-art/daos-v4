package daos.execution

import future.keywords.if
import future.keywords.in

# Execution policy: gate every action through pre-flight checks
default deny = true

# Allow execution only if ALL checks pass
allow if {
    not deny
}

deny if {
    not has_rollback(intent)
}

deny if {
    risk_level(intent) == "high"
    not simulation_passed(intent)
}

deny if {
    risk_level(intent) == "critical"
}

deny if {
    trust_score_below_threshold(intent.target_node)
}

deny if {
    not valid_network_zone(intent.target_network)
}

# Every intent must carry rollback steps
has_rollback(intent) {
    count(intent.rollback_steps) > 0
}

risk_level(intent) = level if {
    level := intent.risk_level
}

simulation_passed(intent) {
    data.simulation.results[intent.id] == "pass"
}

trust_score_below_threshold(node) {
    node.trust_score < data.baseline.nodes.min_trust_for_execution
}

valid_network_zone(network_cidr) {
    zone := data.baseline.nodes.network_zones[_]
    net.cidr_contains(zone.cidr[_], network_cidr)
}
