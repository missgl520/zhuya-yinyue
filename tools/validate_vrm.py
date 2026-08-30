# -*- coding: utf-8 -*-
"""校验生成的 VRM/GLB 结构, 并输出 2D 正视线框预览 SVG"""
import struct, json, sys
from pathlib import Path

ROOT = Path(r"F:/zhuyapp/assets/vrm")

def read_glb(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[:4] == b'glTF', "not GLB"
    assert struct.unpack('<I', data[4:8])[0] == 2, "not glTF2"
    off = 12; json_bytes = None; bin_bytes = None
    while off < len(data):
        clen = struct.unpack('<I', data[off:off+4])[0]
        ctype = struct.unpack('<I', data[off+4:off+8])[0]
        chunk = data[off+8:off+8+clen]
        if ctype == 0x4E4F534A:
            json_bytes = chunk
        elif ctype == 0x004E4942:
            bin_bytes = chunk
        off += 8 + clen
        if clen % 4:
            off += 4 - (clen % 4)
    return json.loads(json_bytes.decode('utf-8')), bin_bytes

def read_accessor(gltf, bin_bytes, i):
    acc = gltf['accessors'][i]
    bv = gltf['bufferViews'][acc['bufferView']]
    ct = acc['componentType']; tp = acc['type']
    size = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[tp]
    fmt = {5126:'<f', 5125:'<I', 5123:'<H', 5121:'<B'}[ct]
    esize = struct.calcsize(fmt)
    base = bv['byteOffset']
    full = '<' + fmt[1:]*size
    out = []
    for k in range(acc['count']):
        vals = struct.unpack_from(full, bin_bytes, base + k*size*esize)
        out.append(vals if size > 1 else vals[0])
    return out

VALID_BONES = set(['hips','spine','chest','upperChest','neck','head','leftShoulder',
    'leftUpperArm','leftLowerArm','leftHand','rightShoulder','rightUpperArm','rightLowerArm',
    'rightHand','leftUpperLeg','leftLowerLeg','leftFoot','leftToes','rightUpperLeg',
    'rightLowerLeg','rightFoot','rightToes'])

def validate(path):
    gltf, binb = read_glb(path)
    rep = []
    ok = True
    ext = gltf.get('extensions', {})
    vrm = ext.get('VRM')
    rep.append(f"  扩展: {list(ext.keys()) if ext else '无'}")
    if vrm:
        rep.append(f"  VRM specVersion: {vrm.get('specVersion')}")
        hb = vrm.get('humanoid', {}).get('humanBones', [])
        rep.append(f"  humanoid 骨数: {len(hb)}")
        for e in hb:
            if e['bone'] not in VALID_BONES:
                rep.append(f"    [!] 非法骨名 {e['bone']}"); ok = False
            if e['node'] >= len(gltf['nodes']):
                rep.append(f"    [!] node 越界 {e['node']}"); ok = False
    else:
        rep.append("  [!] 缺少 VRM 扩展")
    # 检查索引越界 + NaN
    for mi, mesh in enumerate(gltf['meshes']):
        for prim in mesh['primitives']:
            pos_acc = prim['attributes']['POSITION']
            idx_acc = prim['indices']
            pos = read_accessor(gltf, binb, pos_acc)
            idx = read_accessor(gltf, binb, idx_acc)
            nv = gltf['accessors'][pos_acc]['count']
            maxi = max(idx) if idx else 0
            if maxi >= nv:
                rep.append(f"    [!] mesh {mi} 索引越界 max={maxi} nv={nv}"); ok = False
            for p in pos:
                if any(math.isnan(v) for v in p):
                    rep.append(f"    [!] mesh {mi} 含 NaN"); ok = False; break
    # 包围盒 (从所有 POSITION min/max 估算, 注意: 这里 min/max 是 bone-local, 仅看量级)
    rep.append(f"  mesh 数: {len(gltf['meshes'])}  材质数: {len(gltf['materials'])}  节点数: {len(gltf['nodes'])}")
    return ok, rep, gltf, binb

import math
ok, rep, gltf, binb = validate(ROOT / "zhuyu_chibi.vrm")
print("=== VRM 校验 ===")
print("\n".join(rep))
print("结果:", "PASS" if ok else "FAIL")

# ---------- 2D 示意图: 骨架线 + 彩色部件圆块 ----------
def world_of_node(gltf, idx):
    parent = {}
    for ni, node in enumerate(gltf['nodes']):
        for c in node.get('children', []):
            parent[c] = ni
    t = [0.0, 0.0, 0.0]; n = idx
    while n is not None:
        tn = gltf['nodes'][n].get('translation', [0, 0, 0])
        t = [t[0]+tn[0], t[1]+tn[1], t[2]+tn[2]]
        n = parent.get(n)
    return t

COL_HEX = {'face': '#FFF3D9', 'body': '#96E294', 'belly': '#FFF3D9', 'leaf': '#62C450',
           'leaf2': '#96E294', 'sword': '#38B848'}

parts_info = []   # (color, world_verts)
all_world = []
for mi, mesh in enumerate(gltf['meshes']):
    prim = mesh['primitives'][0]
    pos = read_accessor(gltf, binb, prim['attributes']['POSITION'])
    mat_idx = prim.get('material', 0)
    mat_name = gltf['materials'][mat_idx]['name'] if mat_idx < len(gltf['materials']) else 'body'
    color = COL_HEX.get(mat_name, '#96E294')
    node_idx = next((ni for ni, node in enumerate(gltf['nodes']) if node.get('mesh') == mi), None)
    tw = world_of_node(gltf, node_idx) if node_idx is not None else [0, 0, 0]
    wp = [[p[0]+tw[0], p[1]+tw[1], p[2]+tw[2]] for p in pos]
    parts_info.append((color, wp))
    all_world.extend(wp)

xs = [v[0] for v in all_world]; ys = [v[1] for v in all_world]
minx, maxx = min(xs), max(xs); miny, maxy = min(ys), max(ys)
height = maxy - miny
print(f"\n模型包围盒 X=[{minx:.2f},{maxx:.2f}] Y=[{miny:.2f},{maxy:.2f}]  总高={height:.2f}m")

W, H = 460, 560; pad = 30
s = min((W-2*pad)/(maxx-minx or 1), (H-2*pad)/(maxy-miny or 1))
def proj(p):
    return (pad + (p[0]-minx)*s, H - (pad + (p[1]-miny)*s))

svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" font-family="sans-serif">']
svg.append(f'<rect width="{W}" height="{H}" fill="#1b1f2a"/>')
svg.append(f'<text x="10" y="20" fill="#9fb3c8" font-size="13">竹剑小精灵·正视示意图(程序化代理)</text>')
svg.append(f'<text x="10" y="{H-10}" fill="#6b7c93" font-size="11">总高 {height:.2f}m · 骨骼22 · 部件{len(parts_info)} · 颜色: 脸黄/身绿/肚黄/竹叶/竹剑</text>')
gy = H - (pad + (0-miny)*s)
svg.append(f'<line x1="0" y1="{gy:.1f}" x2="{W}" y2="{gy:.1f}" stroke="#3a4250" stroke-width="1"/>')
# 骨架线
parent = {}
for ni, node in enumerate(gltf['nodes']):
    for c in node.get('children', []):
        parent[c] = ni
bone_nodes = {ni: node['name'] for ni, node in enumerate(gltf['nodes']) if node['name'] in VALID_BONES}
for ni, name in bone_nodes.items():
    p = parent.get(ni)
    if p is not None and p in bone_nodes:
        a = proj(world_of_node(gltf, ni)); b = proj(world_of_node(gltf, p))
        svg.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#5a6b80" stroke-width="1.5"/>')
# 部件圆块
for color, wp in parts_info:
    cx = sum(v[0] for v in wp)/len(wp); cy = sum(v[1] for v in wp)/len(wp); cz = sum(v[2] for v in wp)/len(wp)
    r = max(math.hypot(v[0]-cx, v[1]-cy) for v in wp)
    c = proj((cx, cy, cz)); rr = max(r*s, 1.5)
    svg.append(f'<circle cx="{c[0]:.1f}" cy="{c[1]:.1f}" r="{rr:.1f}" fill="{color}" fill-opacity="0.85" stroke="{color}" stroke-width="0.5"/>')
svg.append('</svg>')
svg_str = "\n".join(svg)
Path(ROOT / "zhuyu_preview.svg").write_text(svg_str, encoding='utf-8')
print("预览 SVG ->", ROOT / "zhuyu_preview.svg")
