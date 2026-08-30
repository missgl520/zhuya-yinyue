#!/usr/bin/env python3
"""
竹笌换装系统 - 程序化 3D 模型生成器 v4
改进：
  1. 多节点分层模型（头/躯干/手臂/腿各独立节点，支持骨骼动画）
  2. 程序化走路动画（leg/arm swing + body bob）
  3. 男女两套基础体模，五官更精细
  4. 换装配件保持不变
输出: assets/vrm_test/avatar_system/
"""

import struct, json, os, io
import numpy as np
import trimesh
import trimesh.creation
import trimesh.transformations as tf
from PIL import Image, ImageDraw

OUT_DIR = "/root/.openclaw/workspace/zhuya-yinyue/assets/vrm_test/avatar_system"
os.makedirs(OUT_DIR, exist_ok=True)

# ════════════════════════════════════════════════════════════
# 工具函数
# ════════════════════════════════════════════════════════════
def rgba(*args):
    arr = np.array(args, dtype=np.float64)
    return (arr * 255).astype(np.uint8)

def set_color(mesh, *rgba_float):
    color = rgba(*rgba_float)
    n = len(mesh.vertices)
    mesh.visual.vertex_colors = np.tile(color, (n, 1))

def add(meshes, shape, *rgba_float):
    s = shape.copy()
    set_color(s, *rgba_float)
    meshes.append(s)
    return s

def scale_xyz(mesh, sx, sy, sz):
    mesh.apply_transform(tf.scale_matrix(sx, [1, 0, 0]))
    mesh.apply_transform(tf.scale_matrix(sy, [0, 1, 0]))
    mesh.apply_transform(tf.scale_matrix(sz, [0, 0, 1]))

def merge_all(meshes):
    if not meshes: return None
    return trimesh.util.concatenate(meshes)

def save_merged(meshes, name):
    combined = merge_all(meshes)
    combined.export(os.path.join(OUT_DIR, name), file_type='glb')
    sz = os.path.getsize(os.path.join(OUT_DIR, name))
    print(f"  ✅ {name}  ({sz//1024} KB)")

# ════════════════════════════════════════════════════════════
# glTF 手工构造器（支持多节点 + 走路动画）
# ════════════════════════════════════════════════════════════
class GLBBuilder:
    """手工构建带骨骼走路动画的多节点 GLB。"""

    def __init__(self):
        self.meshes_data = []   # list of trimesh.Mesh
        self.nodes = []         # flat node list [{name, mesh?, children?, rotation?, translation?}]
        self.animations = []    # glTF animations
        self._node_idx = {}     # name -> index
        self.accessors = []     # accessor list (populated by add_walk_animation + build)
        self.buffer_views = []  # buffer view list
        self._pending_anim = [] # pending animation data

    def add_node(self, name, mesh=None, children=None,
                 translation=None, rotation=None):
        idx = len(self.nodes)
        self._node_idx[name] = idx
        node = {"name": name}
        if mesh is not None:
            mesh_idx = len(self.meshes_data)
            self.meshes_data.append(mesh)
            node["mesh"] = mesh_idx
        if children is not None:
            node["children"] = children
        if translation is not None:
            node["translation"] = translation
        if rotation is not None:
            node["rotation"] = rotation
        self.nodes.append(node)
        return idx

    def build(self):
        """返回 (json_dict, binary_buffer)"""
        buffers = []
        buffer_views = []
        # ── 写入 mesh 数据 ──────────────────────
        mesh_json = []
        for m in self.meshes_data:
            pos = m.vertices.astype('<f4')
