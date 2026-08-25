from PIL import Image, ImageDraw
import numpy as np

fs = [f"f:/zhuyapp/_run_{i}.png" for i in range(1, 9)]
imgs = [np.array(Image.open(f).convert("RGB"), dtype=np.int16) for f in fs]
H, W = imgs[0].shape[:2]
print(f"img {W}x{H}")

# 1) 找每帧脚底 y_max (靴子橙底或靴子下沿)
# Ren 模型靴子下沿 y 大约在 1000-1100，背景地面/阴影在 ~1200
# 用角色区域 (x 200-880) 找深色靴子像素最低 y
def find_foot_y(img, y_range=(900, 1200), x_range=(200, 880)):
    # 找靴子黑色 (R<80, G<80, B<80) 的最低 y
    rgb = img
    dark = (rgb[:, :, 0] < 80) & (rgb[:, :, 1] < 80) & (rgb[:, :, 2] < 80)
    region = dark[y_range[0]:y_range[1], x_range[0]:x_range[1]]
    if region.sum() == 0:
        return None
    ys, _ = np.where(region)
    return y_range[0] + int(ys.max())

# 2) 也找角色顶部 y_min (头发顶) - 颠簸 36px 颠的话头顶 y 变化 ~36px
def find_head_y(img, y_range=(0, 600), x_range=(200, 880)):
    rgb = img
    # 头发是深色到黑色
    dark = (rgb[:, :, 0] < 100) & (rgb[:, :, 1] < 100) & (rgb[:, :, 2] < 120)
    region = dark[y_range[0]:y_range[1], x_range[0]:x_range[1]]
    if region.sum() == 0:
        return None
    ys, _ = np.where(region)
    return y_range[0] + int(ys.min())

print("\n=== per-frame foot y (越小=脚抬得高) & head y (越小=头上跳得多) ===")
foots = []
heads = []
for i, im in enumerate(imgs):
    fy = find_foot_y(im)
    hy = find_head_y(im)
    foots.append(fy)
    heads.append(hy)
    print(f"  f{i+1}: foot_y={fy}  head_y={hy}")

valid_f = [(i, y) for i, y in enumerate(foots) if y is not None]
valid_h = [(i, y) for i, y in enumerate(heads) if y is not None]
if valid_f:
    spread_f = max(y for _, y in valid_f) - min(y for _, y in valid_f)
    print(f"\nfoot_y spread = {spread_f} px")
if valid_h:
    spread_h = max(y for _, y in valid_h) - min(y for _, y in valid_h)
    print(f"head_y spread = {spread_h} px  (蹦跶颠簸幅度量化)")
    if spread_h >= 30:
        print("  -> 颠簸明显 (>30px) = 蹦跶跑成功")
    elif spread_h >= 20:
        print("  -> 颠簸可感知 (20-30px)")
    else:
        print("  -> 颠簸小 (<20px)")

# 3) 拼 4 帧对比图: 选 head_y 最大(颠最低) + head_y 最小(颠最高) + 中间
if valid_h:
    sorted_v = sorted(valid_h, key=lambda t: t[1])
    # 选 head_y 最小(最高颠) + 1/3 + 2/3 + 最大(最低颠)
    n = len(sorted_v)
    pick_idxs = [sorted_v[0][0], sorted_v[n//3][0], sorted_v[2*n//3][0], sorted_v[-1][0]]
    pick_idxs = sorted(set(pick_idxs))  # 去重排序
    canvas = Image.new("RGB", (W * len(pick_idxs), H + 40), "white")
    d = ImageDraw.Draw(canvas)
    for j, idx in enumerate(pick_idxs):
        canvas.paste(Image.open(fs[idx]), (j * W, 40))
        d.text((j * W + 20, 10), f"f{idx+1} head_y={heads[idx]} foot_y={foots[idx]}", fill="black")
    canvas.save("f:/zhuyapp/_run_compare.png")
    print(f"\ncompare: f:/zhuyapp/_run_compare.png  (picked f{[i+1 for i in pick_idxs]})")
