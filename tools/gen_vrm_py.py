# -*- coding: utf-8 -*-
"""
竹剑小精灵·江湖Q版 —— 纯 Python 程序化生成 VRM / GLB (零依赖, 无需 Blender)
运行: python gen_vrm_py.py
产物: F:/zhuyapp/assets/vrm/zhuyu_chibi.vrm  +  zhuyu_chibi.glb

说明: 结构合法、风格近似的"占位角色", 用于先跑通 3D 显示 / VSeeFace 直播链路。
      精细版仍需在 VRoid Studio 按参数表制作后一行替换。
要点:
  - 骨骼节点层级 = VRM humanoid 标准骨名; 各身体部件作为骨骼子节点挂载(刚性跟随, 无需蒙皮权重)
  - .vrm 用 MToon 材质 + VRM 扩展(可被 VSeeFace 识别)
  - .glb 用标准 PBR 材质(可被 model_viewer_plus / 浏览器直接预览)
"""
import struct
import json
import math
import os
from pathlib import Path

OUT_DIR = Path(r"F:/zhuyapp/assets/vrm")
OUT_DIR.mkdir(parents=True, exist_ok=True)
VRM_PATH = str(OUT_DIR / "zhuyu_chibi.vrm")
GLB_PATH = str(OUT_DIR / "zhuyu_chibi.glb")

# ============ 向量小工具 ============
def sub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def add(a, b): return (a[0]+b[0], a[1]+b[1], a[2]+b[2])
def scale(a, s): return (a[0]*s, a[1]*s, a[2]*s)
def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def norm(a):
    l = math.sqrt(dot(a, a)) or 1e-9
    return (a[0]/l, a[1]/l, a[2]/l)

# ============ 基础几何体生成 (返回 pos, nrm, idx) ============
def make_sphere(center, radius, segs=20, rings=14):
    pos, nrm, idx = [], [], []
    for i in range(rings+1):
        phi = math.pi * i / rings
        for j in range(segs):
            theta = 2*math.pi*j/segs
            n = (math.sin(phi)*math.cos(theta), math.cos(phi), math.sin(phi)*math.sin(theta))
            pos.append(add(center, scale(n, radius)))
            nrm.append(n)
    for i in range(rings):
        for j in range(segs):
            a = i*segs+j; b = i*segs+(j+1) % segs
            c = (i+1)*segs+j; d = (i+1)*segs+(j+1) % segs
            idx += [a, c, b, b, c, d]
    return pos, nrm, idx

def make_cylinder(center, axis, radius, length, segs=16):
    axis_n = norm(axis)
    up = (0, 1, 0) if abs(axis_n[1]) < 0.9 else (1, 0, 0)
    u = norm(cross(up, axis_n))
    v = norm(cross(axis_n, u))
    pos, nrm, idx = [], [], []
    half = length/2
    for j in range(segs):
        ang = 2*math.pi*j/segs
        radial = norm(add(scale(u, math.cos(ang)), scale(v, math.sin(ang))))
        pb = add(add(center, scale(axis_n, -half)), scale(radial, radius))
        pt = add(add(center, scale(axis_n, half)), scale(radial, radius))
        pos.append(pb); nrm.append(radial)
        pos.append(pt); nrm.append(radial)
    base = 0
    for j in range(segs):
        k = (j+1) % segs
        b0 = base+j*2; t0 = base+j*2+1; b1 = base+k*2; t1 = base+k*2+1
        idx += [b0, b1, t0, t0, b1, t1]
    cb = add(center, scale(axis_n, -half)); ct = add(center, scale(axis_n, half))
    ci_b = len(pos); pos.append(cb); nrm.append(scale(axis_n, -1))
    ci_t = len(pos); pos.append(ct); nrm.append(axis_n)
    for j in range(segs):
        k = (j+1) % segs
        b0 = base+j*2; b1 = base+k*2
        idx += [ci_b, b1, b0]
        t0 = base+j*2+1; t1 = base+k*2+1
        idx += [ci_t, t0, t1]
    return pos, nrm, idx

def make_box(center, dims):
    hx, hy, hz = dims[0]/2, dims[1]/2, dims[2]/2
    corners = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
               (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
    corners = [add(center, c) for c in corners]
    pos = list(corners); nrm = [(0, 0, 0)]*8; idx = []
    faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 3, 7, 4)]
    fnorm = [(0, 0, -1), (0, 0, 1), (0, -1, 0), (0, 1, 0), (1, 0, 0), (-1, 0, 0)]
    for fi, f in enumerate(faces):
        a, b, c, d = f
        idx += [a, b, c, a, c, d]
        for vv in f:
            nrm[vv] = fnorm[fi]
    return pos, nrm, idx

