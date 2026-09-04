#!/usr/bin/env python3
"""
2D→3D 增强版 v2
纯参数化 + 边缘修正比例 + 合并网格
"""
import sys, os, math, random, warnings
warnings.filterwarnings('ignore')

import numpy as np
from PIL import Image, ImageFilter
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
import trimesh
import trimesh.repair

device = torch.device('cpu')
print(f"🔧 设备: {device}")


# ─────────────────────────────────────────────
# 1. 工具
# ─────────────────────────────────────────────
def simple_kmeans(pixels, n_clusters, seed=42):
    np.random.seed(seed)
    idx = np.random.choice(len(pixels), min(n_clusters, len(pixels)), replace=False)
    centers = pixels[idx].copy()
    for _ in range(20):
        dists = np.linalg.norm(pixels[:, None] - centers[None], axis=2)
        labels = dists.argmin(axis=1)
        nc = np.array([pixels[labels==i].mean(axis=0) if np.any(labels==i) else centers[i]
                       for i in range(n_clusters)])
        if np.allclose(centers, nc, atol=1.): break
        centers = nc
    return centers, labels


# ─────────────────────────────────────────────
# 2. 图像分割
# ─────────────────────────────────────────────
def segment_character(img, tolerance=40):
    arr = np.array(img.convert('RGB')).astype(float)
    h, w = arr.shape[:2]
    corners = np.array([arr[2,2], arr[2,w-3], arr[h-3,2], arr[h-3,w-3]])
    bg = corners.mean(axis=0)
    diff = np.sqrt(np.sum((arr - bg)**2, axis=2))
    mask = (diff > tolerance).astype(np.uint8)
    from scipy.ndimage import binary_opening, binary_closing, label
    mask = binary_opening(mask, iterations=1).astype(np.uint8)
    mask = binary_closing(mask, iterations=2).astype(np.uint8)
    labeled, num = label(mask)
    if num > 0:
        sizes = [(labeled==i).sum() for i in range(1,num+1)]
        ml = sizes.index(max(sizes)) + 1
        mask = (labeled==ml).astype(np.uint8)
    return mask, bg


# ─────────────────────────────────────────────
# 3. 颜色 + 比例分析
# ─────────────────────────────────────────────
def analyze_image(img, mask):
    arr = np.array(img.convert('RGB'))
    ys, xs = np.where(mask > 0)
    if len(ys) == 0:
        return {}
    y_mn, y_mx = ys.min(), ys.max()
    x_mn, x_mx = xs.min(), xs.max()
    char_h = y_mx - y_mn
    char_w = x_mx - x_mn

    roi = arr[y_mn:y_mx+1, x_mn:x_mx+1]
    roi_m = mask[y_mn:y_mx+1, x_mn:x_mx+1]
    sm_y, sm_x = np.where(roi_m > 0)
    if len(sm_y) < 10:
        pixels = roi[roi_m > 0]
    else:
        idx = np.arange(0, len(sm_y), 5)
        pixels = roi[sm_y[idx], sm_x[idx]].astype(float)

    n_clust = min(6, len(pixels))
    if n_clust < 2:
        return {'bbox':(y_mn,y_mx,x_mn,x_mx),'h':char_h,'w':char_w,
                'regions':{},'main_outfit':'mid','arr':arr,
                'shoulder_w':char_w*0.75,'waist_w':char_w*0.45,'hip_w':char_w*0.65,'head_w':char_w*0.22}

    centroids, labels = simple_kmeans(pixels, n_clust)

    reg = {}
    for i, c in enumerate(centroids):
        r, g, b = int(c[0]), int(c[1]), int(c[2])
        s = r + g + b
        if s < 120 and r < 60: lb = 'hair'
        elif 100 < s < 220 and abs(r-g) < 30: lb = 'skin'
        elif s < 80: lb = 'dark'
        elif s > 180 and r > 150: lb = 'shiny'
        elif s > 130: lb = 'light'
        else: lb = 'mid'
        if lb not in reg: reg[lb] = {'color': c, 'count': 0}
        reg[lb]['count'] += np.sum(labels == i)

    main = max(reg.items(), key=lambda x: x[1]['count'])[0]

    def col_width(y, dy):
        row = ys[(ys >= y) & (ys < y + dy)]
        if len(row) == 0: return char_w * 0.5
        cxs = xs[(ys >= y) & (ys < y + dy)]
        return cxs.max() - cxs.min() if len(cxs) > 0 else char_w * 0.5

    shoulder_y = y_mn + int(char_h * 0.22)
    waist_y = y_mn + int(char_h * 0.52)
    hip_y = y_mn + int(char_h * 0.65)

    return {
        'bbox': (y_mn, y_mx, x_mn, x_mx),
        'h': char_h, 'w': char_w,
        'regions': reg, 'main_outfit': main, 'arr': arr,
        'shoulder_w': col_width(shoulder_y, int(char_h*0.08)),
        'waist_w':  col_width(waist_y,   int(char_h*0.08)),
        'hip_w':    col_width(hip_y,     int(char_h*0.08)),
        'head_w':   col_width(y_mn,      int(char_h*0.15)),
    }


