package daos.trust  # Multi-dimensional trust evaluation / 多维信任评估

import future.keywords.if

# Multi-dimensional trust evaluation / 多维信任评估
# trust_score is a weighted combination, NOT a single flat value / 信任分数是加权组合，不是单一平面值
# Dimensions: reliability, reversibility, blast_radius, stability, hallucination_risk, MTTR
# 维度：可靠性、可逆性、爆炸半径、稳定性、幻觉风险、平均恢复时间

# Allow if overall trust ≥ 0.7, reliability ≥ 0.5, hallucination_risk ≤ 0.3
# 当整体信任≥0.7、可靠性≥0.5、幻觉风险≤0.3 时允许
trust_allow(action, node) if {
    eval := trust_evaluation(node)
    eval.overall >= 0.7
    eval.reliability >= 0.5
    eval.hallucination_risk <= 0.3
}

# Compute multi-dimensional trust score / 计算多维信任分数
# Weights: reliability 25%, reversibility 20%, blast_radius (inverse) 20%, stability 20%, hallucination_risk (inverse) 15%
# 权重：可靠性25%、可逆性20%、爆炸半径（反向）20%、稳定性20%、幻觉风险（反向）15%
trust_evaluation(node) = eval if {
    trust := node.trust_matrix
    eval := {
        "overall": (trust.reliability * 0.25) +                    # Reliability score / 可靠性分数
                    (trust.reversibility * 0.20) +                  # Reversibility score / 可逆性分数
                    (1 - trust.blast_radius * 0.20) +               # Inverse blast radius / 反向爆炸半径
                    (trust.stability * 0.20) +                      # Stability score / 稳定性分数
                    ((1 - trust.hallucination_risk) * 0.15),        # Inverse hallucination risk / 反向幻觉风险
        "reliability": trust.reliability,                           # Raw reliability / 原始可靠性
        "reversibility": trust.reversibility,                       # Raw reversibility / 原始可逆性
        "blast_radius": trust.blast_radius,                         # Raw blast radius / 原始爆炸半径
        "stability": trust.stability,                               # Raw stability / 原始稳定性
        "hallucination_risk": trust.hallucination_risk,             # Raw hallucination risk / 原始幻觉风险
        "mean_time_to_recover_hours": trust.mean_time_to_recover     # MTTR in hours / MTTR（小时）
    }
}

# Default trust for nodes without explicit matrix / 没有显式矩阵的节点的默认信任值
default_trust = {
    "reliability": 0.5,
    "reversibility": 0.5,
    "blast_radius": 0.5,
    "stability": 0.5,
    "hallucination_risk": 0.5,
    "mean_time_to_recover": 24
}