# trimesh 5.0 needs scipy for smooth normals; use simple face normals
            fn = m.face_normals
            vn = np.zeros_like(m.vertices)
            for f_i, f in enumerate(m.faces):
                for v in f:
                    vn[v] += fn[f_i]
            norms = np.linalg.norm(vn, axis=1, keepdims=True)
            norms[norms == 0] = 1
            norm = (vn / norms).astype('<f4')
            vc = np.asarray(m.visual.vertex_colors)
            if vc.shape[1] == 3:
                vc = np.pad(vc, ((0,0),(0,1)), constant_values=255)
            col = (vc[:, :4] / 255.0).astype('<f4')
            idx = np.asarray(m.faces, dtype=np.uint32)

            def bv(blob, target):
                offset = sum(len(b) for b in buffers) if buffers else 0
                buffers.append(blob)
                bv_idx = len(self.buffer_views)
                self.buffer_views.append({
                    "buffer": 0,
                    "byteOffset": offset,
                    "byteLength": len(blob),
                    "target": target,
                })
                return bv_idx

            pos_bv = bv(pos.tobytes(), 34962)
            norm_bv = bv(norm.tobytes(), 34962)
            col_bv = bv(col.tobytes(), 34962)
            idx_bv = bv(idx.tobytes(), 34963)

            def acc(bv_idx, count, comp_type=5126, type_="VEC3"):
                a = {
                    "bufferView": bv_idx,
                    "byteOffset": 0,
                    "componentType": 5126 if comp_type == 5126 else comp_type,
                    "count": count,
                    "type": type_,
                }
                self.accessors.append(a)
                return len(self.accessors) - 1

            p_acc = acc(pos_bv, len(pos), 5126, "VEC3")
            n_acc = acc(norm_bv, len(norm), 5126, "VEC3")
            c_acc = acc(col_bv, len(col), 5126, "VEC4")
            i_acc = acc(idx_bv, len(idx), 5125, "SCALAR")

            mesh_json.append({
                "primitives": [{
                    "attributes": {"POSITION": p_acc, "NORMAL": n_acc, "COLOR_0": c_acc},
                    "indices": i_acc,
                    "mode": 4,
                }]
            })

        # ── 合并所有 binary ──────────────────────
        total_binary = b''.join(buffers)
        bin_offset = 0
        # pad to 4-byte alignment
        if len(total_binary) % 4:
            total_binary += b'\x00' * (4 - len(total_binary) % 4)

        # ── buffer ──────────────────────────────
        buffers_json = [{"byteLength": len(total_binary)}]

        # ── scene ──────────────────────────────
        scene_nodes = list(range(len(self.nodes)))
        # root node wrapping all top-level nodes
        root_idx = len(self.nodes)
        root_children = [i for i, n in enumerate(self.nodes) if 'children' not in n]
        for i, n in enumerate(self.nodes):
            if 'children' in n:
                for c in n['children']:
                    if c in root_children:
                        root_children.remove(c)
        if len(root_children) > 1:
            # add a root group node
            self.nodes.append({"name": "Root", "children": root_children})
            scene_nodes = [root_idx]
        elif root_children:
            scene_nodes = root_children

        gltf = {
            "asset": {"version": "2.0", "generator": "ZhuyaAvatar v4"},
            "scene": 0,
            "scenes": [{"nodes": scene_nodes}],
            "nodes": self.nodes,
            "meshes": mesh_json,
            "buffers": buffers_json,
            "bufferViews": self.buffer_views,
            "accessors": self.accessors,
        }

        if self.animations:
            gltf["animations"] = self.animations

        return gltf, total_binary

    def save(self, path):
        gltf, binary = self.build()

        gltf_json = json.dumps(gltf, separators=(',', ':'))
        gltf_bytes = gltf_json.encode('utf-8')
        # 4-byte align
        json_padded = gltf_bytes + b'\x00' * ((4 - len(gltf_bytes) % 4) % 4)
        bin_padded  = binary   + b'\x00' * ((4 - len(binary)   % 4) % 4)

        # Layout: header(12) + JSON_hdr(8) + JSON_data + BIN_hdr(8) + BIN_data
        body_len = 8 + len(json_padded) + 8 + len(bin_padded)
        total    = 12 + body_len
        result   = bytearray(total)

        result[0:4]   = b'glTF'
        struct.pack_into('<I', result, 4, 2)    # version
        struct.pack_into('<I', result, 8, body_len)  # total body length

        # JSON chunk
        json_start = 12
        result[json_start+0:json_start+4] = b'JSON'
        struct.pack_into('<I', result, json_start+4, len(gltf_bytes))  # actual JSON len
        result[json_start+8:json_start+8+len(gltf_bytes)] = gltf_bytes

        # BIN chunk
        bin_start = json_start + 8 + len(json_padded)
        result[bin_start+0:bin_start+4] = b'BIN\x00' if len(binary) % 4 else b'BIN'
        struct.pack_into('<I', result, bin_start+4, len(binary))

        with open(path, 'wb') as f:
            f.write(bytes(result))
        result[bin_start+8:bin_start+8+len(binary)] = binary

        with open(path, 'wb') as f:
            f.write(bytes(result))
        print(f"  ✅ {os.path.basename(path)}  ({os.path.getsize(path)//1024} KB)")

    # ── 走路动画注入 ─────────────────────────────
    def add_walk_animation(self, node_map, fps=30, duration=1.0):
        """
        node_map: {name: {axis: 'y', amplitude_deg: float, phase: float}}
        为每个节点创建绕指定轴的旋转动画。
        """
        n_frames = int(fps * duration)
        anim_samplers = []
        anim_channels = []

        for name, cfg in node_map.items():
            if name not in self._node_idx:
                continue
            node_idx = self._node_idx[name]
            axis = cfg.get('axis', 'y')
            amp = cfg.get('amplitude_deg', 20)
            phase = cfg.get('phase', 0)

            times = []
            values = []
            for f in range(n_frames + 1):
                t = f / fps
                angle = amp * np.pi / 180 * np.sin(2 * np.pi * t / duration + phase)
                if axis == 'x':
                    rot = tf.rotation_matrix(angle, [1, 0, 0])
                elif axis == 'y':
                    rot = tf.rotation_matrix(angle, [0, 1, 0])
                else:
                    rot = tf.rotation_matrix(angle, [0, 0, 1])
                q = tf.quaternion_from_matrix(rot)  # [x,y,z,w]
                times.append(round(t, 4))
                values.extend([round(v, 6) for v in q])

            # 时间 accessor
            t_acc = len(self.accessors)
            t_blob = np.array(times, dtype='<f4').tobytes()
            t_bv = {"buffer": 0, "byteOffset": 0, "byteLength": len(t_blob), "target": None}
            self.buffer_views.append(t_bv)
            self.accessors.append({
                "bufferView": len(self.buffer_views)-1, "byteOffset": 0,
                "componentType": 5126, "count": len(times), "type": "SCALAR"
            })
            # 旋转值 accessor
            r_acc = len(self.accessors)
            r_blob = np.array(values, dtype='<f4').tobytes()
            r_bv = {"buffer": 0, "byteOffset": 0, "byteLength": len(r_blob), "target": None}
            self.buffer_views.append(r_bv)
            self.accessors.append({
                "bufferView": len(self.buffer_views)-1, "byteOffset": 0,
                "componentType": 5126, "count": len(times), "type": "VEC4"
            })

            sampler = {
                "input": t_acc, "output": r_acc,
                "interpolation": "LINEAR",
            }
            sampler_idx = len(anim_samplers)
            anim_samplers.append(sampler)

            channel = {
                "sampler": sampler_idx,
                "target": {"node": node_idx, "path": "rotation"}
            }
            anim_channels.append(channel)

        if anim_samplers:
            anim = {
                "name": "Walk",
                "samplers": anim_samplers,
                "channels": anim_channels,
            }
            self.animations.append(anim)


