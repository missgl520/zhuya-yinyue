from PIL import Image
import numpy as np
import sys

paths = [f'f:/zhuyapp/_emu_f{i}.png' for i in range(1, 7)]
imgs = [np.array(Image.open(p).convert('RGB')) for p in paths]
H, W, _ = imgs[0].shape
print(f'frames={len(imgs)} size={W}x{H}')

# 排除顶部状态栏与底部系统导航栏
TOP_CUT = 50
BOT_CUT = 80

def fg_mask(img):
    r = img[:, :, 0].astype(int)
    g = img[:, :, 1].astype(int)
    b = img[:, :, 2].astype(int)
    # 背景：浅绿
    bg = (g > r + 3) & (g > b + 3) & (g > 190) & (r > 180)
    fg = ~bg
    fg[:TOP_CUT, :] = False
    fg[H - BOT_CUT:, :] = False
    return fg

masks = [fg_mask(im) for im in imgs]
centroids = []
for m in masks:
    ys, xs = np.where(m)
    if len(xs):
        centroids.append((float(xs.mean()), float(ys.mean()), int(m.sum())))
    else:
        centroids.append((0, 0, 0))

print('\nidx   cx      cy     fg_px')
for i, c in enumerate(centroids):
    print(f'f{i+1}  {c[0]:7.2f} {c[1]:7.2f}  {c[2]}')

print('\n--- centroid delta (between consecutive frames) ---')
for i in range(1, len(centroids)):
    dx = centroids[i][0] - centroids[i-1][0]
    dy = centroids[i][1] - centroids[i-1][1]
    print(f'f{i+1}-f{i}: dx={dx:+.2f}  dy={dy:+.2f}')

print('\n--- foreground XOR pixels (frame-to-frame motion) ---')
for i in range(1, len(masks)):
    xor = masks[i-1] ^ masks[i]
    print(f'f{i+1}^f{i}: {int(xor.sum())} px')

# 分区运动：看运动集中在画面哪个 y 区域
print('\n--- per-band motion (f1^f2) ---')
xor12 = masks[0] ^ masks[1]
bands = [
    (50, 220, '头发/脸'),
    (220, 420, '躯干/手'),
    (420, 700, '腿/膝'),
    (700, 1000, '脚/靴'),
]
for y0, y1, name in bands:
    s = int(xor12[y0:y1, :].sum())
    print(f'y[{y0:4d}-{y1:4d}] {name:10s}: {s} px')

# 水平方向运动分布：左右分区，看漂移方向
print('\n--- left/right motion (f1^f2) ---')
mid = W // 2
left = int(xor12[:, :mid].sum())
right = int(xor12[:, mid:].sum())
print(f'left(x<{mid}): {left}  right(x>={mid}): {right}')

# 总结
print('\n=== summary ===')
dxx = [centroids[i][0]-centroids[i-1][0] for i in range(1,len(centroids))]
dyy = [centroids[i][1]-centroids[i-1][1] for i in range(1,len(centroids))]
xor_seq = [int((masks[i-1]^masks[i]).sum()) for i in range(1,len(masks))]
print(f'cx range: {min(c[0] for c in centroids):.2f} ~ {max(c[0] for c in centroids):.2f}  (spread {max(c[0] for c in centroids)-min(c[0] for c in centroids):.2f}px = horizontal drift)')
print(f'cy range: {min(c[1] for c in centroids):.2f} ~ {max(c[1] for c in centroids):.2f}  (spread {max(c[1] for c in centroids)-min(c[1] for c in centroids):.2f}px = vertical bob)')
print(f'XOR pixels per frame: {xor_seq}  (limb/edge motion)')
print(f'dx sequence: {[f"{d:+.1f}" for d in dxx]}')
print(f'dy sequence: {[f"{d:+.1f}" for d in dyy]}')
