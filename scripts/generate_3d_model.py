"""
zhuya-yinyue 3D 模型生成器 v2
用 Python + trimesh 生成 Q 版角色，导出 GLB 供 Three.js 使用
"""
import numpy as np
import trimesh
import trimesh.creation
import trimesh.transformations as tf
import os, json

OUT_DIR = '/root/.openclaw/workspace/zhuya-yinyue/assets/3d/models'
os.makedirs(OUT_DIR, exist_ok=True)

# ===================== 颜色 =====================
def rgba(r, g, b, a=255):
    return np.array([r, g, b, a], dtype=np.uint8)

COLORS = {
    'skin':   rgba(250, 217, 191),
    'hair':   rgba(38,  20,  13),
    'eye':    rgba(51,  115, 217),
    'shirt':  rgba(230, 128, 179),
    'pants':  rgba(102, 140, 242),
    'shoes':  rgba(153,  77,  77),
    'mouth':  rgba(230,  77, 102),
    'blush':  rgba(255, 179, 179, 160),
}

# ===================== 几何体 =====================
def mk_sphere(r, color, subs=3):
    m = trimesh.creation.icosphere(radius=r, subdivisions=subs)
    m.visual.vertex_colors = np.tile(color, (len(m.vertices), 1))
    return m

def mk_uv_sphere(r, color):
    """光滑 UV 球体"""
    m = trimesh.creation.uv_sphere(radius=r)
    m.visual.vertex_colors = np.tile(color, (len(m.vertices), 1))
    return m

def mk_cylinder(r, h, color, segs=16):
    """圆柱体"""
    m = trimesh.creation.cylinder(radius=r, height=h, sections=segs)
    m.visual.vertex_colors = np.tile(color, (len(m.vertices), 1))
    return m

def mk_capsule(r, h, color):
    """胶囊体"""
    m = trimesh.creation.capsule(radius=r, height=h)
    m.visual.vertex_colors = np.tile(color, (len(m.vertices), 1))
    return m

def mk_box(w, h, d, color):
    m = trimesh.creation.box(extents=[w, h, d])
    m.visual.vertex_colors = np.tile(color, (len(m.vertices), 1))
    return m

def scale(m, sx, sy, sz):
    out = m.copy(); out.apply_scale([sx, sy, sz]); return out

def move(m, x, y, z):
    out = m.copy(); out.apply_translation([x, y, z]); return out

def rot_z(m, a):
    out = m.copy(); out.apply_transform(tf.rotation_matrix(a, [0, 0, 1])); return out

def merge(*meshes):
    valid = [m for m in meshes if m is not None]
    return trimesh.util.concatenate(valid) if valid else None

# ===================== 身体部件 =====================
def part_head(skin, hair_col):
    parts = []
    # 脸
    parts.append(move(scale(mk_uv_sphere(0.50, skin), 1.0, 1.12, 0.88), 0, 0, 0.05))
    # 左眼
    parts.append(move(scale(mk_uv_sphere(0.11, COLORS['eye']), 1.0, 1.25, 0.38), -0.16, 0.07, 0.39))
    # 右眼
    parts.append(move(scale(mk_uv_sphere(0.11, COLORS['eye']), 1.0, 1.25, 0.38), 0.16, 0.07, 0.39))
    # 瞳孔
    parts.append(move(scale(mk_uv_sphere(0.065, rgba(20,20,20)), 1.0, 1.0, 0.3), -0.16, 0.06, 0.42))
    parts.append(move(scale(mk_uv_sphere(0.065, rgba(20,20,20)), 1.0, 1.0, 0.3), 0.16, 0.06, 0.42))
    # 高光
    parts.append(move(scale(mk_uv_sphere(0.035, rgba(255,255,255)), 1.2, 1.0, 0.4), -0.19, 0.13, 0.44))
    parts.append(move(scale(mk_uv_sphere(0.035, rgba(255,255,255)), 1.2, 1.0, 0.4), 0.13, 0.13, 0.44))
    # 嘴巴
    parts.append(move(scale(mk_uv_sphere(0.065, COLORS['mouth']), 1.6, 0.45, 0.3), 0, -0.11, 0.43))
    # 腮红
    parts.append(move(scale(mk_uv_sphere(0.10, COLORS['blush']), 1.3, 0.65, 0.2), -0.29, -0.02, 0.36))
    parts.append(move(scale(mk_uv_sphere(0.10, COLORS['blush']), 1.3, 0.65, 0.2), 0.29, -0.02, 0.36))
    # 头发-头顶
    parts.append(move(scale(mk_uv_sphere(0.53, hair_col), 1.12, 0.85, 1.0), 0, 0.15, -0.01))
    # 刘海
    parts.append(move(mk_box(0.95, 0.22, 0.28, hair_col), 0, 0.26, 0.22))
    # 两侧头发
    parts.append(move(scale(mk_uv_sphere(0.26, hair_col), 0.55, 1.6, 0.72), -0.46, -0.10, 0.0))
    parts.append(move(scale(mk_uv_sphere(0.26, hair_col), 0.55, 1.6, 0.72), 0.46, -0.10, 0.0))
    # 耳朵
    parts.append(move(scale(mk_uv_sphere(0.12, skin), 0.5, 1.3, 0.8), -0.45, 0.05, 0.0))
    parts.append(move(scale(mk_uv_sphere(0.12, skin), 0.5, 1.3, 0.8), 0.45, 0.05, 0.0))
    return merge(*parts)