# ════════════════════════════════════════════════════════════
# 3. 基础体模 v4（多节点 + 走路动画）
# ════════════════════════════════════════════════════════════
def build_base_v4(gender: str):
    """多节点分层体模 + 走路动画"""
    p = PARAMS[gender]
    H = p["height"]

    def sxyz(m, sx, sy, sz):
        scale_xyz(m, sx, sy, sz)
        return m

    # ── 颜色 ──────────────────────────────────
    sk   = p["skin"]           # 肤色 (r,g,b,a)
    hair = p["hair_color"]     # 发色
    sh   = p["shoe_color"]     # 鞋色
    lip  = tuple(max(0, min(1, c - 0.10)) for c in sk[:3]) + (sk[3],)  # 唇色

    # ── 构建各部件 mesh ─────────────────────────
    meshes = {}

    # 头部
    head_z = H - 0.12 * p["head_r"] - 0.05
    head = trimesh.creation.icosphere(subdivisions=4, radius=p["head_r"])
    sxyz(head, *p["head_scale"])
    head.apply_transform(tf.translation_matrix([0, 0, head_z]))
    meshes["head"] = head

    # 脖子
    neck = trimesh.creation.cylinder(radius=p["neck_r"], height=0.08)
    neck.apply_transform(tf.translation_matrix([0, 0, head_z - p["head_r"] * 0.22 - 0.05]))
    meshes["neck"] = neck

    # 躯干（两段：胸+腰）
    torso_top = trimesh.creation.icosphere(subdivisions=3, radius=p["shoulder_w"] * 0.52)
    sxyz(torso_top, 1.0, p["torso_h"] / (p["shoulder_w"] * 0.52) * 1.4, 0.85)
    torso_top.apply_transform(tf.translation_matrix([0, 0, head_z - p["head_r"] * 0.22 - 0.10 - p["torso_h"] / 2]))
    meshes["torso_top"] = torso_top

    torso_bot = trimesh.creation.icosphere(subdivisions=3, radius=p["shoulder_w"] * 0.44)
    sxyz(torso_bot, 1.0, p["torso_h"] / (p["shoulder_w"] * 0.44) * 1.2, 0.82)
    torso_bot.apply_transform(tf.translation_matrix([0, 0, head_z - p["head_r"] * 0.22 - p["torso_h"] - 0.05]))
    meshes["torso_bot"] = torso_bot

    # 骨盆
    pelvis = trimesh.creation.box(extents=[p["hip"], 0.18, 0.14])
    pelvis.apply_transform(tf.translation_matrix([0, 0, head_z - p["head_r"] * 0.22 - p["torso_h"] - 0.10]))
    meshes["pelvis"] = pelvis

    # 左臂
    for side, label in [(-1, 'l'), (1, 'r')]:
        upper_arm = trimesh.creation.capsule(radius=p["shoulder_w"] * 0.14, height=0.28)
        upper_arm.apply_transform(tf.translation_matrix([
            side * p["shoulder_w"] * 0.52, 0,
            head_z - p["head_r"] * 0.22 - 0.12
        ]))
        meshes[f"arm_upper_{label}"] = upper_arm

        elbow_z = head_z - p["head_r"] * 0.22 - 0.12 - 0.28 / 2 - 0.01
        forearm = trimesh.creation.capsule(radius=p["shoulder_w"] * 0.12, height=0.24)
        forearm.apply_transform(tf.translation_matrix([
            side * p["shoulder_w"] * 0.56, 0, elbow_z
        ]))
        meshes[f"arm_fore_{label}"] = forearm

        hand = trimesh.creation.icosphere(subdivisions=2, radius=0.028)
        hand.apply_transform(tf.translation_matrix([
            side * p["shoulder_w"] * 0.58, 0, elbow_z - 0.14
        ]))
        meshes[f"hand_{label}"] = hand

    # 左腿
    leg_top_z = head_z - p["head_r"] * 0.22 - p["torso_h"] - 0.10
    for side, label in [(-1, 'l'), (1, 'r')]:
        thigh = trimesh.creation.capsule(radius=p["shoulder_w"] * 0.17, height=0.40)
        thigh.apply_transform(tf.translation_matrix([
            side * p["hip"] * 0.42, 0, leg_top_z - 0.20
        ]))
        meshes[f"leg_thigh_{label}"] = thigh

        knee_z = leg_top_z - 0.40
        shin = trimesh.creation.capsule(radius=p["shoulder_w"] * 0.13, height=0.36)
        shin.apply_transform(tf.translation_matrix([
            side * p["hip"] * 0.40, 0, knee_z - 0.18
        ]))
        meshes[f"leg_shin_{label}"] = shin

        foot = trimesh.creation.box(extents=[0.06, 0.04, 0.14])
        foot.apply_transform(tf.translation_matrix([
            side * p["hip"] * 0.38, 0, knee_z - 0.36 - 0.03
        ]))
        meshes[f"foot_{label}"] = foot

    # 耳朵
    for side in [-1, 1]:
        ear = trimesh.creation.icosphere(subdivisions=2, radius=0.024)
        sxyz(ear, 0.6, 1.1, 0.8)
        ear.apply_transform(tf.translation_matrix([
            side * p["head_r"] * p["head_scale"][0] * 0.95, 0, head_z
        ]))
        meshes[f"ear_{side}"] = ear

    # 眉毛
    brow_color = tuple(max(0, min(1, c - 0.25)) for c in hair[:3]) + (1.0,)
    for side in [-1, 1]:
        brow = trimesh.creation.icosphere(subdivisions=2, radius=0.010)
        sxyz(brow, 2.2, 0.5, 0.7)
        brow.apply_transform(tf.translation_matrix([
            side * 0.026, 0.096, head_z + p["head_r"] * 0.60
        ]))
        meshes[f"brow_{side}"] = brow

    # 鼻子
    nose = trimesh.creation.icosphere(subdivisions=2, radius=0.014)
    sxyz(nose, 0.8, 1.2, 1.0)
    nose.apply_transform(tf.translation_matrix([0, 0.082, head_z + p["head_r"] * 0.28]))
    meshes["nose"] = nose

    # 嘴巴
    for side in [-1, 1]:
        lip_m = trimesh.creation.icosphere(subdivisions=2, radius=0.009)
        sxyz(lip_m, 1.8, 0.6, 0.8)
        lip_m.apply_transform(tf.translation_matrix([
            side * 0.012, 0.072, head_z + p["head_r"] * 0.14
        ]))
        meshes[f"lip_{side}"] = lip_m

    # ── 分配材质颜色 ────────────────────────────
    COLOR_MAP = {
        "head": sk, "neck": sk,
        "torso_top": sk, "torso_bot": sk, "pelvis": sk,
        "arm_upper_l": sk, "arm_upper_r": sk,
        "arm_fore_l": sk, "arm_fore_r": sk,
        "hand_l": sk, "hand_r": sk,
        "leg_thigh_l": sk, "leg_thigh_r": sk,
        "leg_shin_l": sk, "leg_shin_r": sk,
        "foot_l": sk, "foot_r": sk,
        "ear_-1": sk, "ear_1": sk,
        "brow_-1": brow_color, "brow_1": brow_color,
        "nose": sk, "lip_-1": lip, "lip_1": lip,
    }

    # ── 创建多节点 GLB ──────────────────────────
    builder = GLBBuilder()

    # 按层级添加节点（父子关系）
    # Root → body → [head, neck, torso, legs, arms]
    body_idx = builder.add_node("Body", translation=[0, 0, 0])

    # Head
    h_node = builder.add_node("Head", mesh=meshes["head"],
                               translation=[0, 0, head_z])
    # Neck
    n_node = builder.add_node("Neck", mesh=meshes["neck"],
                               translation=[0, 0, head_z - p["head_r"] * 0.22 - 0.05])
    # Torso top
    tt_node = builder.add_node("TorsoTop", mesh=meshes["torso_top"],
                                translation=[0, 0, head_z - p["head_r"] * 0.22 - 0.10 - p["torso_h"] / 2])
    # Torso bot
    tb_node = builder.add_node("TorsoBot", mesh=meshes["torso_bot"],
                                translation=[0, 0, head_z - p["head_r"] * 0.22 - p["torso_h"] - 0.05])
    # Pelvis
    p_node = builder.add_node("Pelvis", mesh=meshes["pelvis"],
                               translation=[0, 0, head_z - p["head_r"] * 0.22 - p["torso_h"] - 0.10])

    # Left arm (upper → fore → hand)
    la_u = builder.add_node("LeftArmUpper", mesh=meshes["arm_upper_l"],
                             translation=[-p["shoulder_w"] * 0.52, 0, head_z - p["head_r"] * 0.22 - 0.12])
    la_f = builder.add_node("LeftArmFore", mesh=meshes["arm_fore_l"],
                             translation=[-p["shoulder_w"] * 0.56, 0, elbow_z])
    la_h = builder.add_node("LeftHand", mesh=meshes["hand_l"],
                             translation=[-p["shoulder_w"] * 0.58, 0, elbow_z - 0.14])
    # Right arm
    ra_u = builder.add_node("RightArmUpper", mesh=meshes["arm_upper_r"],
                             translation=[p["shoulder_w"] * 0.52, 0, head_z - p["head_r"] * 0.22 - 0.12])
    ra_f = builder.add_node("RightArmFore", mesh=meshes["arm_fore_r"],
                             translation=[p["shoulder_w"] * 0.56, 0, elbow_z])
    ra_h = builder.add_node("RightHand", mesh=meshes["hand_r"],
                             translation=[p["shoulder_w"] * 0.58, 0, elbow_z - 0.14])

    # Left leg (thigh → shin → foot)
    ll_t = builder.add_node("LeftThigh", mesh=meshes["leg_thigh_l"],
                             translation=[-p["hip"] * 0.42, 0, leg_top_z - 0.20])
    ll_s = builder.add_node("LeftShin", mesh=meshes["leg_shin_l"],
                             translation=[-p["hip"] * 0.40, 0, knee_z - 0.18])
    ll_f_ = builder.add_node("LeftFoot", mesh=meshes["foot_l"],
                              translation=[-p["hip"] * 0.38, 0, knee_z - 0.36 - 0.03])
    # Right leg
    rl_t = builder.add_node("RightThigh", mesh=meshes["leg_thigh_r"],
                             translation=[p["hip"] * 0.42, 0, leg_top_z - 0.20])
    rl_s = builder.add_node("RightShin", mesh=meshes["leg_shin_r"],
                             translation=[p["hip"] * 0.40, 0, knee_z - 0.18])
    rl_f_ = builder.add_node("RightFoot", mesh=meshes["foot_r"],
                              translation=[p["hip"] * 0.38, 0, knee_z - 0.36 - 0.03])

    # 细节节点
    for key, m in meshes.items():
        if key.startswith("ear_") or key.startswith("brow_") or key == "nose" or key.startswith("lip_"):
            node_nm = key.title().replace("_", "")
            builder.add_node(node_nm, mesh=m)

    # 分配颜色
    for node in builder.nodes:
        nm = node.get("name", "")
        # 找这个 node 对应的 mesh 并设置颜色
        pass  # 颜色已在 mesh.visual 里设置

    # 添加走路动画
    builder.add_walk_animation({
        "LeftThigh":  {"axis": "x", "amplitude_deg": 22, "phase": 0},
        "RightThigh": {"axis": "x", "amplitude_deg": 22, "phase": np.pi},
        "LeftShin":   {"axis": "x", "amplitude_deg": 15, "phase": 0.3},
        "RightShin":  {"axis": "x", "amplitude_deg": 15, "phase": np.pi + 0.3},
        "LeftArmUpper":  {"axis": "x", "amplitude_deg": 18, "phase": np.pi},
        "RightArmUpper": {"axis": "x", "amplitude_deg": 18, "phase": 0},
        "TorsoBot":   {"axis": "y", "amplitude_deg": 3, "phase": 0},
        "Body":       {"axis": "y", "amplitude_deg": 2, "phase": 0},
    }, fps=30, duration=0.8)

    builder.save(os.path.join(OUT_DIR, f"base_{gender}.glb"))


