#!/usr/bin/env python3
"""
神经 2D→3D 管线（完全从零训练，无外部权重依赖）
流程：合成球体/椭球渲染 → 训练深度预测网络 → 推理真实图片 → 深度图 → 点云 → 网格
"""
import sys, os, math, random, warnings
warnings.filterwarnings('ignore')

import numpy as np
from PIL import Image
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
import trimesh

device = torch.device('cpu')
print(f"🔧 设备: {device}")

# ─────────────────────────────────────────────
# 1. 向量化合成数据（numpy广播，不循环）
# ─────────────────────────────────────────────
def make_grid(s):
    xs = np.linspace(-1, 1, s)
    ys = np.linspace(-1, 1, s)
    return np.meshgrid(xs, ys)

class DepthDataset(Dataset):
    def __init__(self, size=1000, s=128):
        self.size = size
        self.s = s
        self.X, self.Y = make_grid(s)
        self.Z = -np.ones_like(self.X)

    def __len__(self):
        return self.size

    def __getitem__(self, idx):
        cz = random.uniform(2.0, 3.5)
        cr = random.uniform(0.3, 0.7)
        col = np.array([
            random.randint(80, 255),
            random.randint(80, 255),
            random.randint(80, 255)
        ], dtype=np.float32)

        # 球射线求交
        b2 = 2 * (self.X * 0 + self.Y * 0 + self.Z * (-cz))
        c2 = cz**2 - cr**2
        disc = np.clip(b2**2 - 4*c2, 0, None)
        t = (-b2 - np.sqrt(disc)) / 2
        depth = np.where(t > 0.1, t, 15.0)

        # 法线 shading
        Nx, Ny, Nz = self.X/cr, self.Y/cr, self.Z/cr
        norm = np.sqrt(Nx**2+Ny**2+Nz**2) + 1e-8
        Nx, Ny, Nz = Nx/norm, Ny/norm, Nz/norm
        shade = np.clip(0.3 + 0.7*(Nz*-1 + 1)/2, 0, 1)

        valid = depth < 14.0
        rgb = (col * shade[:,:,None] / 255.0).clip(0,1)
        img = np.zeros((self.s, self.s, 3), dtype=np.uint8)
        img[valid] = (rgb[valid]*255).astype(np.uint8)

        d_norm = ((depth - 1.0)/14.0).clip(0, 1).astype(np.float32)
        return (torch.from_numpy(img).permute(2,0,1).float()/255,
                torch.from_numpy(d_norm).float().unsqueeze(0))

# ─────────────────────────────────────────────
# 2. 轻量深度预测网络 (~200K params)
# ─────────────────────────────────────────────
class DepthNet(nn.Module):
    def __init__(self):
        super().__init__()
        # 编码器
        self.enc = nn.ModuleList([
            nn.Sequential(nn.Conv2d(3,  32, 3, padding=1), nn.BatchNorm2d(32),  nn.ReLU(inplace=True)),
            nn.Sequential(nn.Conv2d(32, 64, 3, padding=1), nn.BatchNorm2d(64),  nn.ReLU(inplace=True)),
            nn.Sequential(nn.Conv2d(64,128, 3, padding=1), nn.BatchNorm2d(128), nn.ReLU(inplace=True)),
            nn.Sequential(nn.Conv2d(128,256,3, padding=1), nn.BatchNorm2d(256), nn.ReLU(inplace=True)),
        ])
        self.pools = [nn.MaxPool2d(2) for _ in range(4)]
        # 解码器
        self.dec = nn.ModuleList([
            nn.Sequential(nn.Conv2d(256,128,3,padding=1), nn.BatchNorm2d(128), nn.ReLU(inplace=True)),
            nn.Sequential(nn.Conv2d(128, 64,3,padding=1), nn.BatchNorm2d(64),  nn.ReLU(inplace=True)),
            nn.Sequential(nn.Conv2d(64,  32,3,padding=1), nn.BatchNorm2d(32),  nn.ReLU(inplace=True)),
            nn.Sequential(nn.Conv2d(32,  16,3,padding=1), nn.BatchNorm2d(16),  nn.ReLU(inplace=True)),
        ])
        self.head = nn.Conv2d(16, 1, 1)

    def forward(self, x):
        feats = []
        for i, enc in enumerate(self.enc):
            x = enc(x)
            if i < 3: x = self.pools[i](x)
            feats.append(x)

        for i, dec in enumerate(self.dec):
            if i < 3:
                x = self.pools[3](x)  # down
            x = dec(x)
            if i < 3:
                # 上采样 + 跳跃连接（简化版）
                tgt = feats[2-i]
                x = F.interpolate(x, size=tgt.shape[2:], mode='bilinear', align_corners=False) + tgt * 0.5

        x = F.interpolate(x, size=(128, 128), mode='bilinear', align_corners=False)
        out = self.head(x)
        return torch.sigmoid(out)


# ─────────────────────────────────────────────
# 3. 训练
# ─────────────────────────────────────────────
def train(model, epochs=5, bs=16):
    ds = DepthDataset(size=1000, s=args.size)
    dl = DataLoader(ds, batch_size=8, shuffle=True, num_workers=0)
    opt = torch.optim.Adam(model.parameters(), lr=3e-4)
    crit = nn.MSELoss()
    model.train()
    for ep in range(epochs):
        loss_sum = 0
        for imgs, depths, in dl:
            imgs, depths = imgs.to(device), depths.to(device)
            opt.zero_grad()
            pred = model(imgs)
            loss = crit(pred, depths)
            loss.backward()
            opt.step()
            loss_sum += loss.item()
        print(f"  Epoch {ep+1}/{epochs} loss={loss_sum/len(dl):.6f}", flush=True)
    model.eval()
    return model