def part_torso(shirt_col):
    parts = []
    parts.append(move(scale(mk_uv_sphere(0.42, shirt_col), 1.0, 1.25, 0.76), 0, -0.55, 0))
    parts.append(move(scale(mk_uv_sphere(0.38, shirt_col), 1.12, 0.88, 0.82), 0, -0.95, 0.03))
    parts.append(move(mk_capsule(0.11, 0.14, COLORS['skin']), 0, -0.32, 0))
    return merge(*parts)


def part_arms(skin_col, shirt_col):
    parts = []
    parts.append(rot_z(move(mk_capsule(0.115, 0.28, shirt_col), -0.52, -0.58, 0), 0.22))
    parts.append(rot_z(move(mk_capsule(0.095, 0.26, skin_col), -0.60, -0.85, 0), 0.08))
    parts.append(move(mk_uv_sphere(0.10, skin_col), -0.63, -1.06, 0))
    parts.append(rot_z(move(mk_capsule(0.115, 0.28, shirt_col), 0.52, -0.58, 0), -0.22))
    parts.append(rot_z(move(mk_capsule(0.095, 0.26, skin_col), 0.60, -0.85, 0), -0.08))
    parts.append(move(mk_uv_sphere(0.10, skin_col), 0.63, -1.06, 0))
    return merge(*parts)


def part_legs(pants_col, shoes_col):
    parts = []
    parts.append(move(mk_capsule(0.13, 0.30, pants_col), -0.18, -1.25, 0))
    parts.append(move(mk_capsule(0.10, 0.28, pants_col), -0.18, -1.65, 0))
    parts.append(move(scale(mk_uv_sphere(0.12, shoes_col), 1.42, 0.68, 1.65), -0.18, -1.90, 0.04))
    parts.append(move(mk_capsule(0.13, 0.30, pants_col), 0.18, -1.25, 0))
    parts.append(move(mk_capsule(0.10, 0.28, pants_col), 0.18, -1.65, 0))
    parts.append(move(scale(mk_uv_sphere(0.12, shoes_col), 1.42, 0.68, 1.65), 0.18, -1.90, 0.04))
    return merge(*parts)


def build_chibi(skin, shirt, pants, hair):
    return merge(
        part_head(skin, hair),
        part_torso(shirt),
        part_arms(skin, shirt),
        part_legs(pants, COLORS['shoes']),
    )


# ===================== 预设 =====================
PRESETS = [
    ('default',  COLORS['skin'],  COLORS['shirt'],  COLORS['pants'],  COLORS['hair']),
    ('cat_girl', rgba(255,235,225), rgba(218,140,191), rgba(200,210,255), rgba(153,77,51)),
    ('dark',     rgba(217,166,128), rgba( 77, 77,153), rgba( 51, 51, 89), rgba(13,13,26)),
    ('fairy',    rgba(255,250,255), rgba(179,230,255), rgba(204,153,255), rgba(230,204,255)),
]


# ===================== 动画数据 =====================
def gen_walk_frames(n=8):
    frames = []
    for i in range(n):
        t = i / n * 2 * np.pi
        frames.append({
            'time': round(i * 0.12, 3),
            'leftArm':  round(np.sin(t) * 0.50, 4),
            'rightArm': round(-np.sin(t) * 0.50, 4),
            'leftLeg':  round(-np.sin(t) * 0.40, 4),
            'rightLeg': round(np.sin(t) * 0.40, 4),
            'bodyY':    round(abs(np.sin(t * 2)) * 0.03, 4),
        })
    return frames

def gen_idle_frames(n=4):
    frames = []
    for i in range(n):
        t = i / n * 2 * np.pi
        frames.append({
            'time': round(i * 0.25, 3),
            'bodyY':    round(np.sin(t) * 0.015, 4),
            'leftArm':  round(np.sin(t * 0.5) * 0.05, 4),
            'rightArm': round(-np.sin(t * 0.5) * 0.05, 4),
        })
    return frames


# ===================== 主程序 =====================
def main():
    print("=" * 55)
    print("🎮 zhuya-yinyue 3D 模型生成器 v2")
    print("=" * 55)

    for name, skin, shirt, pants, hair in PRESETS:
        print(f"\n📦 生成 chibi_{name}...")
        ch = build_chibi(skin, shirt, pants, hair)
        fp = os.path.join(OUT_DIR, f'chibi_{name}.glb')
        for ext, ftype in [('glb','glb'), ('gltf','gltf'), ('obj','obj')]:
            try:
                out_fp = fp.replace('.glb', f'.{ext}')
                ch.export(file_obj=out_fp, file_type=ftype)
                sz = os.path.getsize(out_fp)
                print(f"  ✅ {os.path.basename(out_fp)} ({sz//1024} KB)")
                break
            except Exception as e:
                print(f"  ⚠️  {ext}: {str(e)[:60]}")

    # 动画数据
    anim = {'walk': gen_walk_frames(8), 'idle': gen_idle_frames(4)}
    ap = os.path.join(OUT_DIR, 'animations.json')
    with open(ap, 'w', encoding='utf-8') as f:
        json.dump(anim, f, indent=2, ensure_ascii=False)
    print(f"\n📄 动画数据: animations.json")

    cfg = {
        'models': {name: f'chibi_{name}.glb' for name, *_ in PRESETS},
        'animations': 'animations.json',
        'usage': 'Three.js: new GLTFLoader().load("chibi_default.glb", gltf => scene.add(gltf.scene))',
        'scale_hint': '角色高约 2.0 单位，建议 scale = 0.3~0.5',
    }
    cp = os.path.join(OUT_DIR, 'models_config.json')
    with open(cp, 'w', encoding='utf-8') as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
    print(f"📄 配置: models_config.json")
    print(f"\n输出: {OUT_DIR}")
    print("=" * 55)


if __name__ == '__main__':
    main()