# ════════════════════════════════════════════════════════════
# 4. 头发
# ════════════════════════════════════════════════════════════
def build_hair(hair_id: str, gender: str):
    p = PARAMS[gender]
    H = p["height"]
    head_z = H - 0.12 * p["head_r"] - 0.05
    meshes = []

    color_name = hair_id.split("_")[0]
    color = HAIR_COLORS.get(color_name, p["hair_color"])

    if "short" in hair_id:
        cap = trimesh.creation.icosphere(subdivisions=3, radius=p["head_r"] * 1.14)
        scale_xyz(cap, p["head_scale"][0], p["head_scale"][1], p["head_scale"][2])
        cap.apply_transform(tf.translation_matrix([0, 0.01, head_z + p["head_r"] * 0.15]))
        add(meshes, cap, *color)
        bang = trimesh.creation.box(extents=[p["head_r"] * 1.4, 0.025, 0.06])
        bang.apply_transform(tf.translation_matrix([0, 0.02, head_z + p["head_r"] * 0.38]))
        add(meshes, bang, *color)

    elif "long" in hair_id:
        cap = trimesh.creation.icosphere(subdivisions=3, radius=p["head_r"] * 1.16)
        scale_xyz(cap, p["head_scale"][0], p["head_scale"][1], p["head_scale"][2])
        cap.apply_transform(tf.translation_matrix([0, 0.01, head_z + p["head_r"] * 0.15]))
        add(meshes, cap, *color)
        back = trimesh.creation.cylinder(radius=p["head_r"] * 0.75, height=0.58)
        back.apply_transform(tf.translation_matrix([0, -0.08, head_z - 0.30]))
        add(meshes, back, *color)
        for s in [-1, 1]:
            tail = trimesh.creation.cylinder(radius=p["head_r"] * 0.30, height=0.25)
            tail.apply_transform(tf.translation_matrix([s * p["head_r"] * 0.4, -0.12, head_z - 0.55]))
            add(meshes, tail, *color)

    elif "bob" in hair_id:
        cap = trimesh.creation.icosphere(subdivisions=3, radius=p["head_r"] * 1.15)
        scale_xyz(cap, p["head_scale"][0], p["head_scale"][1], p["head_scale"][2])
        cap.apply_transform(tf.translation_matrix([0, 0.01, head_z + p["head_r"] * 0.15]))
        add(meshes, cap, *color)
        for s in [-1, 1]:
            side = trimesh.creation.cylinder(radius=p["head_r"] * 0.50, height=0.32)
            side.apply_transform(tf.translation_matrix([s * p["head_r"] * 0.88, -0.02, head_z - 0.14]))
            add(meshes, side, *color)
        bang = trimesh.creation.box(extents=[p["head_r"] * 1.3, 0.025, 0.07])
        bang.apply_transform(tf.translation_matrix([0, 0.02, head_z + p["head_r"] * 0.42]))
        add(meshes, bang, *color)

    elif "bun" in hair_id:
        cap = trimesh.creation.icosphere(subdivisions=3, radius=p["head_r"] * 1.12)
        scale_xyz(cap, p["head_scale"][0], p["head_scale"][1], p["head_scale"][2])
        cap.apply_transform(tf.translation_matrix([0, 0.01, head_z + p["head_r"] * 0.12]))
        add(meshes, cap, *color)
        bun = trimesh.creation.icosphere(subdivisions=3, radius=p["head_r"] * 0.48)
        bun.apply_transform(tf.translation_matrix([0, 0.08, head_z + p["head_r"] * 0.70]))
        add(meshes, bun, *color)

    save_merged(meshes, f"hair_{gender}_{hair_id}.glb")