def make_plane(center, normal, size):
    n = norm(normal)
    up = (0, 1, 0) if abs(n[1]) < 0.9 else (1, 0, 0)
    t = norm(cross(up, n)); b = norm(cross(n, t))
    h = size/2
    p1 = add(center, add(scale(t, h), scale(b, h)))
    p2 = add(center, add(scale(t, -h), scale(b, h)))
    p3 = add(center, add(scale(t, -h), scale(b, -h)))
    p4 = add(center, add(scale(t, h), scale(b, -h)))
    return [p1, p2, p3, p4], [n, n, n, n], [0, 1, 2, 0, 2, 3]

# ============ 骨骼定义 (VRM humanoid 标准骨名, Y-up, 面朝 +Z) ============
bones = {
    'hips':          (None,           (0, 0.50, 0)),
    'spine':         ('hips',         (0, 0.08, 0)),
    'chest':         ('spine',        (0, 0.08, 0)),
    'upperChest':    ('chest',        (0, 0.05, 0)),
    'neck':          ('upperChest',   (0, 0.04, 0)),
    'head':          ('neck',         (0, 0.07, 0)),
    'leftShoulder':  ('chest',        (0.04, 0.04, 0)),
    'leftUpperArm':  ('leftShoulder', (0.08, 0, 0)),
    'leftLowerArm':  ('leftUpperArm', (0.16, 0, 0)),
    'leftHand':      ('leftLowerArm', (0.14, 0, 0)),
    'rightShoulder': ('chest',        (-0.04, 0.04, 0)),
    'rightUpperArm': ('rightShoulder', (-0.08, 0, 0)),
    'rightLowerArm': ('rightUpperArm', (-0.16, 0, 0)),
    'rightHand':     ('rightLowerArm', (-0.14, 0, 0)),
    'leftUpperLeg':  ('hips',         (0.07, -0.05, 0)),
    'leftLowerLeg':  ('leftUpperLeg', (0, -0.22, 0)),
    'leftFoot':      ('leftLowerLeg', (0, -0.22, 0)),
    'leftToes':      ('leftFoot',     (0, -0.05, 0.10)),
    'rightUpperLeg': ('hips',         (-0.07, -0.05, 0)),
    'rightLowerLeg': ('rightUpperLeg', (0, -0.22, 0)),
    'rightFoot':     ('rightLowerLeg', (0, -0.22, 0)),
    'rightToes':     ('rightFoot',    (0, -0.05, 0.10)),
}

def world_trans(name):
    t = (0.0, 0.0, 0.0); n = name
    while n is not None:
        t = add(bones[n][1], t)
        n = bones[n][0]
    return t

# ============ 配色 ============
COL = {
    'face':  (1.000, 0.953, 0.851),   # #FFF3D9 奶米黄(脸)
    'body':  (0.588, 0.886, 0.580),   # #96E294 嫩青绿(身体)
    'belly': (1.000, 0.953, 0.851),   # #FFF3D9 奶米黄(肚子)
    'leaf':  (0.384, 0.769, 0.314),   # #62C450 鲜绿(竹叶)
    'leaf2': (0.588, 0.886, 0.580),   # #96E294 嫩绿(嫩芽/耳)
    'sword': (0.220, 0.722, 0.282),   # #38B848 翡翠绿(竹剑)
}

# ============ 组装部件 ============
parts = []  # (bone_name, pos_world, nrm, idx, mat_name)

def add_part(bone, geo, mat):
    T = world_trans(bone)
    pos = [sub(p, T) for p in geo[0]]   # 转到骨骼局部空间
    parts.append((bone, pos, geo[1], geo[2], mat))

hw = world_trans('head')
hips_w = world_trans('hips')
chest_w = world_trans('chest')

# 头 (chibi 大球)
add_part('head', make_sphere(add(hw, (0, 0.12, 0)), 0.22, segs=22, rings=16), 'face')

# 躯干 (hips->chest 箱体, 嫩绿)
tc = (0, (hips_w[1]+chest_w[1])/2 + 0.03, 0)
add_part('spine', make_box(tc, (0.22, 0.28, 0.16)), 'body')

# 肚子奶黄贴片 (身体前侧 +Z)
belly_c = (tc[0], tc[1]-0.02, tc[2]+0.10)
add_part('spine', make_box(belly_c, (0.15, 0.24, 0.04)), 'belly')

# 四肢 (圆柱, 嫩绿)
def limb(bone, child_bone, radius, mat):
    a = world_trans(bone); b = world_trans(child_bone)
    axis = sub(b, a); length = math.sqrt(dot(axis, axis))
    center = ((a[0]+b[0])/2, (a[1]+b[1])/2, (a[2]+b[2])/2)
    add_part(bone, make_cylinder(center, axis, radius, length*0.95), mat)

