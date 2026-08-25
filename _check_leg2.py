from PIL import Image, ImageDraw
import numpy as np

fs = [f"f:/zhuyapp/_leg2_{i}.png" for i in range(1, 9)]
imgs = [np.array(Image.open(f).convert("RGB"), dtype=np.int16) for f in fs]
H, W = imgs[0].shape[:2]
print(f"img {W}x{H}")

LEG_Y0, LEG_Y1 = 850, 1300

print("=== leg region frame diff ===")
for i in range(len(imgs) - 1):
    d = np.abs(imgs[i + 1] - imgs[i]).sum(axis=2)
    leg_changed = int((d[LEG_Y0:LEG_Y1] > 15).sum())
    print(f"  f{i+1}^f{i+2}: leg_changed={leg_changed} px")

def foot_bottom_y(img):
    rgb = img
    dark = (rgb[:, :, 0] < 90) & (rgb[:, :, 1] < 90) & (rgb[:, :, 2] < 90)
    region = dark[LEG_Y0:LEG_Y1, 100:980]
    if region.sum() == 0:
        return None
    ys, _ = np.where(region)
    if len(ys) == 0:
        return None
    return LEG_Y0 + int(ys.max())

print("=== per-frame foot bottom y (smaller = foot higher) ===")
foot_ys = []
for i, im in enumerate(imgs):
    fy = foot_bottom_y(im)
    foot_ys.append(fy)
    print(f"  f{i+1}: foot_y={fy}")

valid = [(i, y) for i, y in enumerate(foot_ys) if y is not None]
if valid:
    spread = max(y for _, y in valid) - min(y for _, y in valid)
    print(f"foot_y spread = {spread} px")
    if spread >= 30:
        print("-> leg lift VISIBLE (>30px)")
    elif spread >= 15:
        print("-> leg lift noticeable (15-30px)")
    else:
        print("-> leg lift NOT obvious (<15px)")

    sorted_v = sorted(valid, key=lambda t: t[1])
    pick = [sorted_v[0], sorted_v[len(sorted_v)//2], sorted_v[-1], sorted_v[len(sorted_v)//4]]
    pick_idxs = [t[0] for t in pick]
    canvas = Image.new("RGB", (W * len(pick_idxs), H + 40), "white")
    d = ImageDraw.Draw(canvas)
    for j, idx in enumerate(pick_idxs):
        canvas.paste(Image.open(fs[idx]), (j * W, 40))
        d.text((j * W + 20, 10), f"f{idx+1} foot_y={foot_ys[idx]}", fill="black")
    canvas.save("f:/zhuyapp/_leg_compare.png")
    print(f"compare image: f:/zhuyapp/_leg_compare.png  (picked f{[i+1 for i in pick_idxs]})")