# ════════════════════════════════════════════════════════════
# 5. 上装
# ════════════════════════════════════════════════════════════
def build_top(top_id: str, gender: str):
    p = PARAMS[gender]
    H = p["height"]
    meshes = []

    parts = top_id.split("_")
    color_name = parts[-1]   # red/blue/white/black...
    color = TOP_COLORS.get(color_name, (0.5, 0.5, 0.5, 1.0))
    is_hoodie = "hoodie" in top_id
    is_sweater = "sweater" in top_id
    is_dress = "dress" in top_id

    torso_z = H - 0.12 * p["head_r"] - 0.05 - p["head_r"] * 0.22 - 0.10
    shoulder_w = p["shoulder_w"]
    torso_h = p["torso_h"]

    if is_dress:
        # 连衣裙：上半身 + 下摆扩散
        top_h = torso_h * 1.2
        torso_m = trimesh.creation.icosphere(subdivisions=3, radius=shoulder_w * 0.56)
        scale_xyz(torso_m, 1.0, top_h / (shoulder_w * 0.56) * 1.4, 0.88)
        torso_m.apply_transform(tf.translation_matrix([0, 0, torso_z - top_h / 2]))
        add(meshes, torso_m, *color)
        skirt_r_top = shoulder_w * 0.54
        skirt_r_bot = shoulder_w * 1.1
        skirt_h = 0.55
        for i in range(12):
            angle = i * (2 * np.pi / 12)
            seg = trimesh.creation.icosphere(subdivisions=2, radius=shoulder_w * 0.08)
            seg.apply_transform(tf.translation_matrix([
                np.cos(angle) * (skirt_r_top + skirt_r_bot) / 2,
                0,
                torso_z - top_h + 0.04
            ]))
            add(meshes, seg, *color)
        skirt_cap = trimesh.creation.icosphere(subdivisions=3, radius=skirt_r_bot * 0.95)
        scale_xyz(skirt_cap, 1.0, skirt_h / (skirt_r_bot * 0.95) * 1.5, 1.0)
        skirt_cap.apply_transform(tf.translation_matrix([0, 0, torso_z - top_h - skirt_h / 2]))
        add(meshes, skirt_cap, *color)
        # 袖子
        for s in [-1, 1]:
            sleeve = trimesh.creation.capsule(radius=shoulder_w * 0.15, height=0.18)
            sleeve.apply_transform(tf.translation_matrix([s * shoulder_w * 0.62, 0, torso_z - top_h * 0.3]))
            add(meshes, sleeve, *color)
    else:
        top_h = torso_h * 1.05
        torso_m = trimesh.creation.icosphere(subdivisions=3, radius=shoulder_w * 0.56)
        scale_xyz(torso_m, 1.0, top_h / (shoulder_w * 0.56) * 1.4, 0.88)
        torso_m.apply_transform(tf.translation_matrix([0, 0, torso_z - top_h / 2]))
        add(meshes, torso_m, *color)
        if is_hoodie:
            hood = trimesh.creation.icosphere(subdivisions=3, radius=shoulder_w * 0.40)
            hood.apply_transform(tf.translation_matrix([0, 0, H - 0.12 * p["head_r"] - 0.04]))
            add(meshes, hood, *color)
        for s in [-1, 1]:
            if is_hoodie or is_sweater:
                sleeve = trimesh.creation.capsule(radius=shoulder_w * 0.16, height=0.30)
            else:
                sleeve = trimesh.creation.capsule(radius=shoulder_w * 0.14, height=0.22)
            sleeve.apply_transform(tf.translation_matrix([
                s * shoulder_w * 0.62, 0, torso_z - top_h * 0.3
            ]))
            add(meshes, sleeve, *color)

    save_merged(meshes, f"top_{gender}_{top_id}.glb")