limb('leftUpperArm', 'leftLowerArm', 0.05, 'body')
limb('leftLowerArm', 'leftHand', 0.045, 'body')
limb('rightUpperArm', 'rightLowerArm', 0.05, 'body')
limb('rightLowerArm', 'rightHand', 0.045, 'body')
limb('leftUpperLeg', 'leftLowerLeg', 0.06, 'body')
limb('leftLowerLeg', 'leftFoot', 0.05, 'body')
limb('rightUpperLeg', 'rightLowerLeg', 0.06, 'body')
limb('rightLowerLeg', 'rightFoot', 0.05, 'body')

# 手 / 脚 (小球)
for b in ['leftHand', 'rightHand', 'leftFoot', 'rightFoot']:
    add_part(b, make_sphere(world_trans(b), 0.055 if 'Hand' in b else 0.06), 'body')

# 头顶 4 片竹叶 (面片, 鲜绿)
leaf_defs = [
    (add(hw, (0, 0.32, 0)),        (0, 1, 0),    0.16, 'leaf'),
    (add(hw, (0.12, 0.29, 0)),     norm((0.6, 1, 0)), 0.13, 'leaf'),
    (add(hw, (-0.12, 0.29, 0)),    norm((-0.6, 1, 0)), 0.13, 'leaf'),
    (add(hw, (0, 0.27, -0.06)),    norm((0, 1, 0.4)), 0.10, 'leaf'),
]
for c, n, s, m in leaf_defs:
    add_part('head', make_plane(c, n, s), m)

# 额头 3 颗小嫩芽 (淡嫩绿, 朝前 +Z)
for dx, s in [(-0.06, 0.06), (0, 0.07), (0.06, 0.06)]:
    c = add(hw, (dx, 0.14, 0.33))
    add_part('head', make_plane(c, (0, 0, 1), s), 'leaf2')

# 圆精灵耳 (嫩绿, 两侧)
add_part('head', make_sphere(add(hw, (0.24, 0.04, 0)), 0.05), 'leaf2')
add_part('head', make_sphere(add(hw, (-0.24, 0.04, 0)), 0.05), 'leaf2')

# 竹剑 (右手持, 剑尖朝地面, 略偏前 +Z)
rh = world_trans('rightHand')
seg_len, seg_n = 0.11, 4
for i in range(seg_n):
    c = add(rh, (0, -(i*seg_len)-seg_len/2-0.02, 0.03))
    add_part('rightHand', make_cylinder(c, (0, -1, 0), 0.032, seg_len), 'sword')
add_part('rightHand', make_sphere(add(rh, (0, -(seg_n*seg_len)-0.02, 0.03)), 0.032), 'sword')  # 钝头
add_part('rightHand', make_cylinder(add(rh, (0, 0.03, 0)), (0, 1, 0), 0.045, 0.07), 'belly')   # 米黄剑柄

# ============ 构建 glTF 节点 / 网格 ============
nodes = []
bone_node_idx = {}
for name in bones:
    bone_node_idx[name] = len(nodes)
    nodes.append({'name': name, 'translation': list(bones[name][1]), 'children': []})
for name in bones:
    p = bones[name][0]
    if p:
        nodes[bone_node_idx[p]]['children'].append(bone_node_idx[name])

# 材质名 -> 索引
mat_names = list(COL.keys())
mat_index = {m: i for i, m in enumerate(mat_names)}

meshes_data = []  # (pos, nrm, idx, mat_idx)
for (bone, pos, nrm, idx, mat) in parts:
    nidx = len(nodes)
    nodes.append({'name': f'part_{len(nodes)}', 'mesh': len(meshes_data),
                  'translation': [0, 0, 0]})
    nodes[bone_node_idx[bone]]['children'].append(nidx)
    meshes_data.append((pos, nrm, idx, mat_index[mat]))

