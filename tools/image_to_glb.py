#!/usr/bin/env python3
"""
纯算法 2D→3D 角色建模管线 v2
零依赖（除 trimesh），全离线运行
策略：颜色直方图分割 + 参数化人体建模 + 顶点颜色贴图
"""

import sys, os, warnings
warnings.filterwarnings('ignore')

import numpy as np
from PIL import Image
import trimesh
import trimesh.repair

# ─────────────────────────────────────────────
# 工具函数
# ─────────────────────────────────────────────
def color_distance(c1, c2):
    """欧氏颜色距离"""
    return np.sqrt(np.sum((np.array(c1) - np.array(c2)) ** 2))


def simple_kmeans(pixels, n_clusters, seed=42):
    """纯 NumPy 实现 KMeans（简化版，用于颜色聚类）"""
    np.random.seed(seed)
    
    # 初始化中心点（随机选）
    idx = np.random.choice(len(pixels), n_clusters, replace=False)
    centers = pixels[idx].copy()
    
    for _ in range(20):  # 最多20轮
        # 分配到最近中心
        dists = np.linalg.norm(pixels[:, None] - centers[None], axis=2)
        labels = dists.argmin(axis=1)
        
        # 更新中心
        new_centers = np.array([
            pixels[labels == i].mean(axis=0) if np.any(labels == i) else centers[i]
            for i in range(n_clusters)
        ])
        
        if np.allclose(centers, new_centers, atol=1.0):
            break
        centers = new_centers
    
    return centers, labels


def connected_component_labeling(mask):
    """纯 NumPy 连通域标记"""
    labeled = np.zeros_like(mask, dtype=np.int32)
    current_label = 0
    
    h, w = mask.shape
    for y in range(h):
        for x in range(w):
            if mask[y, x] and labeled[y, x] == 0:
                # BFS flood fill
                current_label += 1
                stack = [(y, x)]
                while stack:
                    cy, cx = stack.pop()
                    if (0 <= cy < h and 0 <= cx < w and 
                        mask[cy, cx] and labeled[cy, cx] == 0):
                        labeled[cy, cx] = current_label
                        stack.extend([(cy+1,cx),(cy-1,cx),(cy,cx+1),(cy,cx-1)])
    
    return labeled, current_label


def binary_opening(img, kernel_size=3):
    """腐蚀后膨胀"""
    from scipy.ndimage import binary_erosion, binary_dilation
    return binary_dilation(binary_erosion(img, iterations=1), iterations=1)


# ─────────────────────────────────────────────
# 1. 图像分割
# ─────────────────────────────────────────────
def segment_character(img: Image.Image, tolerance=40):
    """分离角色与背景"""
    arr = np.array(img.convert('RGB')).astype(float)
    h, w = arr.shape[:2]
    
    # 取四角背景色
    corners = np.array([arr[2,2], arr[2,w-3], arr[h-3,2], arr[h-3,w-3]])
    bg_color = corners.mean(axis=0)
    
    # 距离 > tolerance 为角色
    diff = np.sqrt(np.sum((arr - bg_color) ** 2, axis=2))
    mask = (diff > tolerance).astype(np.uint8)
    
    # 简单的开运算（腐蚀+膨胀）
    kernel = np.ones((3, 3), dtype=np.uint8)
    mask = np.clip(np.convolve(mask.flatten(), kernel.flatten(), mode='same').reshape(mask.shape), 0, 1).astype(np.uint8)
    mask = np.clip(np.convolve(mask.flatten(), np.ones(5, dtype=np.uint8), mode='same').reshape(mask.shape) / 5, 0, 1).astype(np.uint8)
    
    # 找最大连通域
    labeled, num = connected_component_labeling(mask)
    if num > 0:
        sizes = [(labeled == i).sum() for i in range(1, num+1)]
        max_label = sizes.index(max(sizes)) + 1
        mask = (labeled == max_label).astype(np.uint8)
    
    return mask, bg_color