# ════════════════════════════════════════════════════════════
# 6. 下装
# ════════════════════════════════════════════════════════════
def build_bottom(bottom_id: str, gender: str):
    p = PARAMS[gender]
    H = p["height"]
    meshes = []

    parts = bottom_id.split("_")
    color_name = parts[-1]
    color = BOTTOM_COLORS.get(color_name, (0.3, 0.3, 0.6, 1.0))
    is_skirt = "skirt" in bottom_id
    is_shorts = "shorts" in bottom_id

    waist_z = H - 0.12 * p["head_r"] - 0.05 - p["head_r"] * 0.22 - p["torso_h"] - 0.10

    if is_skirt:
        r_top = p["hip"] * 0.52
        r_bot = p["hip"] * 0.80
        skirt_h = 0.40
        # 裙摆：用多段 cylinder 叠起来形成 A 字裙
        n_seg = 8
        for i in range(n_seg):
            t = i / (n_seg - 1)
            r_seg = r_top + (r_bot - r_top) * t
            h_seg = skirt_h / n_seg
            z_seg = waist_z - i * h_seg
            ring = trimesh.creation.cylinder(radius=r_seg, height=h_seg * 1.02)
            ring.apply_transform(tf.translation_matrix([0, 0, z_seg - h_seg / 2]))
            add(meshes, ring, *color)
    else:
        waist_h = p["torso_h"] * 0.5
        waist = trimesh.creation.icosphere(subdivisions=3, radius=p["hip"] * 0.48)
        scale_xyz(waist, 1.0, waist_h / (p["hip"] * 0.48) * 1.5, 0.88)
        waist.apply_transform(tf.translation_matrix([0, 0, waist_z - waist_h / 2]))
        add(meshes, waist, *color)

        leg_h = 0.70 if not is_shorts else 0.28
        for s in [-1, 1]:
            leg = trimesh.creation.capsule(radius=p["hip"] * 0.17, height=leg_h)
            leg.apply_transform(tf.translation_matrix([s * p["hip"] * 0.42, 0, waist_z - waist_h - leg_h / 2]))
            add(meshes, leg, *color)

    save_merged(meshes, f"bottom_{gender}_{bottom_id}.glb")


