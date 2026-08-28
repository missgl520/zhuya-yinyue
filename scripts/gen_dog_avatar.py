#!/usr/bin/env python3
# 程序化生成「音乐狗子」3D 宠物 GLB (glTF 2.0 binary)
# 改进版：更精致的卡通狗子，参考二次元3D建模方案的比例/色块/动画原则
import struct, json, math, os

OUT = r'F:\zhuyapp\assets\vrm_test\dog_avatar.glb'

# ---------- 几何工具 ----------
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

def sphere(r, seg=16):
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

def cylinder(r, h, seg=14, top_at_zero=True):
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

def cone(r, h, seg=12, top_at_zero=True):
    """圆锥（用于耳朵、尾巴尖等）"""
    cy = -h/2 if top_at_zero else 0.0
    y0, y1 = cy - h/2, cy + h/2
    pos, nrm, idx = [], [], []
    for i in range(seg):
        a0 = 2*math.pi*i/seg
        a1 = 2*math.pi*(i+1)/seg
        x0, z0 = math.cos(a0)*r, math.sin(a0)*r
        x1, z1 = math.cos(a1)*r, math.sin(a1)*r
        base = len(pos)
        pos += [[x0,y0,z0],[x1,y0,z1],[0,y1,0]]
        nrm += [[0,-1,0],[0,-1,0],[0,1,0]]
        idx += [base,base+1,base+2]
    cbot = len(pos); pos.append([0,y0,0]); nrm.append([0,-1,0])
    for i in range(seg):
        a0 = 2*math.pi*i/seg; a1 = 2*math.pi*(i+1)/seg
        x0, z0 = math.cos(a0)*r, math.sin(a0)*r
        x1, z1 = math.cos(a1)*r, math.sin(a1)*r
        base = len(pos)
        pos += [[x0,y0,z0],[x1,y0,z1]]; nrm += [[0,-1,0],[0,-1,0]]
        idx += [cbot,base+1,base]
    return pos, nrm, idx

# ---------- 狗子配色（参考二次元色块阴影原则） ----------
COL = {
    'fur_light':  [0.92, 0.78, 0.52, 1.0],   # 浅金（脸部/腹部）
    'fur':        [0.85, 0.68, 0.42, 1.0],   # 金色（身体/四肢）
    'fur_dark':   [0.70, 0.52, 0.28, 1.0],   # 深金（背部/耳朵/尾巴）
    'belly':      [0.96, 0.90, 0.78, 1.0],   # 米白（肚子/胸口）
    'nose':       [0.10, 0.08, 0.06, 1.0],   # 黑鼻
    'eye_white':  [0.98, 0.98, 0.98, 1.0],   # 眼白
    'eye_pupil':  [0.12, 0.08, 0.06, 1.0],   # 黑瞳孔
    'eye_highlight':[1.0, 1.0, 1.0, 1.0],     # 眼睛高光
    'ear_inner':  [0.88, 0.62, 0.58, 1.0],   # 粉耳内
    'mouth':      [0.55, 0.30, 0.25, 1.0],   # 嘴巴
    'tongue':     [0.85, 0.45, 0.50, 1.0],   # 舌头
    'collar':     [0.82, 0.25, 0.20, 1.0],   # 红项圈
    'tag':        [0.92, 0.76, 0.20, 1.0],   # 金吊牌
    'paw_pad':    [0.80, 0.55, 0.50, 1.0],   # 肉垫
}

