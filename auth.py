# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 接口签名鉴权（auth.py）
#
# 采用「API Key + 请求签名」方案，满足生成式 AI 服务安全评估
# 中关于接口鉴权、防篡改、防重放的要求：
#
#   客户端每个请求需携带以下请求头：
#     X-Api-Key    : 与后端 ZHUYU_API_KEY 一致的密钥
#     X-Timestamp  : Unix 秒级时间戳
#     X-Nonce      : 一次性随机串（防重放）
#     X-Signature  : HMAC-SHA256 签名
#     X-User-Id    : 设备/用户唯一标识（用于多用户数据隔离）
#
#   签名串（canonical）构造：
#     METHOD\nPATH\nTIMESTAMP\nNONCE\nSHA256(BODY)
#   签名 = HMAC-SHA256(API_KEY, canonical).hexdigest()
#
#   公开路径（健康检查 / 文档 / 法律文本）免签名，见 PUBLIC_PATHS。
#   未配置 API_KEY 时进入开发模式，不强制签名（便于本地联调）。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import hashlib
import hmac
import time

from fastapi import Request, HTTPException, status

from config import settings

# 不需要签名的公开路径（健康检查、API 文档、法律文本）
PUBLIC_PATHS = {
    "/",
    "/health",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/legal/privacy",
    "/legal/terms",
}

# 重放防护：记录已使用过的 nonce 及其过期时间（进程内，单实例足够）
_SEEN_NONCES: dict = {}


def _prune_nonces(now: int) -> None:
    """清理已过期的 nonce 记录。"""
    expired = [n for n, exp in _SEEN_NONCES.items() if exp < now]
    for n in expired:
        _SEEN_NONCES.pop(n, None)


def compute_signature(
    api_key: str,
    method: str,
    path: str,
    timestamp: str,
    nonce: str,
    body: bytes,
) -> str:
    """计算请求签名（HMAC-SHA256）。客户端与服务端使用同一实现。"""
    body_hash = hashlib.sha256(body or b"").hexdigest()
    canonical = "\n".join(
        [method.upper(), path, timestamp, nonce, body_hash]
    )
    return hmac.new(
        api_key.encode("utf-8"),
        canonical.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


async def verify_request(request: Request) -> None:
    """FastAPI 依赖：校验请求签名，并注入 request.state.user_id。

    校验顺序：公开路径白名单 → 开发模式跳过 → 头存在性 →
    API Key → 时间戳容差 → nonce 重放 → HMAC 签名。
    """
    path = request.url.path

    # 1) 公开路径免签名
    if path in PUBLIC_PATHS:
        request.state.user_id = request.headers.get("X-User-Id") or "default"
        return

    # 2) 开发模式：未配置 API Key 时不强制签名
    if not settings.API_KEY:
        request.state.user_id = request.headers.get("X-User-Id") or "default"
        return

    api_key = request.headers.get("X-Api-Key", "")
    timestamp = request.headers.get("X-Timestamp", "")
    nonce = request.headers.get("X-Nonce", "")
    signature = request.headers.get("X-Signature", "")

    # 3) 头完整性
    if not (api_key and timestamp and nonce and signature):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="缺少鉴权头（X-Api-Key/X-Timestamp/X-Nonce/X-Signature）",
        )

    # 4) API Key 校验
    if not hmac.compare_digest(api_key, settings.API_KEY):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API Key 无效",
        )

    # 5) 时间戳容差（防重放）
    try:
        ts = int(timestamp)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-Timestamp 格式错误",
        )
    now = int(time.time())
    if abs(now - ts) > settings.SIGNATURE_TOLERANCE_SECONDS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="请求已过期（时间戳超出容差）",
        )

    # 6) nonce 重放防护
    _prune_nonces(now)
    if nonce in _SEEN_NONCES:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="请求重放被拒绝（nonce 已使用）",
        )
    _SEEN_NONCES[nonce] = now + settings.SIGNATURE_TOLERANCE_SECONDS

    # 7) 读取 body 用于签名校验（GET 无 body）
    body = b""
    if request.method.upper() in ("POST", "PUT", "DELETE", "PATCH"):
        try:
            body = await request.body()
        except Exception:
            body = b""

    expected = compute_signature(
        settings.API_KEY, request.method, path, timestamp, nonce, body
    )
    if not hmac.compare_digest(expected, signature):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="签名校验失败",
        )

    # 注入用户标识，供路由做多用户隔离
    request.state.user_id = request.headers.get("X-User-Id") or "default"
