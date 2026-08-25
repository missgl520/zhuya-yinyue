from PIL import Image, ImageDraw
# 左：之前 4 帧 (半波摆动 1.0~9.5，间隔 0.15s)
# 右：极限帧 (硬编码 10/10)
fs_left = [f"f:/zhuyapp/_leg2_{i}.png" for i in (2,4,6,8)]
imgs_l = [Image.open(f) for f in fs_left]
imgs_r = [Image.open("f:/zhuyapp/_leg_max.png")]
W, H = imgs_l[0].size
canvas = Image.new("RGB", (W * 5, H + 60), "white")
d = ImageDraw.Draw(canvas)
labels = [f"half-wave f{i+2}" for i in range(4)] + ["ParamLegL=ParamLegR=10 (max)"]
for i, im in enumerate(imgs_l + imgs_r):
    canvas.paste(im, (i * W, 50))
    d.text((i * W + 20, 15), labels[i], fill="black")
d.text((20, H + 55), "结论: ParamLegL/R 从 1.0~9.5 摆动 vs 推到 moc3 上限 10，画面完全一样 → 模型 deformer 不抬脚", fill="red")
canvas.save("f:/zhuyapp/_leg_proof.png")
print("saved _leg_proof.png", canvas.size)
