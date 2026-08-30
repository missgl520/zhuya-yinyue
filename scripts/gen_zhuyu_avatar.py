#!/usr/bin/env python3
# 程序化生成「竹笌」3D 少年人形 GLB (glTF 2.0 binary)
# 分部位竹笌配色 + node 旋转走路动画。纯 stdlib，不依赖外部库。
import struct, json, math, os

OUT = r'F:\zhuyapp\assets\vrm_test\zhuyu_avatar.glb'

# ---------- 几何工具 (局部坐标，几何中心在原点) ----------
def box(w, h, d):
    x0, x1 = -w/2, w/2
    y0, y1 = -h/2, h/2
    z0, z1 = -d/2, d/2
    faces = [
        ([x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1],[0,0,1]),
        ([x1,y0,z0],[x0,y0,z0],[x0,y1,z0],[x1,y1,z0],[0,0,-1]),
        ([x1,y0,z1],[x1,y0,z0],[x1,y1,z0],[x1,y1,z1],[1,0,0]),
        ([x0,y0,z0],[x0,y0,z1],[x0,y1,z1],[x0,y1,z0],[-1,0,0]),
        ([x0,y1,z1],[x1,y1,z1],[x1,y1,z0],[x0,y1,z0],[0,1,0]),
        ([x0,y0,z0],[x1,y0,z0],[x1,y0,z1],[x0,y0,z1],[0,-1,0]),
    ]
    pos, nrm, idx = [], [], []
    for (a,b,c,d,n) in faces:
        base = len(pos)
        for v in (a,b,c,d):
            pos.append(list(v)); nrm.append(list(n))
        idx += [base,base+1,base+2, base,base+2,base+3]
    return pos, nrm, idx

def sphere(r, seg=14):
    pos, nrm, idx = [], [], []
    for i in range(seg):
        lat0 = -math.pi/2 + math.pi*i/seg
        lat1 = -math.pi/2 + math.pi*(i+1)/seg
        for j in range(seg):
            lon0 = 2*math.pi*j/seg
            lon1 = 2*math.pi*(j+1)/seg
            def pt(lat,lon):
                return [math.cos(lat)*math.cos(lon)*r, math.sin(lat)*r, math.cos(lat)*math.sin(lon)*r]
            def nf(lat,lon):
                return [math.cos(lat)*math.cos(lon), math.sin(lat), math.cos(lat)*math.sin(lon)]
            a,b,c,d = pt(lat0,lon0), pt(lat0,lon1), pt(lat1,lon1), pt(lat1,lon0)
            na,nb,nc,nd = nf(lat0,lon0), nf(lat0,lon1), nf(lat1,lon1), nf(lat1,lon0)
            base = len(pos)
            pos += [a,b,c,d]; nrm += [na,nb,nc,nd]
            idx += [base,base+1,base+2, base,base+2,base+3]
    return pos, nrm, idx

def cylinder(r, h, seg=12, top_at_zero=True):
    # 沿 y 轴；top_at_zero=True 时顶端在 y=0，几何向下延伸（用于肢体，关节在顶端）
    cy = -h/2 if top_at_zero else 0.0
    y0, y1 = cy - h/2, cy + h/2
    pos, nrm, idx = [], [], []
    for i in range(seg):
        a0 = 2*math.pi*i/seg
        a1 = 2*math.pi*(i+1)/seg
        x0, z0 = math.cos(a0)*r, math.sin(a0)*r
        x1, z1 = math.cos(a1)*r, math.sin(a1)*r
        n0, n1 = [math.cos(a0),0,math.sin(a0)], [math.cos(a1),0,math.sin(a1)]
        base = len(pos)
        pos += [[x0,y0,z0],[x1,y0,z1],[x1,y1,z1],[x0,y1,z0]]
        nrm += [n0,n1,n1,n0]
        idx += [base,base+1,base+2, base,base+2,base+3]
    ctop = len(pos); pos.append([0,y1,0]); nrm.append([0,1,0])
    cbot = len(pos); pos.append([0,y0,0]); nrm.append([0,-1,0])
    for i in range(seg):
        a0 = 2*math.pi*i/seg; a1 = 2*math.pi*(i+1)/seg
        x0, z0 = math.cos(a0)*r, math.sin(a0)*r
        x1, z1 = math.cos(a1)*r, math.sin(a1)*r
        base = len(pos)
        pos += [[x0,y1,z0],[x1,y1,z1]]; nrm += [[0,1,0],[0,1,0]]
        idx += [ctop,base,base+1]
        base = len(pos)
        pos += [[x0,y0,z0],[x1,y0,z1]]; nrm += [[0,-1,0],[0,-1,0]]
        idx += [cbot,base+1,base]
    return pos, nrm, idx