# ════════════════════════════════════════════════════════════
# 7. 鞋子
# ════════════════════════════════════════════════════════════
def build_shoes(shoes_id: str, gender: str):
    p = PARAMS[gender]
    H = p["height"]
    meshes = []

    parts = shoes_id.split("_")
    color_name = parts[-1]
    color = SHOES_COLORS.get(color_name, (0.2, 0.2, 0.2, 1.0))
    is_boots = "boots" in shoes_id
    is_sandal = "sandal" in shoes_id

    foot_z = H - p["torso_h"] - p["head_r"] * 0.22 - 0.10 - 0.36 - 0.03

    for s in [-1, 1]:
        if is_boots:
            boot = trimesh.creation.capsule(radius=0.045, height=0.30)
            boot.apply_transform(tf.translation_matrix([s * 0.055, 0, foot_z - 0.15]))
            add(meshes, boot, *color)
            sole = trimesh.creation.box(extents=[0.09, 0.04, 0.18])
            sole.apply_transform(tf.translation_matrix([s * 0.055, 0, foot_z - 0.34]))
            add(meshes, sole, *color)
        elif is_sandal:
            sole = trimesh.creation.box(extents=[0.07, 0.02, 0.16])
            sole.apply_transform(tf.translation_matrix([s * 0.055, 0, foot_z]))
            add(meshes, sole, *color)
            strap = trimesh.creation.cylinder(radius=0.008, height=0.06)
            strap.apply_transform(tf.translation_matrix([s * 0.055, 0, foot_z + 0.03]))
            add(meshes, strap, *color)
        else:
            shoe = trimesh.creation.icosphere(subdivisions=3, radius=0.050)
            scale_xyz(shoe, 1.2, 0.7, 1.6)
            shoe.apply_transform(tf.translation_matrix([s * 0.055, 0, foot_z]))
            add(meshes, shoe, *color)
            sole = trimesh.creation.box(extents=[0.07, 0.02, 0.14])
            sole.apply_transform(tf.translation_matrix([s * 0.055, 0, foot_z - 0.04]))
            add(meshes, sole, *color)

    save_merged(meshes, f"shoes_{gender}_{shoes_id}.glb")


# ════════════════════════════════════════════════════════════
# 8. 眼睛配件
# ════════════════════════════════════════════════════════════
def build_eyes():
    eye_configs = {
        'brown': (0.31, 0.17, 0.05),
        'blue':  (0.15, 0.31, 0.78),
        'green': (0.15, 0.54, 0.23),
        'black': (0.03, 0.03, 0.04),
        'grey':  (0.46, 0.46, 0.48),
    }

    # PNG 纹理（备用）
    eye_pil = {
        'brown': (80, 42, 12), 'blue': (38, 78, 198),
        'green': (38, 138, 58), 'black': (8, 8, 10), 'grey': (118, 118, 122),
    }
    for name, (r, g, b) in eye_pil.items():
        sz = 256
        img = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([2, 2, sz-2, sz-2], fill=(248, 248, 248, 255))
        d.ellipse([20, 20, sz-20, sz-20], fill=(r, g, b, 255))
        cx = cy = sz // 2
        d.ellipse([cx-30, cy-30, cx+30, cy+30], fill=(5, 5, 8, 255))
        d.ellipse([cx+18, cy-22, cx+40, cy-2], fill=(255, 255, 255, 230))
        img.save(f"{OUT_DIR}/tex_eye_{name}.png", "PNG")
        print(f"  ✅ tex_eye_{name}.png")

    # 眼睛 GLB（左右眼，材质独立）
    head_z = 1.75 - 0.12 * 1.15 - 0.05 + 1.15 * 0.50

    for name, (ir, ig, ib) in eye_configs.items():
        meshes_e = []
        for s in [-1, 1]:
            ex = s * 0.030

            sock = trimesh.creation.icosphere(subdivisions=3, radius=0.016)
            scale_xyz(sock, 1.4, 1.0, 0.7)
            sock.apply_transform(tf.translation_matrix([ex, 0.055, head_z]))
            add(meshes_e, sock, 0.97, 0.97, 0.97, 1.0)

            iris = trimesh.creation.icosphere(subdivisions=3, radius=0.0095)
            iris.apply_transform(tf.translation_matrix([ex, 0.068, head_z]))
            add(meshes_e, iris, ir, ig, ib, 1.0)

            pup = trimesh.creation.icosphere(subdivisions=3, radius=0.0055)
            pup.apply_transform(tf.translation_matrix([ex, 0.074, head_z]))
            add(meshes_e, pup, 0.04, 0.04, 0.06, 1.0)

            hl = trimesh.creation.icosphere(subdivisions=2, radius=0.0028)
            hl.apply_transform(tf.translation_matrix([ex + 0.002, 0.076, head_z + 0.003]))
            add(meshes_e, hl, 0.95, 0.95, 0.95, 1.0)

        save_merged(meshes_e, f"eye_{name}.glb")


