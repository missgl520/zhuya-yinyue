# QQ 炫舞角色 2D→3D 管线

将时装立绘（正面站立图）自动转换为 3D GLB 模型，用于 zhuya-yinyue 换装系统。

---

## 管线概览

```
原图 (JPG) → 角色分割 → 颜色聚类(K-Means) → 比例检测 → 参数化人体建模 → GLB
              ↓                              ↓
         背景抠除                      顶点颜色投影
```

**三条生成路径：**

| 脚本 | 精度 | 速度 | 依赖 | 适用场景 |
|------|------|------|------|---------|
| `image_to_glb.py` | ⭐⭐ | 快 | numpy, PIL, trimesh | 快速预览 |
| `nn_image_to_3d.py` | ⭐⭐⭐ | 慢 | + PyTorch | 神经网络推理 |
| `enhanced_image_to_glb.py` | ⭐⭐⭐⭐ | 快 | 同 image_to_glb.py | **生产推荐** |

---

## 快速开始

### 方式一：增强参数化版（推荐）

```bash
# 分析图片、检测比例、生成GLB
python3 tools/enhanced_image_to_glb.py \
  /path/to/fashion.jpg \
  -o output/avatar.glb
```

输出：
```
📷 加载: fashion.jpg
   尺寸: 489×460
🔍 分割角色...
🎨 颜色+比例分析...
   角色尺寸: 469×424px, 服装: shiny
   肩宽:88 腰宽:144 臀宽:194
🧊 构建3D人体...
🖼️ 投影纹理...
💾 导出: output/avatar.glb
✅ 完成！1958顶点/4016面 (78.6 KB)
```

### 方式二：神经网络深度预测版（需先训练）

```bash
# 训练深度预测网络（8 epochs，约5分钟）
python3 tools/nn_image_to_3d.py \
  /path/to/fashion.jpg \
  -o output/avatar_nn.glb \
  --epochs 8 \
  --model output/depth_net.pth

# 已有模型时跳过训练
python3 tools/nn_image_to_3d.py \
  /path/to/fashion.jpg \
  -o output/avatar_nn.glb \
  --model output/depth_net.pth
```

---

## 模型文件

```
assets/web/models/
├── avatar_female.glb          # 参数化版 v1（1958顶点）
├── avatar_female_enhanced.glb  # 早期测试版（264顶点）
├── avatar_female_v2.glb       # ✅ 增强参数化版（1958顶点）← 主用
├── avatar_male.glb            # 参数化版 v1（1958顶点）
├── avatar_male_v2.glb         # ✅ 增强参数化版（1958顶点）← 主用
├── depth_net.pth              # 深度预测网络权重（3.1MB）
└── edge_net.pth               # 边缘检测网络权重（6.7MB）
```

---

## 技术细节

### 角色分割（`segment_character`）

1. 取四角背景色取平均
2. 计算每个像素到背景的欧氏距离
3. 阈值 `tolerance=40` 二值化
4. `scipy.ndimage.binary_opening/closing` 去噪
5. 连通域标注，取最大连通区域

### 颜色聚类（`simple_kmeans`）

- K=6，纯 NumPy 实现，迭代20次收敛
- 按亮度/色相分类：头发、皮肤、服装（亮/中/暗/闪钻）
- 主体色作为服装主色调

### 身体比例检测（`analyze_proportions`）

从分割掩码的纵向轮廓提取：
- **肩宽**：角色高度 22% 处宽度
- **腰宽**：角色高度 52% 处宽度
- **臀宽**：角色高度 65% 处宽度
- **头宽**：角色高度 15% 处宽度

这些比例直接映射到 3D 胶囊/椭球体的半径参数。

### 人体建模（`build_humanoid_v2`）

```
身体比例分配（以角色像素高度为基准）：
┌──────────────────────────┐
│ 礼帽顶        ━━━━━━━━━   │  hh * 0.38
├──────────────────────────┤
│ 礼帽底座      ═══════════ │  hh * 0.06
├──────────────────────────┤
│ 头发         ◯           │  hd_w*1.15 × hh*0.32
│ 头部         ●           │  hd_w*1.0  × hh*0.50
│ 颈部         ┃           │  hh * 0.25
├──────────────────────────┤
│ 躯干         ║           │  th（角色高32%）
│ 肩宽底座     ▭           │  sw*0.7 × hh*0.08
│ 臀部         ▯           │  hw*0.5 × lh*0.22
├──────────────────────────┤
│ 上臂×2       ┃  ┃        │  th*0.32
│ 前臂×2       ┃  ┃        │  th*0.28
├──────────────────────────┤
│ 大腿×2       ▐  ▌        │  lh*0.45（角色高48%）
│ 小腿×2       ▔  ▔        │  lh*0.55
├──────────────────────────┤
│ 脚×2         ▪  ▪        │  fh*0.40（角色高6.5%）
└──────────────────────────┘
```