# ---------- 竹笌配色 ----------
COL = {
    'jacket': [0.96, 0.96, 0.96, 1.0],   # 白夹克 #F5F5F5
    'inner':  [0.16, 0.16, 0.16, 1.0],   # 黑 V 领内搭 #2A2A2A
    'pants':  [0.10, 0.10, 0.10, 1.0],   # 黑工装裤
    'boot':   [0.10, 0.10, 0.10, 1.0],   # 黑短靴
    'sole':   [0.90, 0.64, 0.16, 1.0],   # 暖黄鞋底 #E6A428
    'skin':   [0.96, 0.84, 0.78, 1.0],   # 肤色
    'hair':   [0.18, 0.18, 0.18, 1.0],   # 深灰黑发 #2E2E2E
    'hair_tip':[0.43, 0.66, 0.72, 1.0],  # 青蓝挑染 #6FA8B8
}

# ---------- 部件定义 (几何在原点，node.translation 定位) ----------
parts = [
    ('head',        sphere(0.13),                    'skin',     (0, 1.46, 0)),
    ('hair_cap',    sphere(0.145),                   'hair',     (0, 1.50, 0)),
    ('hair_back',   box(0.26, 0.30, 0.12),           'hair_tip', (0, 1.40, -0.07)),
    ('neck',        box(0.10, 0.10, 0.10),           'skin',     (0, 1.33, 0)),
    ('torso_jacket',box(0.36, 0.52, 0.20),           'jacket',   (0, 1.08, 0)),
    ('torso_inner', box(0.30, 0.46, 0.17),           'inner',    (0, 1.06, 0.02)),
    ('hip',         box(0.34, 0.20, 0.20),           'pants',    (0, 0.82, 0)),
    ('armL_up',     cylinder(0.062, 0.30),           'jacket',   (-0.23, 1.30, 0)),
    ('armL_lo',     cylinder(0.052, 0.28),           'skin',     (-0.23, 1.00, 0)),
    ('handL',       sphere(0.06),                    'skin',     (-0.23, 0.68, 0)),
    ('armR_up',     cylinder(0.062, 0.30),           'jacket',   ( 0.23, 1.30, 0)),
    ('armR_lo',     cylinder(0.052, 0.28),           'skin',     ( 0.23, 1.00, 0)),
    ('handR',       sphere(0.06),                    'skin',     ( 0.23, 0.68, 0)),
    ('legL_up',     cylinder(0.095, 0.40),           'pants',    (-0.09, 0.80, 0)),
    ('legL_lo',     cylinder(0.075, 0.36),           'pants',    (-0.09, 0.40, 0)),
    ('footL',       box(0.13, 0.09, 0.28),           'boot',     (-0.09, 0.045, 0.06)),
    ('soleL',       box(0.14, 0.035, 0.30),          'sole',     (-0.09, 0.018, 0.06)),
    ('legR_up',     cylinder(0.095, 0.40),           'pants',    ( 0.09, 0.80, 0)),
    ('legR_lo',     cylinder(0.075, 0.36),           'pants',    ( 0.09, 0.40, 0)),
    ('footR',       box(0.13, 0.09, 0.28),           'boot',     ( 0.09, 0.045, 0.06)),
    ('soleR',       box(0.14, 0.035, 0.30),          'sole',     ( 0.09, 0.018, 0.06)),
]

# ---------- 写入二进制缓冲 ----------
bin_data = bytearray()
accessors = []
bufferViews = []
meshes = []
materials = []
nodes = []
node_by_name = {}

def add_floats(arr):
    data = struct.pack('<%df' % len(arr), *arr)
    while len(data) % 4 != 0:
        data += b'\x00'
    offset = len(bin_data)
    bin_data.extend(data)
    bv = len(bufferViews)
    bufferViews.append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(data)})
    return bv

