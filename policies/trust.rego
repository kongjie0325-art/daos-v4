package daos.trust  # Multi-dimensional trust evaluation | 多维信任评估

import future.keywords.if

# Default deny | 默认拒绝
default allow = false

# Allow if overall trust >= 0.7, reliability >= 0.5, hallucination_risk <= 0.3
# 当整体信任>=0.7、可靠性>=0.5、幻觉风险<=0.3 时允许
allow if {
    eval := trust_evaluation(input.target_node)
    eval.overall >= 0.7
    eval.reliability >= 0.5
    eval.hallucination_risk <= 0.3
}

# Compute multi-dimensional trust score | 计算多维信任分数
trust_evaluation(node) = eval if {
    trust := node.trust_matrix
    eval := {
        "overall": (trust.reliability * 0.25) +
                    (trust.reversibility * 0.20) +
                    ((1 - trust.blast_radius) * 0.20) +
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

# Default trust for nodes without explicit matrix | 没有显式矩阵的节点的默认信任值
default_trust = {
    "reliability": 0.5,
    "reversibility": 0.5,
    "blast_radius": 0.5,
    "stability": 0.5,
    "hallucination_risk": 0.5,
    "mean_time_to_recover": 24
}
