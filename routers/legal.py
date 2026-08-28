# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 法律文本路由（隐私政策 / 用户协议）
# GET /legal/privacy   隐私政策（Markdown）
# GET /legal/terms     用户协议（Markdown）
#
# 文档模板中的占位标记（运营主体名称/联系邮箱）会被替换为 .env 配置。
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import os

from fastapi import APIRouter
from fastapi.responses import PlainTextResponse

from config import BASE_DIR, settings

router = APIRouter(prefix="/legal", tags=["legal"])

# 法律文本目录（隐私政策 / 用户协议）
LEGAL_DIR = os.path.join(BASE_DIR, "legal")


def _read_legal(filename: str) -> str:
    path = os.path.join(LEGAL_DIR, filename)
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        return f"# {filename} 未找到\n请先在 legal/ 目录放置对应文档。"

    # 将文档模板中的占位标记替换为运营方配置（来源：.env → config.py）
    return (
        text.replace("【请填写运营主体名称】", settings.OPERATOR_NAME)
        .replace("【请填写隐私联系邮箱】", settings.PRIVACY_CONTACT_EMAIL)
        .replace("【请填写服务联系邮箱】", settings.SERVICE_CONTACT_EMAIL)
    )


@router.get("/privacy", include_in_schema=True)
def legal_privacy():
    """隐私政策（Markdown）。"""
    return PlainTextResponse(
        _read_legal("privacy_policy.md"),
        media_type="text/markdown; charset=utf-8",
    )


@router.get("/terms", include_in_schema=True)
def legal_terms():
    """用户协议（Markdown）。"""
    return PlainTextResponse(
        _read_legal("terms_of_service.md"),
        media_type="text/markdown; charset=utf-8",
    )
