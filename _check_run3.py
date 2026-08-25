from PIL import Image
import numpy as np

fs = [f"f:/zhuyapp/_run_{i}.png" for i in range(1, 9)]
imgs = [np.array(Image.open(f).convert("RGB"), dtype=np.int16) for f in fs]
H, W = imgs[0].shape[:2]

# 背景: 顶部 status bar (灰) + 主区域浅绿 (~230-245) + 底部 nav bar
# 找"非背景"的第一行 y (status bar 之下, ~120 开始)
# 限制 x 范围到画面中央 (200-880, 避开状态栏图标)
def role_top_y(img, x0=300, x1=780, y0=200, y1=900):
    rgb = img.astype(np.int32)
    # 找非"浅绿"区域: 任一通道明显低于 230
    non_bg = (rgb[:, :, 0] < 220) | (rgb[:, :, 1] < 225) | (rgb[:, :, 2] < 215)
    sub = non_bg[y0:y1, x0:x1]
    # 找第一行有非背景像素的 y
    rows = sub.any(axis=1)
    nz = np.where(rows)[0]
    if len(nz) == 0: return None
    return y0 + int(nz[0])

print("=== 每帧角色顶部 y (越小=角色蹦得越高) ===")
tops = []
for i, im in enumerate(imgs):
    t = role_top_y(im)
    tops.append(t)
    print(f"  f{i+1}: role_top_y={t}")

valid = [(i, y) for i, y in enumerate(tops) if y is not None]
if valid:
    spread = max(y for _, y in valid) - min(y for _, y in valid)
    print(f"\nrole_top spread = {spread} px  (蹦跶颠簸幅度)")
    if spread >= 30: print("  -> 蹦跶明显 (>30px)")
    elif spread >= 20: print("  -> 颠簸可感知")
    else: print("  -> 颠簸小")

# 帧间整体像素差
print("\n=== 帧间全图变化像素数 ===")
for i in range(len(imgs)-1):
    d = np.abs(imgs[i+1]-imgs[i]).sum(axis=2)
    ch = int((d>15).sum())
    print(f"  f{i+1}^f{i+2}: {ch}")
