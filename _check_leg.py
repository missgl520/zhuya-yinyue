from PIL import Image
import numpy as np

imgs = [np.array(Image.open(f"f:/zhuyapp/_leg_{i}.png").convert("RGB"), dtype=np.int16) for i in (1,8)]
d = np.abs(imgs[1]-imgs[0]).sum(axis=2)
changed = (d>15).sum()
print("leg_1 vs leg_8 changed pixels:", changed)
print("img shape:", imgs[0].shape)

# 逐帧间差异
fs = [f"f:/zhuyapp/_leg_{i}.png" for i in range(1,9)]
arr = [np.array(Image.open(f).convert("RGB"), dtype=np.int16) for f in fs]
for i in range(len(arr)-1):
    dd = np.abs(arr[i+1]-arr[i]).sum(axis=2)
    print(f"f{i+1}^f{i+2}: changed={int((dd>15).sum())}")