所有部件用 `trimesh.util.concatenate()` 合并为单一 mesh（共享顶点的合并，不是简单叠加）。

### 顶点颜色投影（`project_texture`）

- Y轴（身高）→ 图像纵向坐标
- X轴（肩→腰宽）→ 图像横向坐标
- 闪钻区域（`shiny` 聚类）顶点亮度 ×1.1 + 15

### 神经网络（`nn_image_to_3d.py`）

**架构：** `LightDepthNet` — 4层编码器 + 4层解码器 + skip connection

```
输入 (3, H, W)          输出 (1, H, W)
─────────────────       ─────────────────
Conv 3→64 + BN + ReLU   ↑
MaxPool                 ConvT 256→128 + concat(enc3) + BN + ReLU  ↑
Conv 64→128 + BN        MaxPool                                  ↑
Conv 128→256 + BN       ConvT 128→64  + concat(enc2) + BN + ReLU ↑
MaxPool                 ConvT 64→32   + concat(enc1) + BN + ReLU  ↑
Conv 256→512 + BN       ConvT 32→16   + ReLU
Conv 512→1024            ConvT 16→1    + Sigmoid
MaxPool
Conv 1024→512            (781,793 参数)
```

**训练数据：** 纯合成，无外部依赖
- 在 [-1,1]² 视口内随机放置球体（`cx∈[-0.5,0.5]`, `cz∈[2,3.5]`, `r∈[0.3,0.7]`）
- 解析球面公式计算每个像素的深度值
- 按深度映射颜色（`c * (0.3 + 0.7*shade)`）
- 每次渲染不同球体模拟不同场景

**训练结果：**
| Epoch | Loss |
|-------|------|
| 1 | 0.1195 |
| 4 | 0.0301 |
| 8 | 0.0079 |

**推理：** 图片 resize 到 128×128 → 预测深度图 → 采样 5000 点 → Marching Cubes 体素化

---

## 与 avatar_viewer.html 集成

`avatar_viewer.html` 的换装槽位：

```javascript
const SLOTS = {
  hair:     { name: '发型', file: 'hair_001.glb' },
  top:      { name: '上衣', file: 'top_001.glb'  },
  bottom:   { name: '下装', file: 'bot_001.glb'  },
  shoe:     { name: '鞋子', file: 'shoe_001.glb' },
  accessory:{ name: '配饰', file: 'acc_001.glb'  },
};

// 加载基础模型
function loadBase(file) {
  const path = `models/${file}`;
  loader.load(path, gltf => {
    scene.add(gltf.scene);
    currentBase = gltf.scene;
  });
}

// 使用 v2 模型作为 base
loadBase('avatar_female_v2.glb');  // 女性
loadBase('avatar_male_v2.glb');    // 男性
```

模型路径通过 `hsk-cli` 部署后公开访问，或上传到 GitHub + jsdelivr CDN：

```javascript
// jsdelivr CDN 引用（推荐）
const CDN_BASE = 'https://cdn.jsdelivr.net/gh/missgl520/zhuya-yinyue@main/assets/web';
loader.load(`${CDN_BASE}/models/avatar_female_v2.glb`, ...);
```

---

## 公开预览

- **3D 预览页面（hsk-cli）：** https://am4xor.gicp.fun
- **破网分享：** https://unfurl.anmuji.com/p/GL287m7vvjdT-PH0XmTw3YIBnqccAh3C

---

## 依赖

```txt
# 核心（已装）
numpy          - 数值计算、矩阵运算
Pillow         - 图像读写、滤波
trimesh        - 3D 网格构建、GLB 导出
scipy.ndimage  - 连通域标注、形态学运算

# 神经网络（可选）
torch (CPU)    - `pip install torch --index-url https://download.pytorch.org/whl/cpu`
```

### 安装命令

```bash
# 基础管线
pip install numpy Pillow trimesh scipy --break-system-packages

# 神经网络（CPU版）
pip install torch --index-url https://download.pytorch.org/whl/cpu --break-system-packages
```

---

## 后续优化方向

1. **Blender 精修** — 导入 GLB 后手动美化拓扑，做骨骼绑定走路动画
2. **TripoSR** — 网络好时加载预训练模型，提升重建精度
3. **纹理贴图** — 目前只有顶点颜色（vertex colors），可用 UV 展开 + 2D 纹理图
4. **骨骼动画** — Mixamo 自动绑定走路/待机动画
5. **接入 avatar_viewer.html** — 替换 loadBase() 使用 v2 模型