# ============ 打包 GLB ============
def pack_glb(nodes, meshes_data, materials, extensions_used=None, extensions=None):
    bin_parts = []
    accessors, bufferViews = [], []

    def add_blob(raw, target, comp_type, count, type_, minmax=None):
        offset = sum(len(x) for x in bin_parts)
        pad = (4 - (offset % 4)) % 4
        if pad:
            bin_parts.append(b'\x00' * pad); offset += pad
        bv = {'buffer': 0, 'byteOffset': offset, 'byteLength': len(raw)}
        if target:
            bv['target'] = target
        bufferViews.append(bv)
        acc = {'bufferView': len(bufferViews)-1, 'componentType': comp_type, 'count': count, 'type': type_}
        if minmax:
            acc['min'] = minmax[0]; acc['max'] = minmax[1]
        accessors.append(acc)
        bin_parts.append(raw)
        return len(accessors)-1

    meshes = []
    for (pos, nrm, idx, mat_idx) in meshes_data:
        pbytes = b''.join(struct.pack('<3f', *p) for p in pos)
        xs = [p[0] for p in pos]; ys = [p[1] for p in pos]; zs = [p[2] for p in pos]
        mm = ([min(xs), min(ys), min(zs)], [max(xs), max(ys), max(zs)])
        pa = add_blob(pbytes, 34962, 5126, len(pos), 'VEC3', mm)
        nbytes = b''.join(struct.pack('<3f', *n) for n in nrm)
        na = add_blob(nbytes, 34962, 5126, len(nrm), 'VEC3')
        ibytes = b''.join(struct.pack('<I', i) for i in idx)
        ia = add_blob(ibytes, 34963, 5125, len(idx), 'SCALAR')
        meshes.append({'primitives': [{'attributes': {'POSITION': pa, 'NORMAL': na},
                                       'indices': ia, 'material': mat_idx}]})

    bin_bytes = b''.join(bin_parts)
    gltf = {
        'asset': {'version': '2.0', 'generator': 'zhuyapp-proxy-0.1'},
        'scene': 0,
        'scenes': [{'nodes': [bone_node_idx['hips']]}],
        'nodes': nodes,
        'meshes': meshes,
        'materials': materials,
        'buffers': [{'byteLength': len(bin_bytes)}],
        'bufferViews': bufferViews,
        'accessors': accessors,
    }
    if extensions_used:
        gltf['extensionsUsed'] = extensions_used
        gltf['extensionsRequired'] = extensions_used
    if extensions:
        gltf['extensions'] = extensions
    return gltf, bin_bytes

def build_materials(mtoon):
    mats = []
    for m in mat_names:
        r, g, b = COL[m]
        mat = {'name': m, 'doubleSided': True, 'alphaMode': 'OPAQUE',
               'pbrMetallicRoughness': {'baseColorFactor': [r, g, b, 1.0],
                                        'metallicFactor': 0.0, 'roughnessFactor': 0.9}}
        if mtoon:
            mat['extensions'] = {
                'VRMC_materials_mtoon': {
                    'version': '1.0',
                    'baseColorFactor': [r, g, b, 1.0],
                    'shadeColorFactor': [r*0.6, g*0.6, b*0.6],
                    'outlineWidthMode': 'worldCoordinates',
                    'outlineWidthFactor': 0.012,
                }
            }
        mats.append(mat)
    return mats

def write_glb(path, gltf, bin_bytes):
    json_bytes = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
    # JSON chunk 4 字节对齐(空格填充)
    jpad = (4 - (len(json_bytes) % 4)) % 4
    json_bytes += b' ' * jpad
    bpad = (4 - (len(bin_bytes) % 4)) % 4
    bin_bytes += b'\x00' * bpad
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    with open(path, 'wb') as f:
        f.write(b'glTF'); f.write(struct.pack('<I', 2)); f.write(struct.pack('<I', total))
        f.write(struct.pack('<I', len(json_bytes))); f.write(struct.pack('<I', 0x4E4F534A))
        f.write(json_bytes)
        f.write(struct.pack('<I', len(bin_bytes))); f.write(struct.pack('<I', 0x004E4942))
        f.write(bin_bytes)

# ---- GLB (PBR, 给 app / model-viewer 预览) ----
gltf_glb, bin_glb = pack_glb(nodes, meshes_data, build_materials(mtoon=False))
write_glb(GLB_PATH, gltf_glb, bin_glb)

# ---- VRM (MToon + VRM 扩展, 给 VSeeFace / VTube Studio) ----
vrm_human = {'humanBones': [{'bone': name, 'node': bone_node_idx[name]} for name in bones]}
vrm_ext = {
    'exporterVersion': 'zhuyapp-proxy-0.1',
    'specVersion': '1.0',
    'humanoid': vrm_human,
    'meta': {
        'name': '竹剑小精灵·江湖Q版',
        'version': '1.0.0',
        'authors': ['zhuyapp'],
        'avatarPermission': 'everyone',
        'commercialUsage': 'personalNonProfit',
        'creditNotation': 'unnecessary',
        'allowRedistribution': True,
        'modification': 'allowModificationRedistribution',
    },
    'expressions': {'preset': {}},
}
gltf_vrm, bin_vrm = pack_glb(nodes, meshes_data, build_materials(mtoon=True),
                             extensions_used=['VRM'], extensions={'VRM': vrm_ext})
write_glb(VRM_PATH, gltf_vrm, bin_vrm)

print(f"[OK] VRM -> {VRM_PATH} ({os.path.getsize(VRM_PATH)} bytes)")
print(f"[OK] GLB -> {GLB_PATH} ({os.path.getsize(GLB_PATH)} bytes)")
print(f"[INFO] 部件数={len(parts)} 节点数={len(nodes)} 骨骼数={len(bones)} 材质数={len(mat_names)}")
print("DONE")
