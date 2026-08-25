import json, os, re, glob

base = "f:/zhuyapp/assets/live2d/ren_official"
moc3 = os.path.join(base, "Ren.moc3")

# 1) 从 moc3 二进制提取所有 ParamXxx 字符串（Cubism 把参数 id 以字符串存进 moc3）
names = set()
if os.path.exists(moc3):
    data = open(moc3, "rb").read()
    for m in re.findall(rb'Param[A-Za-z0-9_]+', data):
        names.add(m.decode("ascii"))
    print(f"moc3 size={len(data)} bytes, extracted {len(names)} params")

# 2) 从所有 json (model3, motion3, exp3, pose3, physics3) 收集参数名
for f in glob.glob(base + "/**/*.json", recursive=True):
    try:
        s = open(f, encoding="utf-8").read()
    except Exception:
        continue
    for m in re.findall(r'Param[A-Za-z0-9_]+', s):
        names.add(m)

# 3) 输出与腿/脚/膝相关的
print("\n=== 腿/脚/膝/髋 相关参数 ===")
for n in sorted(names):
    if re.search(r'(Leg|Knee|Foot|Ankle|Hip|Thigh|Shin|Calf)', n):
        print("  ", n)

print("\n=== 全部参数（前 60） ===")
for n in sorted(names)[:60]:
    print("  ", n)
print(f"\n总计 {len(names)} 个参数")

# 4) model3.json FileReferences
m3 = os.path.join(base, "Ren.model3.json")
if os.path.exists(m3):
    d = json.load(open(m3, encoding="utf-8"))
    fr = d.get("FileReferences", {})
    print("\n=== model3.json FileReferences ===")
    for k, v in fr.items():
        print(f"  {k}: {v}")