def add_mesh(pos, nrm, idx, mat_idx):
    flat_pos = [v for p in pos for v in p]
    flat_nrm = [v for n in nrm for v in n]
    bv_p = add_floats(flat_pos)
    bv_n = add_floats(flat_nrm)
    maxidx = max(idx)
    if maxidx < 65536:
        idata = struct.pack('<%dH' % len(idx), *idx); ctype = 5123
    else:
        idata = struct.pack('<%dI' % len(idx), *idx); ctype = 5125
    while len(idata) % 4 != 0:
        idata += b'\x00'
    bv_i = len(bufferViews)
    bufferViews.append({'buffer': 0, 'byteOffset': len(bin_data), 'byteLength': len(idata)})
    bin_data.extend(idata)
    xs = [p[0] for p in pos]; ys = [p[1] for p in pos]; zs = [p[2] for p in pos]
    ap = len(accessors); accessors.append({'bufferView': bv_p, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3', 'min': [min(xs),min(ys),min(zs)], 'max': [max(xs),max(ys),max(zs)]})
    an = len(accessors); accessors.append({'bufferView': bv_n, 'componentType': 5126, 'count': len(nrm), 'type': 'VEC3'})
    ai = len(accessors); accessors.append({'bufferView': bv_i, 'componentType': ctype, 'count': len(idx), 'type': 'SCALAR'})
    meshes.append({'primitives': [{'attributes': {'POSITION': ap, 'NORMAL': an}, 'indices': ai, 'material': mat_idx}]})
    return len(meshes) - 1

# 材质（按 COL 顺序）
mat_index = {}
for k, v in COL.items():
    materials.append({'pbrMetallicRoughness': {'baseColorFactor': v}, 'name': k, 'doubleSided': True})
    mat_index[k] = len(materials) - 1

# 部件 -> mesh + node
for name, geom, color_key, trans in parts:
    pos, nrm, idx = geom
    mesh_idx = add_mesh(pos, nrm, idx, mat_index[color_key])
    ni = len(nodes)
    nodes.append({'mesh': mesh_idx, 'translation': list(trans), 'rotation': [0,0,0,1]})
    node_by_name[name] = ni

# ---------- 走路动画 (node 旋转) ----------
times = [0.0, 0.25, 0.5, 0.75, 1.0]
ta = len(accessors)
accessors.append({'bufferView': add_floats(times), 'componentType': 5126, 'count': len(times), 'type': 'SCALAR'})

# 各肢体在 5 个关键帧的旋转角(绕 X 轴，弧度)
anim = {
    'legL_up':  [0.0,  0.6, 0.0, -0.6, 0.0],
    'legR_up':  [0.0, -0.6, 0.0,  0.6, 0.0],
    'legL_lo':  [0.0,  0.4, 0.0,  0.15, 0.0],
    'legR_lo':  [0.0,  0.15, 0.0, 0.4, 0.0],
    'armL_up':  [0.0, -0.5, 0.0,  0.5, 0.0],
    'armR_up':  [0.0,  0.5, 0.0, -0.5, 0.0],
    'torso_jacket': [0.0, 0.05, 0.0, -0.05, 0.0],
}

channels, samplers = [], []
for nm, angs in anim.items():
    quats = []
    for a in angs:
        quats += [math.sin(a/2), 0.0, 0.0, math.cos(a/2)]
    oa = len(accessors)
    accessors.append({'bufferView': add_floats(quats), 'componentType': 5126, 'count': len(angs), 'type': 'VEC4'})
    si = len(samplers)
    samplers.append({'input': ta, 'output': oa, 'interpolation': 'LINEAR'})
    channels.append({'sampler': si, 'target': {'node': node_by_name[nm], 'path': 'rotation'}})

# 根节点
root_index = len(nodes)
nodes.append({'children': list(range(len(parts)))})

gltf = {
    'asset': {'version': '2.0', 'generator': 'zhuyu-procgen'},
    'scene': 0,
    'scenes': [{'nodes': [root_index]}],
    'nodes': nodes,
    'meshes': meshes,
    'materials': materials,
    'accessors': accessors,
    'bufferViews': bufferViews,
    'buffers': [{'byteLength': len(bin_data)}],
    'animations': [{'channels': channels, 'samplers': samplers, 'name': 'walk'}],
}

json_bytes = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
while len(json_bytes) % 4 != 0:
    json_bytes += b' '
bin_bytes = bytes(bin_data)
total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
header = struct.pack('<III', 0x46546C67, 2, total)
chunk0 = struct.pack('<II', len(json_bytes), 0x4E4F534A) + json_bytes
chunk1 = struct.pack('<II', len(bin_bytes), 0x004E4942) + bin_bytes
with open(OUT, 'wb') as f:
    f.write(header + chunk0 + chunk1)

print('WROTE', OUT, 'bytes=', len(header + chunk0 + chunk1))
print('meshes=', len(meshes), 'nodes=', len(nodes), 'accessors=', len(accessors), 'anim_channels=', len(channels))
