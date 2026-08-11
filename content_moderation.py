# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 内容安全前置过滤（content_moderation.py）
#
# 落实《生成式人工智能服务管理暂行办法》对用户输入的违法不良信息
# 前置过滤要求。当前为 MVP 本地关键词实现，仅覆盖最典型的高危类别；
# 生产环境应替换为专业内容安全服务（如网信办备案的审核 API），
# 本模块接口（moderate）保持不变即可平滑替换。
#
#   moderate(text) -> (blocked: bool, reason: str)
#     blocked=True 表示命中违规，需拦截并拒绝生成。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# MVP 高危关键词（示例，生产务必接入专业审核服务并扩充词库）
_PROHIBITED = [
    # 违法违规类（示例，非穷举）
    "制作炸弹", "如何制毒", "毒品配方", "买卖枪支",
    "儿童色情", "淫秽视频", "裸聊诈骗",
    "自杀教程", "自残方法教程",
    "侵犯公民个人信息", "人肉搜索教程",
    "煽动颠覆", "恐怖袭击", "爆炸物配方",
]

# 敏感类别提示（命中后给出合规提示，不直接拦截，交由模型约束）
_SENSITIVE = [
    "政治", "宗教", "赌博", "色情", "暴力",
]


def moderate(text: str) -> tuple:
    """对用户输入做前置过滤。

    返回 (blocked, reason)：
      - blocked=False  → 放行
      - blocked=True   → 命中高危违规，拦截并给出 reason
    """
    if not text:
        return (False, "")

    lowered = text.lower()
    for kw in _PROHIBITED:
        if kw.lower() in lowered:
            return (True, f"内容包含违法违规信息（命中关键词「{kw}」），已被拦截")

    return (False, "")


def is_sensitive(text: str) -> bool:
    """是否命中敏感类别（用于合规留痕，不拦截）。"""
    if not text:
        return False
    lowered = text.lower()
    return any(kw.lower() in lowered for kw in _SENSITIVE)