# ─────────────────────────────────────────────
# 4. 3D 网格构建
# ─────────────────────────────────────────────
def make_ellipsoid(cx, cy, cz, rx, ry, rz, seg=12, ring=16):
    V, F = [], []
    for i in range(seg+1):
        th = math.pi * i / seg
        for j in range(ring+1):
            ph = 2 * math.pi * j / ring
            V.append([cx+rx*math.sin(th)*math.cos(ph), cy+ry*math.cos(th), cz+rz*math.sin(th)*math.sin(ph)])
    for i in range(seg):
        for j in range(ring):
            a = i*(ring+1)+j; b = a+ring+1
            F.append([a,b,a+1]); F.append([b,b+1,a+1])
    return np.array(V), np.array(F)


def make_capsule(cx, cz, cy, rt, rb, h, nr=8, ns=16):
    V, F = [], []
    ty, by = cy+h/2, cy-h/2
    for i in range(nr+1):
        t = i/nr; y = ty-t*h; r = rt+(rb-rt)*t
        for j in range(ns+1):
            a = 2*math.pi*j/ns
            V.append([cx+r*math.cos(a), y, cz+r*math.sin(a)])
    nc_t = len(V); V.append([cx,ty,cz])
    nc_b = len(V); V.append([cx,by,cz])
    for i in range(nr):
        for j in range(ns):
            a = i*(ns+1)+j; b = a+ns+1
            F.append([a,b,a+1]); F.append([b,b+1,a+1])
    b = nr*(ns+1)
    for j in range(ns):
        F.append([nc_t,j,(j+1)%(ns+1)])
        F.append([nc_b,b+j+1,b+j])
    return np.array(V), np.array(F)


def build_humanoid_v2(prop, regions_data):
    """构建完整人体网格（合并为一个mesh）"""
    bbox = prop.get('bbox', (0,100,0,50))
    y_mn, y_mx, x_mn, x_mx = bbox
    char_h = prop['h']
    char_w = prop['w']

    regions = regions_data.get('regions', {})
    main = regions_data.get('main_outfit', 'mid')

    c_outfit = {'shiny':[210,218,240],'light':[130,120,150],
                'mid':[70,60,90],'dark':[25,20,35]}.get(main, [50,40,70])
    c_hair = [65,65,75]
    if 'hair' in regions:
        hr,hg,hb = regions['hair']['color'][:3]
        c_hair = [int(hr),int(hg),int(hb)]
    c_skin = [220,190,175]

    sw = prop.get('shoulder_w', char_w*0.75)
    ww = prop.get('waist_w',  char_w*0.45)
    hw = prop.get('hip_w',    char_w*0.65)
    hd_w = prop.get('head_w', char_w*0.22)

    h_r=0.115; t_r=0.32; l_r=0.48; f_r=0.065
    total = char_h
    hh=int(total*h_r); th=int(total*t_r); lh=int(total*l_r); fh=int(total*f_r)
    neck_y = fh+lh+th-hh*0.15
    head_cy = fh+lh+th+hh*0.3
    hat_y = fh+lh+th+hh*0.7

    scale = 3.0/(fh+lh+th+hh)
    def S(v): return v*scale

    all_meshes = []

    def add_m(v, f, col):
        colored_v = np.hstack([v, np.tile(col, (len(v),1))])
        m = trimesh.Trimesh(vertices=v, faces=f)
        m.visual.vertex_colors = np.hstack([
            np.full((len(v),3), col, dtype=np.uint8),
            np.full((len(v),1), 255, dtype=np.uint8)
        ])
        all_meshes.append(m)

    def add(cx,cz,cy,rt,rb,h,col,nr=8,ns=16):
        v,f=make_capsule(S(cx),S(cz),S(cy),S(rt),S(rb),S(h),nr,ns)
        add_m(v,f,col)

    def add_e(cx,cy,cz,rx,ry,rz,col,seg=12,ri=16):
        v,f=make_ellipsoid(S(cx),S(cy),S(cz),S(rx),S(ry),S(rz),seg,ri)
        add_m(v,f,col)

    # 脚
    for s in[-1,1]: add(s*char_w*0.12,0,fh*0.5,char_w*0.06,char_w*0.06,fh*0.4,[30,30,38],4,12)
    # 小腿
    for s in[-1,1]: add(s*char_w*0.13,0,fh+lh*0.3,char_w*0.07,char_w*0.06,lh*0.55,c_outfit,6,12)
    # 大腿
    for s in[-1,1]: add(s*char_w*0.15,0,fh+lh*0.7,char_w*0.10,char_w*0.08,lh*0.45,c_outfit,6,12)
    # 臀部
    add(0,0,fh+lh*0.88,hw*0.5,ww*0.5,lh*0.22,c_outfit,6,16)
    # 躯干
    add(0,0,fh+lh+th*0.5,sw*0.5,ww*0.5,th,c_outfit,8,20)
    # 宽肩底座
    add_e(0,fh+lh+th*0.82,0,sw*0.7,hh*0.08,sw*0.7,c_outfit,6,24)
    # 颈部
    add(0,0,S(neck_y),char_w*0.10,char_w*0.09,hh*0.25,c_skin,4,12)
    # 头部
    add_e(0,S(head_cy),0,hd_w*1.0,hh*0.50,hd_w*0.9,c_skin,14,18)
    # 头发
    add_e(0,S(head_cy+hh*0.1),0,hd_w*1.15,hh*0.32,hd_w*1.05,c_hair,10,16)
    # 手臂
    for s in[-1,1]:
        add(s*sw*0.45,0,fh+lh+th*0.78,char_w*0.07,char_w*0.06,th*0.32,c_outfit,6,12)
        add(s*sw*0.52,0,fh+lh+th*0.55,char_w*0.06,char_w*0.05,th*0.28,c_outfit,6,12)
    # 礼帽底座
    add_e(0,S(hat_y),0,hd_w*2.1,hh*0.06,hd_w*1.7,[185,190,220],6,28)
    # 礼帽顶
    add(0,0,S(hat_y+hh*0.18),hd_w*0.9,hd_w*0.9,hh*0.38,[185,190,220],6,20)

    # 合并
    if not all_meshes:
        return None, 1.0
    combined = trimesh.util.concatenate(all_meshes)
    trimesh.repair.fix_normals(combined)
    return combined, scale