# ─────────────────────────────────────────────
# 4. 推理：图片 → 深度 → 点云 → 网格
# ─────────────────────────────────────────────
def predict_depth(model, img: Image.Image, size=128):
    model.eval()
    arr = np.array(img.convert('RGB').resize((size, size), Image.LANCZOS), dtype=np.float32)/255.
    x = torch.from_numpy(arr).permute(2,0,1).unsqueeze(0).to(device)
    with torch.no_grad():
        d = model(x)[0,0].cpu().numpy()
    depth = d*14.+1.
    return np.clip(depth, 0.5, 15.), (arr*255).astype(np.uint8)


def depth_to_mesh(img_arr, depth, n_pts=5000, vox=0.06):
    h, w = depth.shape
    pts, cols = [], []
    for _ in range(n_pts):
        y = random.randint(0, h-1)
        x = random.randint(0, w-1)
        d = depth[y, x]
        if d > 12: continue   # 阈值放宽
        scale = d/3.
        px = (x/w - .5)*2*scale
        py = (y/h - .5)*2*scale
        pz = -d
        pts.append([px, py, pz])
        r,g,b = img_arr[y,x]
        cols.append([r/255., g/255., b/255.])

    pts = np.array(pts)
    cols = np.array(cols)
    print(f"   有效点数: {len(pts)}", flush=True)
    if len(pts) < 100:
        print("   ⚠️ 点太少，尝试更宽松阈值...", flush=True)
        # 再试一次，放宽
        for _ in range(n_pts):
            y = random.randint(0, h-1)
            x = random.randint(0, w-1)
            d = depth[y, x]
            if d > 14: continue
            scale = d/3.
            px = (x/w - .5)*2*scale
            py = (y/h - .5)*2*scale
            pz = -d
            pts = np.vstack([pts, [px,py,pz]]) if len(pts)>0 else np.array([[px,py,pz]])
            r,g,b = img_arr[y,x]
            cols = np.vstack([cols, [r/255.,g/255.,b/255.]]) if len(cols)>0 else np.array([[r/255.,g/255.,b/255.]])
        print(f"   放宽后点数: {len(pts)}", flush=True)
        if len(pts) < 50:
            raise ValueError(f"点太少 ({len(pts)})，重建失败")

    # 体素化
    mn = pts.min(0)
    g = ((pts - mn)/vox).astype(int)
    occ = set(map(tuple, g))

    verts, vcols, faces = {}, [], []
    vid = 0
    def vid4(gx,gy,gz):
        k = (gx,gy,gz)
        if k not in verts:
            verts[k] = vid
            vcols.append(cols[random.randint(0,len(cols)-1)])
            vid += 1
        return verts[k]

    for (gx,gy,gz) in occ:
        for dx,dy,dz in [(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]:
            if (gx+dx,gy+dy,gz+dz) not in occ:
                v0=vid4(gx,gy,gz)
                v1=vid4(gx+1,gy,gz)
                v2=vid4(gx+1,gy+1,gz)
                v3=vid4(gx,gy+1,gz)
                faces.append([v0,v2,v1]); faces.append([v0,v3,v2])

    V = np.array([k for k in verts])*vox + mn
    F = np.array(faces)
    C = np.array(vcols)
    mesh = trimesh.Trimesh(vertices=V, faces=F,
                           vertex_colors=(C*255).astype(np.uint8))
    trimesh.repair.fix_normals(mesh)
    return mesh


# ─────────────────────────────────────────────
# 5. 主
# ─────────────────────────────────────────────
if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('image')
    p.add_argument('-o', '--output')
    p.add_argument('--epochs', type=int, default=8)
    p.add_argument('--size', type=int, default=128, help='训练图像尺寸')
    p.add_argument('--model', type=str, default=None)
    p.add_argument('--train-only', action='store_true')
    args = p.parse_args()

    model = DepthNet().to(device)
    n_params = sum(x.numel() for x in model.parameters())
    print(f"模型参数: {n_params:,}", flush=True)

    # 加载或训练
    if args.model and os.path.exists(args.model):
        print(f"📦 加载已有模型: {args.model}", flush=True)
        model.load_state_dict(torch.load(args.model, map_location=device, weights_only=True))
        model.eval()
    else:
        print(f"\n🚀 开始训练（{args.epochs} epochs, {args.size}×{args.size}）...", flush=True)
        train(model, epochs=args.epochs, bs=8)
        if args.model:
            torch.save(model.state_dict(), args.model)
            print(f"💾 模型已保存: {args.model}", flush=True)

    if args.train_only:
        sys.exit(0)

    # 推理
    img_path = args.image
    out_path = args.output or (os.path.splitext(os.path.basename(img_path))[0] + '_nn.glb')

    print(f"\n📷 推理: {img_path}", flush=True)
    img = Image.open(img_path)
    print(f"   尺寸: {img.size}", flush=True)

    print("🧠 深度预测...", flush=True)
    depth, rgb = predict_depth(model, img, size=128)
    print(f"   深度范围: {depth.min():.2f} ~ {depth.max():.2f}", flush=True)

    print("☁️ 生成点云...", flush=True)
    print("🧊 网格重建...", flush=True)
    mesh = depth_to_mesh(rgb, depth, n_pts=5000, vox=0.08)
    print(f"   顶点数: {len(mesh.vertices)}, 面数: {len(mesh.faces)}", flush=True)

    # 居中
    center = mesh.vertices.mean(axis=0)
    mesh.vertices -= center

    print(f"💾 导出: {out_path}", flush=True)
    mesh.export(out_path)
    print(f"✅ 完成！{out_path} ({os.path.getsize(out_path)/1024:.1f} KB)", flush=True)
