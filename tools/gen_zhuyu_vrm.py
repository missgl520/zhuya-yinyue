# -*- coding: utf-8 -*-
"""
竹剑小精灵·江湖Q版 —— 程序化代理 VRM 生成脚本 (Blender 无头运行)
运行: blender --background --python gen_zhuyu_vrm.py
依赖: VRM Addon for Blender (icyp.make_basic_armature / export_scene.vrm)
产物: F:/zhuyapp/assets/vrm/zhuyu_chibi.vrm  +  zhuyu_chibi.glb
说明: 这是"结构合法、风格近似"的占位角色，用于先跑通 3D 显示 / VSeeFace 直播链路。
      精细版仍需在 VRoid Studio 按参数表制作后一行替换。
"""
import bpy
import os
import struct
import json
import mathutils
from pathlib import Path

OUT_DIR = Path(r"F:/zhuyapp/assets/vrm")
OUT_DIR.mkdir(parents=True, exist_ok=True)
VRM_PATH = str(OUT_DIR / "zhuyu_chibi.vrm")
GLB_PATH = str(OUT_DIR / "zhuyu_chibi.glb")

# ---- 配色 (sRGB 0..1) ----
def hex2rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0)

COL_FACE  = hex2rgb("FFF3D9")  # 奶米黄 脸
COL_BODY  = hex2rgb("96E294")  # 嫩青绿 身体
COL_BELLY = hex2rgb("FFF3D9")  # 奶米黄 肚子
COL_LEAF  = hex2rgb("62C450")  # 鲜绿 头顶竹叶
COL_LEAF2 = hex2rgb("96E294")  # 嫩绿 嫩芽/耳朵
COL_SWORD = hex2rgb("38B848")  # 翡翠绿 竹剑

# ===== 0. 清空场景 =====
bpy.ops.wm.read_factory_settings(use_empty=True)

# ===== 1. 生成基础 humanoid 骨架 (自动配置 VRM humanoid 骨骼映射) =====
bpy.ops.icyp.make_basic_armature()
armature = bpy.context.active_object
armature.data.vrm_addon_extension.spec_version = "1.0"
meta = armature.data.vrm_addon_extension.vrm1.meta
meta.vrm_name = "竹剑小精灵·江湖Q版"
meta.version = "1.0.0"
meta.authors.add().value = "zhuyapp"
meta.avatar_permission = "everyone"
meta.commercial_usage = "personalNonProfit"
meta.credit_notation = "unnecessary"
meta.allow_redistribution = True
meta.modification = "allowModificationRedistribution"

bpy.context.view_layer.update()

def world_bone(name):
    b = armature.data.bones[name]
    head = armature.matrix_world @ b.head_local
    tail = armature.matrix_world @ b.tail_local
    return head, tail

# ===== 2. MToon 材质工厂 =====
def make_mtoon(name, color):
    mat = bpy.data.materials.new(name)
    mat.vrm_addon_extension.mtoon1.enabled = True
    m = mat.vrm_addon_extension.mtoon1
    m.pbr_metallic_roughness.base_color_factor = (color[0], color[1], color[2], 1.0)
    m.alpha_mode = "OPAQUE"
    m.double_sided = True
    mtoon = m.extensions.vrmc_materials_mtoon
    mtoon.shade_color_factor = (color[0] * 0.55, color[1] * 0.55, color[2] * 0.55)
    mtoon.shading_toony_factor = 0.6
    mtoon.outline_width_mode = "worldCoordinates"
    mtoon.outline_width_factor = 0.012
    mtoon.outline_color_factor = (0.08, 0.18, 0.10)
    mtoon.gi_equalization_factor = 0.3
    return mat

mat_face  = make_mtoon("m_face", COL_FACE)
mat_body  = make_mtoon("m_body", COL_BODY)
mat_belly = make_mtoon("m_belly", COL_BELLY)
mat_leaf  = make_mtoon("m_leaf", COL_LEAF)
mat_leaf2 = make_mtoon("m_leaf2", COL_LEAF2)
mat_sword = make_mtoon("m_sword", COL_SWORD)

