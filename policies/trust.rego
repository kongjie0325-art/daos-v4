package daos.trust

import future.keywords.if

# Multi-dimensional trust evaluation
# trust_score is a weighted combination, NOT a single flat value

trust_allow(action, node) if {
    eval := trust_evaluation(node)
    eval.overall >= 0.7
    eval.reliability >= 0.5
    eval.hallucination_risk <= 0.3
}

trust_evaluation(node) = eval if {
    trust := node.trust_matrix
    eval := {
        "overall": (trust.reliability * 0.25) +
                    (trust.reversibility * 0.20) +
                    (1 - trust.blast_radius * 0.20) +
                    (trust.stability * 0.20) +
                    ((1 - trust.hallucination_risk) * 0.15),
        "reliability": trust.reliability,
        "reversibility": trust.reversibility,
        "blast_radius": trust.blast_radius,
        "stability": trust.stability,
        "hallucination_risk": trust.hallucination_risk,
        "mean_time_to_recover_hours": trust.mean_time_to_recover
    }
}

# Default trust for nodes without explicit matrix
default_trust = {
    "reliability": 0.5,
    "reversibility": 0.5,
    "blast_radius": 0.5,
    "stability": 0.5,
    "hallucination_risk": 0.5,
    "mean_time_to_recover": 24
}
