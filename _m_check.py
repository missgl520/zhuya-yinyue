from PIL import Image
import numpy as np

fs = [f"f:/zhuyapp/_m_{i}.png" for i in range(1, 15)]
arr = [np.array(Image.open(f).convert("RGB"), dtype=np.int16) for f in fs]
H, W = arr[0].shape[:2]
print(f"img {W}x{H}")

# 1) 整体帧差 + 角色顶/底 y（用非背景色找角色范围，背景约 0xEDF7F0）
def nonbg_rows(im):
    # 背景近似 (237,247,240)；偏离 > 30 的像素视为角色
    d = np.abs(im.astype(np.int16) - np.array([237,247,240])).sum(axis=2)
    mask = d > 60
    ys = np.where(mask.any(axis=1))[0]
    return ys

# 2) 腿/脚区域变化量：角色下半身（y > 55% 高度）帧间变化
leg_changes = []
for i in range(len(arr) - 1):
    d = np.abs(arr[i+1] - arr[i]).sum(axis=2)
    ch = (d > 15)
    ys, xs = np.where(ch)
    if len(xs) == 0:
        print(f"f{i+1}^f{i+2}: NO CHANGE"); continue
    total = len(xs)
    # 下半身（腿/脚）
    leg = ch[int(H*0.55):].sum()
    cy_min, cy_max = int(ys.min()), int(ys.max())
    leg_changes.append((total, int(leg), cy_min, cy_max))
    print(f"f{i+1}^f{i+2}: changed={total}  leg(lower45%)={int(leg)}  cy[{cy_min}..{cy_max}]")

# 角色整体上下位移（用非背景最小 y 跟踪头顶）
tops = []
for im in arr:
    ys = nonbg_rows(im)
    tops.append(int(ys.min()) if len(ys) else -1)
print("tops:", tops)
print(f"top spread = {max(tops)-min(t for t in tops if t>=0)} (角色被漂移/颠簸带着上下移动)")

# 拼 4 帧对比（取变化最大的相邻几帧）
import os
sel = [0, 3, 7, 11]  # 间隔取样覆盖一个完整走路周期
canvas = Image.new("RGB", (W*len(sel), H), (237,247,240))
for j, idx in enumerate(sel):
    canvas.paste(Image.open(fs[idx]), (j*W, 0))
canvas.save("f:/zhuyapp/_m_compare.png")
print("saved _m_compare.png", canvas.size)
