#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Sync 完成后执行：拉取 IndexTTS-2.5 权重 + 准备参考音频。
用法：index-tts/.venv/Scripts/python.exe setup_weights.py
依赖：huggingface_hub（需先 uv add）。HF_ENDPOINT 走 hf-mirror.com。
"""

import os
import sys
import shutil
from pathlib import Path

REPO = "IndexTeam/IndexTTS-2.5"
CHECKPOINTS = Path(__file__).resolve().parent / "checkpoints"
CHECKPOINTS.mkdir(parents=True, exist_ok=True)


def main():
    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        print("ERROR: huggingface_hub 未安装，请先 `uv add huggingface_hub`")
        sys.exit(2)

    print(
        f"=== 下载 {REPO} -> {CHECKPOINTS} (HF_ENDPOINT={os.environ.get('HF_ENDPOINT')}) ==="
    )
    path = snapshot_download(
        repo_id=REPO,
        local_dir=str(CHECKPOINTS),
        local_dir_use_symlinks=False,
    )
    print(f"=== 权重目录: {path} ===")

    # 参考音频：优先用仓库内 example 音频，否则用现成 voice_01.wav，再否则生成静音占位
    ref_target = Path(__file__).resolve().parent / "voice_01.wav"
    if ref_target.exists():
        print("voice_01.wav 已存在，跳过")
    else:
        candidates = []
        for root, _, files in os.walk(CHECKPOINTS):
            for f in files:
                if f.lower().endswith((".wav",)) and "example" in root.lower():
                    candidates.append(os.path.join(root, f))
        if candidates:
            shutil.copy(candidates[0], ref_target)
            print(f"从仓库复制参考音频: {candidates[0]} -> {ref_target}")
        else:
            print(
                "未找到仓库参考音频；请手动放置 voice_01.wav 到 tts_service/voice_01.wav"
            )
    print("=== SETUP_WEIGHTS_DONE ===")


if __name__ == "__main__":
    main()