# ─────────────────────────────────────────────
# 2. 颜色聚类 + 区域检测
# ─────────────────────────────────────────────
def detect_regions(img: Image.Image, mask: np.ndarray):
    """检测头发/皮肤/服装区域"""
    arr = np.array(img.convert('RGB'))
    ys, xs = np.where(mask > 0)
    if len(ys) == 0:
        return {}
    
    y_min, y_max = ys.min(), ys.max()
    x_min, x_max = xs.min(), xs.max()
    char_h, char_w = y_max - y_min, x_max - x_min
    
    roi = arr[y_min:y_max+1, x_min:x_max+1]
    roi_mask = mask[y_min:y_max+1, x_min:x_max+1]
    
    # 采样（每5像素取1个，加速）
    sample_y, sample_x = np.where(roi_mask > 0)
    sample_indices = np.arange(0, len(sample_y), 5)
    pixels = roi[sample_y[sample_indices], sample_x[sample_indices]].astype(float)
    
    if len(pixels) < 10:
        pixels = roi[roi_mask > 0].astype(float)
    
    # 颜色聚类
    n_clusters = 6
    centers, labels = simple_kmeans(pixels, n_clusters)
    
    regions = {}
    for i, center in enumerate(centers):
        r, g, b = int(center[0]), int(center[1]), int(center[2])
        s = r + g + b
        
        if s < 120 and r < 60:           label = 'hair'
        elif 100 < s < 220 and abs(r-g) < 30: label = 'skin'
        elif s < 80:                      label = 'dark'
        elif s > 180 and r > 150:        label = 'shiny'
        elif s > 130:                     label = 'light'
        else:                             label = 'mid'
        
        if label not in regions:
            regions[label] = {'color': center, 'count': 0}
        regions[label]['count'] += np.sum(labels == i)
    
    main_outfit = max(regions.items(), key=lambda x: x[1]['count'])[0]
    
    return {
        'bbox': (y_min, y_max, x_min, x_max),
        'h': char_h, 'w': char_w,
        'regions': regions,
        'main_outfit': main_outfit,
        'arr': arr,
    }


# ─────────────────────────────────────────────
# 3. 构建 3D 人体网格
# ─────────────────────────────────────────────
def make_ellipsoid(cx, cy, cz, rx, ry, rz, seg=12, ring=16):
    verts, faces = [], []
    for i in range(seg + 1):
        theta = np.pi * i / seg
        for j in range(ring + 1):
            phi = 2 * np.pi * j / ring
            verts.append([cx + rx*np.sin(theta)*np.cos(phi), cy + ry*np.cos(theta), cz + rz*np.sin(theta)*np.sin(phi)])
    for i in range(seg):
        for j in range(ring):
            a = i*(ring+1)+j; b = a+ring+1
            faces.append([a, b, a+1]); faces.append([b, b+1, a+1])
    return np.array(verts), np.array(faces)


def make_capsule(cx, cz, cy, r_top, r_bot, h, n_ring=8, n_seg=16):
    verts, faces = [], []
    top_y = cy + h/2; bot_y = cy - h/2
    
    for i in range(n_ring + 1):
        t = i / n_ring; y = top_y - t * h; r = r_top + (r_bot - r_top) * t
        for j in range(n_seg + 1):
            ang = 2*np.pi*j/n_seg
            verts.append([cx + r*np.cos(ang), y, cz + r*np.sin(ang)])
    
    nc_top = len(verts); verts.append([cx, top_y, cz])
    nc_bot = len(verts); verts.append([cx, bot_y, cz])
    
    for i in range(n_ring):
        for j in range(n_seg):
            a = i*(n_seg+1)+j; b = a+n_seg+1
            faces.append([a, b, a+1]); faces.append([b, b+1, a+1])
    base = n_ring*(n_seg+1)
    for j in range(n_seg):
        faces.append([nc_top, j, (j+1)%(n_seg+1)])
        faces.append([nc_bot, base+j+1, base+j])
    
    return np.array(verts), np.array(faces)


