from PIL import Image, ImageDraw
fs = ["f:/zhuyapp/_run_5.png", "f:/zhuyapp/_run_7.png"]  # y=436 最高颠, y=540 最低颠
imgs = [Image.open(f) for f in fs]
W, H = imgs[0].size
canvas = Image.new("RGB", (W * 2, H + 40), "white")
d = ImageDraw.Draw(canvas)
for j, (im, lbl) in enumerate(zip(imgs, ["f5 (top y=436, 蹦得最高)", "f7 (top y=540, 蹦得最低)"])):
    canvas.paste(im, (j * W, 40))
    d.text((j * W + 20, 10), lbl, fill="black")
canvas.save("f:/zhuyapp/_bengbo.png")
print("saved _bengbo.png", canvas.size)