# ===== 3. 几何工具 =====
def place(obj, loc, rot_euler, scale):
    """把变换烘焙进网格数据, 物体本身回到 identity, 顶点处于最终世界坐标"""
    obj.location = loc
    obj.rotation_euler = rot_euler
    obj.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def bind_bone(obj, bone_name):
    vg = obj.vertex_groups.new(name=bone_name)
    vg.add(range(len(obj.data.vertices)), 1.0, 'REPLACE')
    mod = obj.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = armature
    obj.data.update()

def add_sphere(bone_name, radius, mat, offset=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=24, ring_count=16)
    obj = bpy.context.active_object
    obj.data.materials.append(mat)
    head, _ = world_bone(bone_name)
    place(obj, head + mathutils.Vector(offset), (0, 0, 0), (1, 1, 1))
    bind_bone(obj, bone_name)
    return obj

def add_limb(bone_name, radius, mat):
    head, tail = world_bone(bone_name)
    direction = tail - head
    length = max(direction.length, 0.05)
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=length, vertices=16)
    obj = bpy.context.active_object
    obj.data.materials.append(mat)
    z = mathutils.Vector((0, 0, 1))
    q = z.rotation_difference(direction.normalized())
    mid = (head + tail) / 2
    place(obj, mid, q.to_euler(), (1, 1, 1))
    bind_bone(obj, bone_name)
    return obj

def add_box(center, dims, mat, bone_name, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    obj.data.materials.append(mat)
    place(obj, center, rot, dims)
    bind_bone(obj, bone_name)
    return obj

def add_plane(loc, rot, size, mat, bone_name):
    bpy.ops.mesh.primitive_plane_add(size=size)
    obj = bpy.context.active_object
    obj.data.materials.append(mat)
    place(obj, loc, rot, (1, 1, 1))
    bind_bone(obj, bone_name)
    return obj

# ===== 4. 组装角色 =====
# --- 头 (chibi 大球) ---
head_h, head_t = world_bone('head')
add_sphere('head', 0.19, mat_face, offset=(0, 0, 0.16))

# --- 躯干 (hips->chest 箱体, 嫩绿) ---
hips_h, hips_t = world_bone('hips')
chest_h, chest_t = world_bone('chest')
torso_bottom = hips_h.z + 0.02
torso_top = chest_t.z + 0.02
torso_h = torso_top - torso_bottom
torso_center = mathutils.Vector(((hips_h.x + chest_h.x) / 2,
                                 (hips_h.y + chest_h.y) / 2,
                                 (torso_bottom + torso_top) / 2))
add_box(torso_center, (0.24, 0.17, torso_h * 0.6), mat_body, 'spine')

# --- 肚子奶黄贴片 (身体前侧 +Y) ---
belly_center = torso_center + mathutils.Vector((0, 0.10, -0.01))
add_box(belly_center, (0.15, 0.03, torso_h * 0.42), mat_belly, 'spine')

# --- 四肢 (圆柱, 嫩绿) ---
add_limb('leftUpperArm', 0.05, mat_body)
add_limb('leftLowerArm', 0.045, mat_body)
add_limb('rightUpperArm', 0.05, mat_body)
add_limb('rightLowerArm', 0.045, mat_body)
add_limb('leftUpperLeg', 0.06, mat_body)
add_limb('leftLowerLeg', 0.05, mat_body)
add_limb('rightUpperLeg', 0.06, mat_body)
add_limb('rightLowerLeg', 0.05, mat_body)

# --- 手/脚 (小球) ---
add_sphere('leftHand', 0.055, mat_body)
add_sphere('rightHand', 0.055, mat_body)
add_sphere('leftFoot', 0.06, mat_body)
add_sphere('rightFoot', 0.06, mat_body)

# --- 头顶 4 片竹叶 (面片, 鲜绿) ---
leaf_specs = [
    ((0, 0, 0.40), (0, 0, 0), 0.16),     # 朝上
    ((0.12, 0, 0.37), (0, 0, 0.5), 0.13), # 右散
    ((-0.12, 0, 0.37), (0, 0, -0.5), 0.13), # 左散
    ((0, -0.05, 0.36), (0.6, 0, 3.14), 0.10), # 后置小
]
for off, rot, sz in leaf_specs:
    add_plane(head_h + mathutils.Vector(off), rot, sz, mat_leaf, 'head')

# --- 额头 3 颗小嫩芽 (淡嫩绿) ---
sprout_specs = [
    ((0.06, 0.16, 0.10), 0.06),
    ((0, 0.17, 0.10), 0.07),
    ((-0.06, 0.16, 0.10), 0.06),
]
for off, sz in sprout_specs:
    add_plane(head_h + mathutils.Vector(off), (1.57, 0, 0), sz, mat_leaf2, 'head')

# --- 圆精灵耳 (嫩绿, 两侧) ---
add_sphere('head', 0.05, mat_leaf2, offset=(0.20, 0, 0.05))
add_sphere('head', 0.05, mat_leaf2, offset=(-0.20, 0, 0.05))

# ===== 5. 竹剑 (右手持, 剑尖朝地面) =====
hand_h, hand_t = world_bone('rightHand')
sword_parts = []
seg_len = 0.11
seg_n = 4
# 剑身: 分段竹节, 从手向下
for i in range(seg_n):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.032, depth=seg_len, vertices=12)
    o = bpy.context.active_object
    y_off = -(i * seg_len) - seg_len / 2 - 0.015
    place(o, hand_h + mathutils.Vector((0, 0, y_off)), (0, 0, 0), (1, 1, 1))
    o.data.materials.append(mat_sword)
    sword_parts.append(o)