# ════════════════════════════════════════════════════════════
# 9. 资源清单
# ════════════════════════════════════════════════════════════
def build_manifest():
    manifest = {
        "base": {
            "male": "avatar_system/base_male.glb", "female": "avatar_system/base_female.glb",
        },
        "hair": {
            "male":   ["black_short", "brown_short", "blonde_short", "black_long", "grey_short"],
            "female": ["black_long", "brown_bob", "blonde_long", "pink_bob", "black_bun"],
        },
        "tops": {
            "male":   ["tshirt_red", "tshirt_blue", "tshirt_white", "tshirt_black",
                       "hoodie_grey", "sweater_beige"],
            "female": ["tshirt_white", "tshirt_pink", "dress_pink", "dress_black",
                       "hoodie_purple", "sweater_beige"],
        },
        "bottoms": {
            "male":   ["jeans_blue", "jeans_black", "pants_grey", "pants_khaki", "shorts_green"],
            "female": ["jeans_blue", "skirt_red", "skirt_black", "shorts_green", "pants_khaki"],
        },
        "shoes": {
            "male":   ["sneaker_white", "sneaker_black", "boots_brown", "boots_black"],
            "female": ["sneaker_white", "sneaker_black", "boots_brown", "sandal_beige"],
        },
        "eye_colors": ["brown", "blue", "green", "black", "grey"],
    }
    with open(f"{OUT_DIR}/manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"  ✅ manifest.json")


# ════════════════════════════════════════════════════════════
# 参数 & 颜色
# ════════════════════════════════════════════════════════════
PARAMS = {
    "male": dict(
        height=1.75, head_r=0.115, head_scale=(1.0, 1.0, 1.0),
        shoulder_w=0.42, hip=0.30, torso_h=0.56,
        neck_r=0.060, skin=(0.91, 0.76, 0.64, 1.0),
        hair_color=(0.08, 0.06, 0.04, 1.0),
        shoe_color=(0.15, 0.15, 0.18, 1.0),
    ),
    "female": dict(
        height=1.62, head_r=0.108, head_scale=(0.95, 1.02, 0.98),
        shoulder_w=0.36, hip=0.28, torso_h=0.52,
        neck_r=0.052, skin=(0.94, 0.78, 0.68, 1.0),
        hair_color=(0.08, 0.06, 0.04, 1.0),
        shoe_color=(0.15, 0.15, 0.18, 1.0),
    ),
}

HAIR_COLORS = {
    "black": (0.06, 0.05, 0.04, 1.0),
    "brown": (0.28, 0.18, 0.09, 1.0),
    "blonde": (0.82, 0.70, 0.42, 1.0),
    "grey": (0.55, 0.55, 0.56, 1.0),
    "pink": (0.92, 0.58, 0.72, 1.0),
}

TOP_COLORS = {
    "red": (0.82, 0.14, 0.14, 1.0), "blue": (0.18, 0.38, 0.82, 1.0),
    "white": (0.96, 0.96, 0.96, 1.0), "black": (0.10, 0.10, 0.10, 1.0),
    "grey": (0.50, 0.50, 0.52, 1.0), "beige": (0.86, 0.78, 0.62, 1.0),
    "pink": (0.92, 0.58, 0.72, 1.0), "purple": (0.48, 0.18, 0.72, 1.0),
}

BOTTOM_COLORS = {
    "blue": (0.16, 0.26, 0.58, 1.0), "black": (0.10, 0.10, 0.12, 1.0),
    "grey": (0.42, 0.42, 0.44, 1.0), "khaki": (0.68, 0.60, 0.44, 1.0),
    "green": (0.22, 0.48, 0.22, 1.0), "red": (0.72, 0.12, 0.12, 1.0),
}

SHOES_COLORS = {
    "white": (0.94, 0.94, 0.94, 1.0), "black": (0.08, 0.08, 0.10, 1.0),
    "brown": (0.42, 0.26, 0.14, 1.0), "beige": (0.86, 0.78, 0.62, 1.0),
}

# ════════════════════════════════════════════════════════════
# 主函数
# ════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print("=" * 60)
    print("🎨 竹笌换装系统 v4 - 多节点分层体模 + 走路动画")
    print("=" * 60)

    # 清理旧文件
    import glob
    for f in glob.glob(f"{OUT_DIR}/*.glb"):
        os.remove(f)
    print("  🗑 已清理旧文件\n")

    print("📦 基础体模 (male) v4...")
    build_base_v4("male")
    print("📦 基础体模 (female) v4...")
    build_base_v4("female")

    print("\n📦 头发...")
    for gid in PARAMS["male"]["height"] and ["black_short", "brown_short", "blonde_short", "black_long", "grey_short"]:
        build_hair(gid, "male")
    for gid in ["black_long", "brown_bob", "blonde_long", "pink_bob", "black_bun"]:
        build_hair(gid, "female")

    print("\n📦 上装...")
    for tid in ["tshirt_red", "tshirt_blue", "tshirt_white", "tshirt_black", "hoodie_grey", "sweater_beige"]:
        build_top(tid, "male")
    for tid in ["tshirt_white", "tshirt_pink", "dress_pink", "dress_black", "hoodie_purple", "sweater_beige"]:
        build_top(tid, "female")

    print("\n📦 下装...")
    for bid in ["jeans_blue", "jeans_black", "pants_grey", "pants_khaki", "shorts_green"]:
        build_bottom(bid, "male")
    for bid in ["jeans_blue", "skirt_red", "skirt_black", "shorts_green", "pants_khaki"]:
        build_bottom(bid, "female")

    print("\n📦 鞋子...")
    for sid in ["sneaker_white", "sneaker_black", "boots_brown", "boots_black"]:
        build_shoes(sid, "male")
    for sid in ["sneaker_white", "sneaker_black", "boots_brown", "sandal_beige"]:
        build_shoes(sid, "female")

    print("\n📦 眼睛配件...")
    build_eyes()

    print("\n📦 资源清单...")
    build_manifest()

    files = glob.glob(f"{OUT_DIR}/*.glb")
    print(f"\n{'=' * 60}")
    print(f"✅ 完成！共 {len(files)} 个 GLB + 5 PNG")
    print(f"📂 {OUT_DIR}")
    print(f"{'=' * 60}")