# ---------- 狗子部件定义（改进比例：大头短身小短腿） ----------
# 坐标系：y向上，z向前（狗子面朝+z方向）
# 整体高度约 0.7m，头身比约 1:1.2（卡通风格）
parts = [
    # ===== 头部（大而圆，卡通风格）=====
    ('head',           sphere(0.18, seg=18),              'fur_light',(0, 0.52, 0.18)),
    # 头顶一撮毛
    ('hair_tuft',      cone(0.04, 0.08, seg=8),          'fur_dark', (0, 0.68, 0.18)),
    # 口鼻部（突出的吻部）
    ('snout',          sphere(0.10, seg=14),              'fur',      (0, 0.48, 0.30)),
    # 鼻子（黑色亮面）
    ('nose',           sphere(0.035, seg=12),             'nose',     (0, 0.50, 0.38)),
    # 嘴巴（微笑曲线，用扁盒子模拟）
    ('mouth',          box(0.06, 0.015, 0.01),            'mouth',    (0, 0.44, 0.37)),
    # 舌头（一点点伸出）
    ('tongue',         box(0.035, 0.02, 0.015),           'tongue',   (0, 0.425, 0.375)),
    # 左眼（眼白+瞳孔+高光）
    ('eye_white_L',    sphere(0.04, seg=12),              'eye_white',(-0.07, 0.56, 0.32)),
    ('eye_pupil_L',    sphere(0.025, seg=10),             'eye_pupil',(-0.07, 0.56, 0.35)),
    ('eye_highlight_L',sphere(0.008, seg=8),              'eye_highlight',(-0.06, 0.57, 0.365)),
    # 右眼
    ('eye_white_R',    sphere(0.04, seg=12),              'eye_white',( 0.07, 0.56, 0.32)),
    ('eye_pupil_R',    sphere(0.025, seg=10),             'eye_pupil',( 0.07, 0.56, 0.35)),
    ('eye_highlight_R',sphere(0.008, seg=8),              'eye_highlight',( 0.08, 0.57, 0.365)),
    # 眉毛（深金色小弧）
    ('brow_L',         box(0.05, 0.008, 0.01),            'fur_dark', (-0.07, 0.61, 0.33)),
    ('brow_R',         box(0.05, 0.008, 0.01),            'fur_dark', ( 0.07, 0.61, 0.33)),
    # 左垂耳（外深金+内粉）
    ('ear_L',          box(0.06, 0.18, 0.04),             'fur_dark', (-0.16, 0.50, 0.15)),
    ('ear_inner_L',    box(0.035, 0.12, 0.025),           'ear_inner',(-0.16, 0.48, 0.17)),
    # 右垂耳
    ('ear_R',          box(0.06, 0.18, 0.04),             'fur_dark', ( 0.16, 0.50, 0.15)),
    ('ear_inner_R',    box(0.035, 0.12, 0.025),           'ear_inner',( 0.16, 0.48, 0.17)),

    # ===== 身体（短而圆润）=====
    ('body',           box(0.28, 0.24, 0.38),             'fur',      (0, 0.30, -0.02)),
    # 背部（深金色，模拟色块阴影）
    ('back',           box(0.26, 0.06, 0.34),             'fur_dark', (0, 0.40, -0.02)),
    # 胸口/肚子（米白色）
    ('belly',          box(0.22, 0.16, 0.30),             'belly',    (0, 0.26, 0.04)),
    # 胸部白毛团
    ('chest_fluff',    sphere(0.10, seg=14),              'belly',    (0, 0.38, 0.16)),

    # ===== 项圈 + 吊牌 =====
    ('collar',         cylinder(0.16, 0.045, seg=16, top_at_zero=False), 'collar', (0, 0.44, 0.10)),
    ('tag',            sphere(0.03, seg=10),               'tag',      (0, 0.40, 0.22)),

    # ===== 前腿（短而粗）=====
    ('legFL',          cylinder(0.05, 0.22, seg=12),      'fur',      (-0.09, 0.20, 0.14)),
    ('pawFL',          sphere(0.055, seg=12),              'fur_dark', (-0.09, 0.06, 0.14)),
    ('paw_pad_FL',     sphere(0.025, seg=8),               'paw_pad',  (-0.09, 0.04, 0.17)),
    ('legFR',          cylinder(0.05, 0.22, seg=12),      'fur',      ( 0.09, 0.20, 0.14)),
    ('pawFR',          sphere(0.055, seg=12),              'fur_dark', ( 0.09, 0.06, 0.14)),
    ('paw_pad_FR',     sphere(0.025, seg=8),               'paw_pad',  ( 0.09, 0.04, 0.17)),

    # ===== 后腿（稍长）=====
    ('legBL',          cylinder(0.055, 0.20, seg=12),     'fur',      (-0.09, 0.18, -0.16)),
    ('pawBL',          sphere(0.055, seg=12),              'fur_dark', (-0.09, 0.06, -0.16)),
    ('legBR',          cylinder(0.055, 0.20, seg=12),     'fur',      ( 0.09, 0.18, -0.16)),
    ('pawBR',          sphere(0.055, seg=12),              'fur_dark', ( 0.09, 0.06, -0.16)),

    # ===== 尾巴（卷曲上翘）=====
    ('tail_base',      cylinder(0.035, 0.12, seg=10),     'fur_dark', (0, 0.42, -0.22)),
    ('tail_mid',       cylinder(0.03, 0.10, seg=10),      'fur_dark', (0, 0.50, -0.26)),
    ('tail_tip',       sphere(0.035, seg=10),              'fur_dark', (0, 0.56, -0.24)),
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

# 材质
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

# ---------- 动画（改进版：更自然的走路+摇尾巴+呼吸） ----------
times = [0.0, 0.25, 0.5, 0.75, 1.0]
ta = len(accessors)
accessors.append({'bufferView': add_floats(times), 'componentType': 5126, 'count': len(times), 'type': 'SCALAR'})

# 各部位关键帧旋转（弧度）
# 走路：前左+后右同步抬起，前右+后左同步抬起
# 身体上下起伏，尾巴左右摇摆，头部轻微点动
anim = {
    'legFL':    [0.0,  0.55, 0.0, -0.55, 0.0],
    'legFR':    [0.0, -0.55, 0.0,  0.55, 0.0],
    'legBL':    [0.0, -0.45, 0.0,  0.45, 0.0],
    'legBR':    [0.0,  0.45, 0.0, -0.45, 0.0],
    # 爪子跟随腿部轻微旋转
    'pawFL':    [0.0,  0.2,  0.0, -0.2,  0.0],
    'pawFR':    [0.0, -0.2,  0.0,  0.2,  0.0],
    # 身体上下起伏（呼吸+走路重心）
    'body':     [0.0,  0.04, 0.0, -0.04, 0.0],
    # 头部轻微点动
    'head':     [0.0,  0.06, 0.0, -0.06, 0.0],
    # 尾巴左右摇摆（绕Y轴）
    'tail_base':[0.0,  0.4,  0.0, -0.4,  0.0],
    'tail_mid': [0.0,  0.6,  0.0, -0.6,  0.0],
    'tail_tip': [0.0,  0.8,  0.0, -0.8,  0.0],
    # 耳朵轻微摆动
    'ear_L':    [0.0,  0.1,  0.0, -0.1,  0.0],
    'ear_R':    [0.0, -0.1,  0.0,  0.1,  0.0],
}

channels, samplers = [], []
for nm, angs in anim.items():
    if nm not in node_by_name:
        continue
    quats = []
    for a in angs:
        # 腿/身体/头绕X轴，尾巴绕Y轴，耳朵绕Z轴
        if nm.startswith('tail'):
            quats += [0.0, math.sin(a/2), 0.0, math.cos(a/2)]
        elif nm.startswith('ear'):
            quats += [0.0, 0.0, math.sin(a/2), math.cos(a/2)]
        else:
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
    'asset': {'version': '2.0', 'generator': 'dog-procgen-v2'},
    'scene': 0,
    'scenes': [{'nodes': [root_index]}],
    'nodes': nodes,
    'meshes': meshes,
    'materials': materials,
    'accessors': accessors,
    'bufferViews': bufferViews,
    'buffers': [{'byteLength': len(bin_data)}],
    'animations': [{'channels': channels, 'samplers': samplers, 'name': 'walk_wag_v2'}],
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
print('parts=', len(parts), 'materials=', len(materials))