def build_humanoid(regions_data, verbose=True):
    """构建完整 3D 人体模型"""
    
    bbox = regions_data['bbox']
    y_min, y_max, x_min, x_max = bbox
    char_h = regions_data['h']
    char_w = regions_data['w']
    regions = regions_data['regions']
    main_outfit = regions_data['main_outfit']
    
    # ── 服装颜色 ──
    outfit_colors = {
        'shiny': [210, 218, 240],
        'light': [130, 120, 150],
        'mid':   [70,  60,  90],
        'dark':  [25,  20,  35],
    }
    outfit_color = outfit_colors.get(main_outfit, [50, 40, 70])
    
    hair_color = [65, 65, 75]
    if 'hair' in regions:
        hr, hg, hb = regions['hair']['color'][:3]
        hair_color = [int(hr), int(hg), int(hb)]
    
    skin_color = [220, 190, 175]
    
    # ── 比例 ──
    head_ratio = 0.115
    torso_ratio = 0.32
    leg_ratio = 0.48
    foot_ratio = 0.065
    
    total = char_h
    head_h = total * head_ratio
    torso_h = total * torso_ratio
    leg_h = total * leg_ratio
    foot_h = total * foot_ratio
    
    # 缩放到 3D 单位
    scale = 3.0 / (foot_h + leg_h + torso_h + head_h)
    
    def S(v): return v * scale
    
    parts_verts, parts_faces, parts_colors = [], [], []
    offset_v = 0
    
    def add_part(verts, faces, color):
        nonlocal offset_v
        colored_verts = np.hstack([verts, np.tile(color, (len(verts), 1))])
        parts_verts.append(colored_verts)
        parts_faces.append(faces + offset_v)
        offset_v += len(verts)
    
    # 脚（两只）
    for side in [-1, 1]:
        v, f = make_capsule(S(side*char_w*0.12), 0, S(foot_h*0.5), S(char_w*0.06), S(char_w*0.06), S(foot_h*0.4), n_ring=4, n_seg=12)
        add_part(v, f, [30, 30, 38])
    
    # 小腿
    for side in [-1, 1]:
        v, f = make_capsule(S(side*char_w*0.13), 0, S(foot_h+leg_h*0.3), S(char_w*0.07), S(char_w*0.06), S(leg_h*0.55), n_ring=6, n_seg=12)
        add_part(v, f, outfit_color)
    
    # 大腿
    for side in [-1, 1]:
        v, f = make_capsule(S(side*char_w*0.15), 0, S(foot_h+leg_h*0.7), S(char_w*0.10), S(char_w*0.08), S(leg_h*0.45), n_ring=6, n_seg=12)
        add_part(v, f, outfit_color)
    
    # 臀部
    v, f = make_capsule(0, 0, S(foot_h+leg_h*0.88), S(char_w*0.32), S(char_w*0.25), S(leg_h*0.22), n_ring=6, n_seg=16)
    add_part(v, f, outfit_color)
    
    # 躯干（主体）
    v, f = make_capsule(0, 0, S(foot_h+leg_h+torso_h*0.5), S(char_w*0.38), S(char_w*0.22), S(torso_h), n_ring=8, n_seg=20)
    add_part(v, f, outfit_color)
    
    # 宽肩披风底座
    v, f = make_ellipsoid(0, S(foot_h+leg_h+torso_h*0.82), 0, S(char_w*0.40), S(char_w*0.07), S(char_w*0.40), seg=6, ring=24)
    add_part(v, f, outfit_color)
    
    # 颈部
    neck_y = foot_h + leg_h + torso_h - head_h*0.15
    v, f = make_capsule(0, 0, S(neck_y), S(char_w*0.10), S(char_w*0.09), S(head_h*0.25), n_ring=4, n_seg=12)
    add_part(v, f, skin_color)
    
    # 头部
    head_c_y = foot_h + leg_h + torso_h + head_h*0.3
    v, f = make_ellipsoid(0, S(head_c_y), 0, S(char_w*0.22), S(head_h*0.50), S(char_w*0.20), seg=14, ring=18)
    add_part(v, f, skin_color)
    
    # 头发
    v, f = make_ellipsoid(0, S(head_c_y+head_h*0.1), 0, S(char_w*0.26), S(head_h*0.32), S(char_w*0.24), seg=10, ring=16)
    add_part(v, f, hair_color)
    
    # 手臂（两只）
    shoulder_y = foot_h + leg_h + torso_h*0.78
    elbow_y = foot_h + leg_h + torso_h*0.55
    for side in [-1, 1]:
        v, f = make_capsule(S(side*char_w*0.44), 0, S(shoulder_y), S(char_w*0.07), S(char_w*0.06), S(torso_h*0.32), n_ring=6, n_seg=12)
        add_part(v, f, outfit_color)
        v, f = make_capsule(S(side*char_w*0.52), 0, S(elbow_y), S(char_w*0.06), S(char_w*0.05), S(torso_h*0.28), n_ring=6, n_seg=12)
        add_part(v, f, outfit_color)
    
    # 礼帽底座
    hat_y = foot_h + leg_h + torso_h + head_h*0.7
    v, f = make_ellipsoid(0, S(hat_y), 0, S(char_w*0.48), S(char_w*0.06), S(char_w*0.38), seg=6, ring=28)
    add_part(v, f, [185, 190, 220])
    
    # 礼帽顶
    v, f = make_capsule(0, 0, S(hat_y+head_h*0.18), S(char_w*0.20), S(char_w*0.20), S(head_h*0.38), n_ring=6, n_seg=20)
    add_part(v, f, [185, 190, 220])
    
    # 合并
    all_verts = np.vstack(parts_verts)
    all_faces = np.vstack(parts_faces)
    all_colors = all_verts[:, 3:6].astype(np.float64) / 255.0
    
    mesh = trimesh.Trimesh(vertices=all_verts[:, :3], faces=all_faces)
    mesh.visual.vertex_colors = np.hstack([
        (all_colors * 255).astype(np.uint8),
        np.full((len(all_colors), 1), 255, dtype=np.uint8)
    ])
    
    trimesh.repair.fix_normals(mesh)
    
    if verbose:
        print(f"   顶点数: {len(mesh.vertices)}, 面数: {len(mesh.faces)}")
        print(f"   服装主色: RGB{tuple(outfit_color)}, 头发: RGB{tuple(hair_color)}")
    
    return mesh, scale


