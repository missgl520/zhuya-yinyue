# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 情绪识别引擎（emotion_engine.py）
#
# 轻量级规则引擎：根据关键词给 14 维情绪打分，返回主情绪 + 置信度。
# 与前端 Emotion.fromJson 期望的字段对齐：
#   { "emotion": str, "confidence": float, "scores": {dim: float} }
# 有 AGNES_API_KEY 时也可改为调用大模型判断，这里用规则保证离线可用。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

_KEYWORDS = {
    "happy": [
        "开心",
        "高兴",
        "哈哈",
        "嘻",
        "喜欢",
        "爱",
        "棒",
        "好耶",
        "耶",
        "可爱",
        "幸福",
    ],
    "sad": ["难过", "伤心", "哭", "遗憾", "失望", "孤独", "想哭", "委屈"],
    "angry": ["生气", "烦", "讨厌", "气死", "滚", "讨厌", "可恶", "讨厌死了"],
    "fearful": ["怕", "害怕", "担心", "恐怖", "不敢", "紧张"],
    "curious": ["怎么", "为什么", "什么", "如何", "吗", "？", "?", "想知道"],
    "surprised": ["哇", "天哪", "居然", "竟然", "没想到", "！", "!"],
    "proud": ["厉害", "牛", "强", "佩服", "崇拜", "优秀"],
    "ashamed": ["不好意思", "害羞", "惭愧", "尴尬", "脸红"],
    "trust": ["相信", "信任", "靠谱", "安心"],
    "awe": ["震撼", "敬畏", "伟大", "壮观"],
    "attachment": ["想你", "离不开", "陪我", "在一起"],
    "disgust": ["恶心", "反感", "讨厌", "呕"],
    "guilt": ["对不起", "抱歉", "内疚", "我的错"],
    "frustration": ["算了", "无奈", "烦死了", "搞不定"],
}


# 强情感集合：一旦命中即作为主情绪候选，优先级高于认知/好奇类
# （如「开心」应优先于回复里常见的「吗？」问句词 curious）。
_STRONG_EMOTIONS = {
    "happy",
    "sad",
    "angry",
    "fearful",
    "guilt",
    "ashamed",
    "disgust",
    "frustration",
    "attachment",
}


def detect_emotion(text: str) -> dict:
    """返回 {emotion, confidence, scores}"""
    scores = {}
    for emo, kws in _KEYWORDS.items():
        hit = sum(1 for k in kws if k in (text or ""))
        # 强情感命中基础分更高，避免被问句词（curious/surprised）反超
        base = 0.5 if emo in _STRONG_EMOTIONS else 0.3
        scores[emo] = round(min(1.0, hit * base), 3)

    active = {k: v for k, v in scores.items() if v > 0}
    if not active:
        return {"emotion": "neutral", "confidence": 0.6, "scores": scores}

    # 并列时优先强情感，其次按分数降序
    top = max(active, key=lambda k: (k in _STRONG_EMOTIONS, active[k]))
    confidence = round(min(0.96, 0.5 + active[top] * 0.45), 3)
    return {"emotion": top, "confidence": confidence, "scores": scores}