# ─────────────────────────────────────────────
# 5. 投影贴图
# ─────────────────────────────────────────────
def project_texture(mesh, regions_data, scale):
    arr = regions_data.get('arr', np.zeros((100,100,3),dtype=np.uint8))
    bbox = regions_data.get('bbox',(0,100,0,100))
    y_mn,y_mx,x_mn,x_mx = bbox
    char_h = regions_data['h']; char_w = regions_data['w']

    verts = mesh.vertices.copy()
    colors = mesh.visual.vertex_colors.copy().astype(float)
    y_vmn,y_vmx = verts[:,1].min(),verts[:,1].max()
    y_rng = max(y_vmx - y_vmn, 0.001)

    for i, v in enumerate(verts):
        ty = (v[1]-y_vmn)/y_rng
        iy = int(np.clip(y_mn+ty*char_h, 0, arr.shape[0]-1))
        tx = v[0]/(scale*max(char_w,1)) + 0.5
        ix = int(np.clip(x_mn+tx*char_w, 0, arr.shape[1]-1))
        if 0 <= iy < arr.shape[0] and 0 <= ix < arr.shape[1]:
            r, g, b = arr[iy, ix]
            colors[i] = [r, g, b, 255]

    mesh.visual.vertex_colors = colors.astype(np.uint8)
    return mesh


# ─────────────────────────────────────────────
# 6. 主流程
# ─────────────────────────────────────────────
def image_to_glb(img_path, output_path=None, verbose=True):
    if verbose:
        print(f"📷 加载: {img_path}", flush=True)
    img = Image.open(img_path)
    if verbose:
        print(f"   尺寸: {img.size}", flush=True)

    if verbose:
        print("🔍 分割角色...", flush=True)
    mask, bg = segment_character(img)

    if verbose:
        print("🎨 颜色+比例分析...", flush=True)
    regions_data = analyze_image(img, mask)
    char_h = regions_data['h']; char_w = regions_data['w']
    if verbose:
        regions = regions_data.get('regions', {})
        print(f"   角色尺寸: {char_w}×{char_h}px, 服装: {regions_data.get('main_outfit','?')}", flush=True)
        print(f"   肩宽:{regions_data.get('shoulder_w',0):.0f} 腰宽:{regions_data.get('waist_w',0):.0f} 臀宽:{regions_data.get('hip_w',0):.0f}", flush=True)

    if verbose:
        print("🧊 构建3D人体...", flush=True)
    mesh, scale = build_humanoid_v2(regions_data, regions_data)

    if verbose:
        print("🖼️ 投影纹理...", flush=True)
    mesh = project_texture(mesh, regions_data, scale)

    # 闪钻效果
    regions = regions_data.get('regions', {})
    if 'shiny' in regions:
        colors = mesh.visual.vertex_colors.copy().astype(float)
        for i, vc in enumerate(colors):
            if np.mean(vc[:3]) > 160:
                colors[i,:3] = np.clip(colors[i,:3] * 1.1 + 15, 0, 255)
        mesh.visual.vertex_colors = colors.astype(np.uint8)

    if output_path is None:
        name = os.path.splitext(os.path.basename(img_path))[0]
        output_path = f"{name}_v2.glb"

    if verbose:
        print(f"💾 导出: {output_path}", flush=True)
    mesh.export(output_path)

    nv = len(mesh.vertices); nf = len(mesh.faces)
    sz = os.path.getsize(output_path)/1024
    if verbose:
        print(f"✅ 完成！{nv}顶点/{nf}面 ({sz:.1f} KB)", flush=True)
    return output_path


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: python enhanced_image_to_glb.py <图片> [输出GLB]")
        sys.exit(1)
    img_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else None
    try:
        result = image_to_glb(img_path, out_path)
        print(f"\n🎉 输出: {result}")
    except Exception as e:
        import traceback
        traceback.print_exc()
        sys.exit(1)
