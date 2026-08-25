from PIL import Image
import numpy as np

fs = [f"f:/zhuyapp/_vrm_{i}.png" for i in range(1, 13)]
imgs = [np.array(Image.open(p).convert("RGB"), dtype=np.int16) for p in fs]
h, w = imgs[0].shape[:2]
print(f"frame size {w}x{h}")

# 帧差：统计变化像素数 + 质心，判断是否在动（走路）
total_changes = []
for i in range(len(imgs) - 1):
    d = np.abs(imgs[i + 1] - imgs[i]).sum(axis=2)
    ch = (d > 15)
    n = int(ch.sum())
    ys, xs = np.where(ch)
    cx = int(xs.mean()) if len(xs) else 0
    cy = int(ys.mean()) if len(ys) else 0
    total_changes.append(n)
    print(f"f{i+1}^f{i+2}: changed={n:>7}  cx={cx:>4}  cy={cy:>4}")

print(f"\nmax frame diff = {max(total_changes)}, min = {min(total_changes)}")
# 中心区域（角色所在）变化
mid_change = []
for i in range(len(imgs) - 1):
    d = np.abs(imgs[i + 1] - imgs[i]).sum(axis=2)
    ch = (d > 15)
    # 中部 40%-80% 高度，30%-70% 宽度
    band = ch[int(h*0.35):int(h*0.85), int(w*0.30):int(w*0.70)]
    mid_change.append(int(band.sum()))
print("mid-region(frame diff):", mid_change)

# 拼一张 4 帧对比图（1,4,8,12）看姿态变化
canvas = Image.new("RGB", (w * 4, h + 40), "white")
from PIL import ImageDraw
d = ImageDraw.Draw(canvas)
for k, idx in enumerate([0, 3, 7, 11]):
    canvas.paste(Image.open(fs[idx]), (k * w, 40))
    d.text((k * w + 20, 10), f"frame {idx+1}", fill="black")
canvas.save("f:/zhuyapp/_vrm_compare.png")
print("saved _vrm_compare.png")
