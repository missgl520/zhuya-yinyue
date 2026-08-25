from PIL import Image
import numpy as np

fs = [f"f:/zhuyapp/_k_{i}.png" for i in range(1, 31)]
arr = [np.array(Image.open(f).convert("RGB"), dtype=np.int16) for f in fs]
H, W = arr[0].shape[:2]

print(f"img {W}x{H}, frames={len(arr)}, dt=0.2s, span={len(arr)*0.2:.1f}s")
print()
print("idx | changed_px | cy_min..cy_max   |  verdict")
for i in range(len(arr) - 1):
    d = np.abs(arr[i+1] - arr[i]).sum(axis=2)
    ch = (d > 15)
    ys, xs = np.where(ch)
    n = len(xs)
    if n == 0:
        print(f"f{i+1:>2}^f{i+2:>2} | {n:>10} | (none)         |  STATIC")
        continue
    cy_min, cy_max = int(ys.min()), int(ys.max())
    # Frozen = 整体变化 < 15k 且 cy 范围很窄（只在提示动画区）
    if n < 15000 and (cy_max - cy_min) < 200:
        verdict = "FROZEN (WebGL stalled)"
    else:
        verdict = "animating"
    print(f"f{i+1:>2}^f{i+2:>2} | {n:>10} | y[{cy_min:>4}..{cy_max:>4}] |  {verdict}")

# 取 6 帧（覆盖 6s 中各阶段）拼对比图
import os
sel = [0, 4, 9, 14, 19, 24]
canvas = Image.new("RGB", (W*len(sel), H), (237,247,240))
from PIL import ImageDraw
d = ImageDraw.Draw(canvas)
for j, idx in enumerate(sel):
    canvas.paste(Image.open(fs[idx]), (j*W, 0))
    d.text((j*W+10, 10), f"t={idx*0.2:.1f}s", fill="black")
canvas.save("f:/zhuyapp/_k_compare.png")
print(f"\nsaved _k_compare.png  frames at t={','.join(str(s*0.2) for s in sel)}s")