# 竹制钝头 (剑尖)
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.032, segments=12, ring_count=8)
tip = bpy.context.active_object
place(tip, hand_h + mathutils.Vector((0, 0, -(seg_n * seg_len) - 0.015)), (0, 0, 0), (1, 1, 1))
tip.data.materials.append(mat_sword)
sword_parts.append(tip)
# 剑柄 (短粗, 米黄) 在手上方的手心里
bpy.ops.mesh.primitive_cylinder_add(radius=0.045, depth=0.07, vertices=12)
grip = bpy.context.active_object
place(grip, hand_h + mathutils.Vector((0, 0, 0.02)), (0, 0, 0), (1, 1, 1))
grip.data.materials.append(mat_belly)
sword_parts.append(grip)
# 合并为单一剑物体
for o in sword_parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = sword_parts[0]
bpy.ops.object.join()
sword = bpy.context.active_object
bind_bone(sword, 'rightHand')
# 略微偏向身体右侧, 不遮挡脸: 整体沿 +X 偏一点 (在几何上已通过 hand 位置决定, 这里微调)
# 剑已挂在右手骨骼, 跟随右手。

# ===== 6. 导出 VRM + GLB =====
result = bpy.ops.export_scene.vrm(filepath=VRM_PATH)
if result != {"FINISHED"}:
    raise Exception(f"VRM 导出失败: {result}")
print(f"[OK] VRM -> {VRM_PATH}")

try:
    result2 = bpy.ops.export_scene.gltf(filepath=GLB_PATH, use_visible=True, export_apply=True)
    if result2 == {"FINISHED"}:
        print(f"[OK] GLB -> {GLB_PATH}")
except Exception as e:
    print(f"[WARN] GLB 导出跳过: {e}")

# ===== 7. 校验 VRM 结构 =====
def validate_vrm(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data[:4] != b'glTF':
        return False, "不是 GLB"
    length = struct.unpack('<I', data[8:12])[0]
    # 找 JSON chunk
    off = 12
    json_bytes = None
    while off < len(data):
        clen = struct.unpack('<I', data[off:off+4])[0]
        ctype = struct.unpack('<I', data[off+4:off+8])[0]
        chunk = data[off+8:off+8+clen]
        if ctype == 0x4E4F534A:  # JSON
            json_bytes = chunk
            break
        off += 8 + clen
        if clen % 4: off += 4 - (clen % 4)
    if not json_bytes:
        return False, "无 JSON chunk"
    gltf = json.loads(json_bytes.decode('utf-8'))
    ext = gltf.get('extensions', {})
    has_vrm = 'VRM' in ext
    bones = len(gltf.get('nodes', []))
    mats = len(gltf.get('materials', []))
    return has_vrm, f"nodes={bones} materials={mats} VRM扩展={'有' if has_vrm else '无'}"

ok, info = validate_vrm(VRM_PATH)
print(f"[VALIDATE] {ok} | {info}")
print("DONE")
