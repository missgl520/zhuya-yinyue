from PIL import Image, ImageDraw
import numpy as np

fs = [f"f:/zhuyapp/_run_{i}.png" for i in range(1, 9)]
imgs = [np.array(Image.open(f).convert("RGB"), dtype=np.int16) for f in fs]
H, W = imgs[0].shape[:2]

# 真实角色范围: 头顶~270, 靴子~820
def find_head_y(img, y_range=(200, 400), x_range=(300, 780)):
    rgb = img
    dark = (rgb[:, :, 0] < 100) & (rgb[:, :, 1] < 100) & (rgb[:, :, 2] < 120)
    region = dark[y_range[0]:y_range[1], x_range[0]:x_range[1]]
    if region.sum() == 0: return None
    ys, _ = np.where(region)
    return y_range[0] + int(ys.min())

def find_foot_y(img, y_range=(700, 900), x_range=(300, 780)):
    rgb = img
    dark = (rgb[:, :, 0] < 80) & (rgb[:, :, 1] < 80) & (rgb[:, :, 2] < 80)
    region = dark[y_range[0]:y_range[1], x_range[0]:x_range[1]]
    if region.sum() == 0: return None
    ys, _ = np.where(region)
    return y_range[0] + int(ys.max())

print("=== per-frame head/foot y (修正检测区域) ===")
foots = []
heads = []
for i, im in enumerate(imgs):
    fy = find_foot_y(im)
    hy = find_head_y(im)
    foots.append(fy); heads.append(hy)
    print(f"  f{i+1}: head_y={hy}  foot_y={fy}")

valid_h = [(i, y) for i, y in enumerate(heads) if y is not None]
valid_f = [(i, y) for i, y in enumerate(foots) if y is not None]
if valid_h:
    spread_h = max(y for _, y in valid_h) - min(y for _, y in valid_h)
    print(f"\nhead_y spread = {spread_h} px  (颠簸幅度)")
    if spread_h >= 30: print("  -> 蹦跶明显 (>30px)")
    elif spread_h >= 20: print("  -> 颠簸可感知")
    else: print("  -> 颠簸小")
if valid_f:
    spread_f = max(y for _, y in valid_f) - min(y for _, y in valid_f)
    print(f"foot_y spread = {spread_f} px")

if valid_h:
    sorted_v = sorted(valid_h, key=lambda t: t[1])
    n = len(sorted_v)
    pick = [sorted_v[0], sorted_v[n//3], sorted_v[2*n//3], sorted_v[-1]]
    pick_idxs = sorted(set([t[0] for t in pick]))
    canvas = Image.new("RGB", (W * len(pick_idxs), H + 40), "white")
    d = ImageDraw.Draw(canvas)
    for j, idx in enumerate(pick_idxs):
        canvas.paste(Image.open(fs[idx]), (j * W, 40))
        d.text((j * W + 20, 10), f"f{idx+1} head_y={heads[idx]} foot_y={foots[idx]}", fill="black")
    canvas.save("f:/zhuyapp/_run_compare2.png")
    print(f"\ncompare2: f:/zhuyapp/_run_compare2.png  picked f{[i+1 for i in pick_idxs]}")
