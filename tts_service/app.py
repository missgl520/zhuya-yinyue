"""
竹笌 TTS 微服务 —— 基于 IndexTTS 2.5 的本地自托管语音合成。

独立进程运行（与 zhuyapp-backend 主服务分离，避免污染其 Python 3.13 环境）。
主后端通过 httpx 反向代理 /tts 到此服务（默认 127.0.0.1:8001）。

启动（在 tts_service 目录下）：
    cd F:/zhuyapp-backend/tts_service/index-tts
    ..\\.venv\\Scripts\\python.exe -m uvicorn app:app --host 127.0.0.1 --port 8001

注意：infer_v2_5 在 import 时会把 HF_HUB_CACHE 写死为相对路径 ./checkpoints/hf_cache，
所以本文件在导入时主动 chdir 到 index-tts 仓库目录，确保缓存/权重都落在 F 盘。
"""

import os
import io
import time
import tempfile
import uuid

from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

# ---- 固定工作目录到 IndexTTS 仓库（保证相对路径 checkpoints/ 正确，且全在 F 盘）----
_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.join(_HERE, "index-tts")
os.chdir(_REPO)

# 中国网络环境走 hf 镜像，加速权重/示例下载
os.environ.setdefault("HF_ENDPOINT", "https://hf-mirror.com")

from indextts.infer_v2_5 import IndexTTS2  # noqa: E402

MODEL_DIR = "checkpoints"  # 即 IndexTeam/IndexTTS-2.5 下载目录
CFG_PATH = "checkpoints/config.yaml"
DEFAULT_VOICE = os.path.join(
    "examples", "voice_01.wav"
)  # 竹笌占位声线（后续可换 VA 样本）

# 聊天情绪 -> 中文情感文本（驱动 emo_text 文本情绪控制）
EMOTION_TO_TEXT = {
    "happy": "开心地、轻快地",
    "joy": "开心地、轻快地",
    "sad": "低落地、温柔地",
    "angry": "略带不满地",
    "calm": "平静地、温柔地",
    "shy": "害羞地、轻声地",
    "cute": "可爱地、撒娇地",
    "excited": "兴奋地、雀跃地",
    "thinking": "认真地、思索地",
    "neutral": None,
}

app = FastAPI(title="Zhuyapp TTS (IndexTTS 2.5)")

_tts = None
_emo_available = False


def _load_model():
    global _tts, _emo_available
    if _tts is not None:
        return
    use_cuda = (
        os.environ.get("CUDA_VISIBLE_DEVICES", "") != "-1"
        and __import__("torch").cuda.is_available()
    )
    device = "cuda" if use_cuda else "cpu"
    print(
        f">> [TTS] loading IndexTTS2 on device={device} (bf16={use_cuda}) ...",
        flush=True,
    )
    t0 = time.time()
    try:
        _tts = IndexTTS2(
            cfg_path=CFG_PATH,
            model_dir=MODEL_DIR,
            use_bf16=use_cuda,
            device=device,
            use_qwen_emo=True,  # 启用文本情绪控制（emo_text）
        )
        _emo_available = True
    except Exception as e:  # 情绪模型缺失时降级：仅音色克隆，无情绪控制
        print(
            f">> [TTS] use_qwen_emo failed ({e}); retry without emotion model",
            flush=True,
        )
        _tts = IndexTTS2(
            cfg_path=CFG_PATH,
            model_dir=MODEL_DIR,
            use_bf16=use_cuda,
            device=device,
            use_qwen_emo=False,
        )
        _emo_available = False
    # 预热：用占位声线跑一句，避免首个用户请求卡顿
    try:
        with tempfile.TemporaryDirectory() as td:
            warm = os.path.join(td, "warm.wav")
            _tts.infer(
                spk_audio_prompt=DEFAULT_VOICE,
                text="你好，我是竹笌。",
                output_path=warm,
                lang="ZH",
                verbose=False,
            )
        print(
            f">> [TTS] ready in {time.time()-t0:.1f}s (emo={'on' if _emo_available else 'off'})",
            flush=True,
        )
    except Exception as e:
        print(f">> [TTS] warm-up skipped: {e}", flush=True)


@app.on_event("startup")
def _startup():
    # 后台线程加载，避免阻塞服务启动（首个请求若未就绪会等待）
    import threading

    threading.Thread(target=_load_model, daemon=True).start()


class TtsRequest(BaseModel):
    text: str
    lang: str = "ZH"  # ZH / EN / JA / ES / AR
    emotion: str | None = None  # happy/sad/shy/cute/... 见 EMOTION_TO_TEXT
    emo_text: str | None = None  # 直接给情感文本亦可
    speed: float = 1.0  # 0.5 - 2.0


@app.get("/health")
def health():
    return {"status": "ok", "ready": _tts is not None, "emo": _emo_available}


@app.post("/tts")
def tts(req: TtsRequest):
    if _tts is None:
        # 等待模型加载完成（最多 120s）
        deadline = time.time() + 120
        while _tts is None and time.time() < deadline:
            time.sleep(0.5)
    if _tts is None:
        raise HTTPException(status_code=503, detail="TTS model still loading")

    text = (req.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="empty text")

    # 解析情绪文本
    emo_text = req.emo_text
    if emo_text is None and req.emotion:
        emo_text = EMOTION_TO_TEXT.get(req.emotion.lower())
    use_emo = _emo_available and bool(emo_text)

    speed = max(0.5, min(2.0, float(req.speed)))
    lang = (req.lang or "ZH").upper()

    try:
        with tempfile.TemporaryDirectory() as td:
            out = os.path.join(td, f"{uuid.uuid4().hex}.wav")
            _tts.infer(
                spk_audio_prompt=DEFAULT_VOICE,
                text=text,
                output_path=out,
                lang=lang,
                use_emo_text=use_emo,
                emo_text=emo_text if use_emo else None,
                duration_factor=speed,
                verbose=False,
            )
            with open(out, "rb") as f:
                data = f.read()
        if not data:
            raise HTTPException(status_code=500, detail="empty audio")
        return Response(content=data, media_type="audio/wav")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"tts failed: {e}")