# ─────────────────────────────────────────────
# 4. 投影贴图（把原图颜色投影到顶点）
# ─────────────────────────────────────────────
def project_texture(mesh, regions_data, scale):
    """把原图颜色正交投影到 3D 顶点"""
    
    arr = regions_data['arr']
    bbox = regions_data['bbox']
    y_min, y_max, x_min, x_max = bbox
    char_h = regions_data['h']
    char_w = regions_data['w']
    
    verts = mesh.vertices.copy()
    colors = mesh.visual.vertex_colors.copy()
    
    y_v_min, y_v_max = verts[:, 1].min(), verts[:, 1].max()
    y_range = max(y_v_max - y_v_min, 0.001)
    
    projected = 0
    for i, v in enumerate(verts):
        t_y = (v[1] - y_v_min) / y_range
        img_y = int(np.clip(y_min + t_y * char_h, 0, arr.shape[0]-1))
        
        t_x = v[0] / (scale * max(char_w, 1)) + 0.5
        img_x = int(np.clip(x_min + t_x * char_w, 0, arr.shape[1]-1))
        
        if 0 <= img_y < arr.shape[0] and 0 <= img_x < arr.shape[1]:
            r, g, b = arr[img_y, img_x]
            colors[i] = [r, g, b, 255]
            projected += 1
    
    mesh.visual.vertex_colors = colors
    return mesh, projected


# ─────────────────────────────────────────────
# 5. 贴钻光效果（闪闪发光的服装）
# ─────────────────────────────────────────────
def add_sparkle_effect(mesh, regions_data):
    """给闪钻区域增加高光顶点"""
    regions = regions_data['regions']
    if 'shiny' not in regions:
        return mesh
    
    # 在服装区域顶点上添加闪烁高光（略微提升亮度）
    colors = mesh.visual.vertex_colors.copy().astype(np.float64)
    for i, vc in enumerate(colors):
        if np.mean(vc[:3]) > 160:  # 亮区域
            # 增加一些银白色高光
            colors[i, :3] = np.clip(colors[i, :3] * 1.15 + 20, 0, 255)
    
    mesh.visual.vertex_colors = colors.astype(np.uint8)
    return mesh


# ─────────────────────────────────────────────
# 6. 主函数
# ─────────────────────────────────────────────
def image_to_glb(img_path: str, output_path: str = None, verbose=True) -> str:
    """端到端：图片 → GLB"""
    
    if verbose:
        print(f"📷 加载: {img_path}")
    
    img = Image.open(img_path)
    img_rgb = np.array(img.convert('RGB'))
    
    if verbose:
        print(f"   图像尺寸: {img.size[0]}×{img.size[1]}")
    
    # Step 1: 分割
    if verbose:
        print("🔍 分割角色轮廓...")
    mask, bg = segment_character(img)
    char_px = mask.sum()
    if verbose:
        print(f"   角色像素: {char_px} ({char_px/(img.size[0]*img.size[1])*100:.1f}%画面)")
    
    # Step 2: 区域检测
    if verbose:
        print("🎨 颜色聚类分析...")
    regions_data = detect_regions(img, mask)
    regions = regions_data['regions']
    if verbose:
        print(f"   检测到区域: {list(regions.keys())}")
        print(f"   服装类型: {regions_data['main_outfit']}")
    
    # Step 3: 构建 3D 模型
    if verbose:
        print("🧊 构建 3D 人体模型...")
    mesh, scale = build_humanoid(regions_data, verbose)
    
    # Step 4: 投影贴图
    if verbose:
        print("🖼️ 正交投影纹理...")
    mesh, projected = project_texture(mesh, regions_data, scale)
    if verbose:
        print(f"   已投影顶点数: {projected}/{len(mesh.vertices)}")
    
    # Step 5: 闪钻效果
    if verbose:
        print("✨ 添加闪钻高光...")
    mesh = add_sparkle_effect(mesh, regions_data)
    
    # Step 6: 导出
    if output_path is None:
        name = os.path.splitext(os.path.basename(img_path))[0]
        output_path = os.path.join(os.path.dirname(img_path), f"{name}_3d.glb")
    
    if verbose:
        print(f"💾 导出 GLB: {output_path}")
    
    mesh.export(output_path)
    
    size_kb = os.path.getsize(output_path) / 1024
    if verbose:
        print(f"✅ 完成！顶点数: {len(mesh.vertices)}, 面数: {len(mesh.faces)}")
        print(f"   文件: {output_path} ({size_kb:.1f} KB)")
    
    return output_path


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: python image_to_glb.py <图片路径> [输出路径]")
        sys.exit(1)
    
    img_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    try:
        result = image_to_glb(img_path, out_path)
        print(f"\n🎉 输出: {result}")
    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
