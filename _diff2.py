from PIL import Image, ImageDraw
import numpy as np

paths = [f'f:/zhuyapp/_emu_f{i}.png' for i in range(1, 7)]
imgs = [np.array(Image.open(p).convert('RGB')) for p in paths]
H, W, _ = imgs[0].shape
print(f'orig {W}x{H}')

TOP_CUT = 100   # 状态栏
BOT_CUT = 120   # 系统导航条

def fg(img):
    r = img[:, :, 0].astype(int)
    g = img[:, :, 1].astype(int)
    b = img[:, :, 2].astype(int)
    bg = (g > r + 3) & (g > b + 3) & (g > 190) & (r > 180)
    m = ~bg
    m[:TOP_CUT, :] = False
    m[H - BOT_CUT:, :] = False
    return m

masks = [fg(im) for im in imgs]
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

# 修正的 y 分区（按 1080x2400 原图，角色在中央 ~y 600-1900）
bands = [
    (200, 600,  '头/发(蓝)'),
    (600, 900,  '脸/肩'),
    (900, 1200, '躯干/手摆'),
    (1200, 1700, '腿/迈步'),
    (1700, 2100, '脚/靴'),
]
print('\n--- per-band motion (XOR pixels, by frame pair) ---')
for y0, y1, name in bands:
    s12 = int((masks[0] ^ masks[1])[y0:y1, :].sum())
    s34 = int((masks[2] ^ masks[3])[y0:y1, :].sum())
    s56 = int((masks[4] ^ masks[5])[y0:y1, :].sum())
    print(f'y[{y0:4d}-{y1:4d}] {name:10s}: f1^f2={s12:6d}  f3^f4={s34:6d}  f5^f6={s56:6d}')

# 左右分区：看漂移主要方向
print('\n--- left/right motion (前景 XOR) ---')
mid = W // 2
for i in range(1, len(masks)):
    x = masks[i-1] ^ masks[i]
    L = int(x[:, :mid].sum())
    R = int(x[:, mid:].sum())
    print(f'f{i+1}^f{i}: left={L:6d}  right={R:6d}  (delta_cx={centroids[i][0]-centroids[i-1][0]:+.1f})')

# 拼图：f1 / f3 / f5 横排
imgs_pil = [Image.open(f'f:/zhuyapp/_emu_f{i}.png') for i in (1, 3, 5)]
small = [im.resize((540, 1200)) for im in imgs_pil]
GW, GH = 540, 1200
gap = 10
grid = Image.new('RGB', (GW * 3 + gap * 2, GH + 70), (255, 255, 255))
draw = ImageDraw.Draw(grid)
for i, (im, idx) in enumerate(zip(small, (1, 3, 5))):
    x = i * (GW + gap)
    grid.paste(im, (x, 50))
    draw.text((x + 8, 18), f'frame {idx}  t={(idx-1)*0.8:.1f}s', fill='black')
grid.save('f:/zhuyapp/_walk_compare.png')
print('\nsaved _walk_compare.png  size', grid.size)

# 另存一张：f1 和 f4 对比（间隔 2.4s ≈ 2 个步态周期，姿态差异最大）
imgs_pil2 = [Image.open(f'f:/zhuyapp/_emu_f{i}.png') for i in (1, 4)]
small2 = [im.resize((540, 1200)) for im in imgs_pil2]
grid2 = Image.new('RGB', (GW * 2 + gap, GH + 70), (255, 255, 255))
draw2 = ImageDraw.Draw(grid2)
for i, (im, idx) in enumerate(zip(small2, (1, 4))):
    x = i * (GW + gap)
    grid2.paste(im, (x, 50))
    draw2.text((x + 8, 18), f'frame {idx}  t={(idx-1)*0.8:.1f}s', fill='black')
grid2.save('f:/zhuyapp/_walk_f1_vs_f4.png')
print('saved _walk_f1_vs_f4.png  size', grid2.size)
