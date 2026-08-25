"""spike 验证：检测 CesiumMan 是否在播放走路动画（腿/全身运动）。
用法：python _spike_check.py f1.png f2.png ...
输出每帧间像素变化量 + 下半身（腿）区域变化量，判断是否真在动。
"""
import sys
import numpy as np
from PIL import Image

files = sys.argv[1:]
if not files:
    print("usage: python _spike_check.py f1.png f2.png ...")
    sys.exit(1)

imgs = [np.array(Image.open(f).convert("RGB"), dtype=np.int16) for f in files]
h, w = imgs[0].shape[:2]
# 下半身（腿）区域：画面高度 55%~100%
leg_top = int(h * 0.55)

print(f"image {w}x{h}, leg region y in [{leg_top},{h})")
total_changes = []
leg_changes = []
for i in range(len(imgs) - 1):
    d = np.abs(imgs[i + 1] - imgs[i]).sum(axis=2)
    ch = (d > 15)
    total = int(ch.sum())
    leg = int(ch[leg_top:].sum())
    total_changes.append(total)
    leg_changes.append(leg)
    ys, xs = np.where(ch)
    cx = int(xs.mean()) if len(xs) else 0
    print(f"f{i+1}^f{i+2}: total_changed={total}  leg_changed={leg}  cx={cx}")

if total_changes:
    print(f"\nSUMMARY: total avg={np.mean(total_changes):.0f}  leg avg={np.mean(leg_changes):.0f}")
    print("VERDICT:", "ANIMATING ✅" if np.mean(total_changes) > 1000 else "STATIC ❌")
