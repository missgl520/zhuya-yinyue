# 竹笌 × 音乐狗子 合并重设计 · UI/UX 设计规范（DESIGN.md）

> 设计寄存器：**Product Register**（设计服务产品，标杆 = 赢得熟悉感 / 可信赖）
> 设计可调参数：`DESIGN_VARIANCE=5`（左对齐 + 非对称留白，禁用居中 Hero） · `MOTION_INTENSITY=5`（功能性动效为主，≤300ms） · `VISUAL_DENSITY=4`（日常应用密度）
> 版本：v1.0（合并重设计基线） · 设计师：颜好看 · 状态：待架构师锁定图标库后冻结

---

## 0. 合并重设计总纲

竹笌 = 整体 App（**竹笋绿系视觉**，语音优先陪伴）；音乐狗子 = 新增**音乐模块**，以「狗子 3D 宠物 + 创作台」形态寄生在竹笌内。

- **单一视觉母体**：所有页面共用竹绿主色 + 暖色点缀，禁止出现第二套独立配色（旧音乐狗子的纯橙 `#FFF8F0` 体系并入 `surface-warm` + `--sun`/`--ember`）。
- **角色即导航**：3D 竹笌（聊天陪伴）与 3D 狗子（音乐）是两大活体入口，不是装饰。
- **去模板化**：无居中 Hero、无 emoji 图标、无紫粉渐变、无硬编码色值、无 "Welcome to" 文案。

---

## 1. 设计语言与对标品牌

### 1.1 设计语言关键词
**竹语·声场（Bamboo Voice × Sound Field）** —— 少年感、阳光、直接、有温度；语音优先、角色在场、创作即反馈。

### 1.2 对标品牌与选择理由

| 维度 | 对标品牌 | 借鉴什么 | 为什么选它（而非其他） |
|------|----------|----------|------------------------|
| 语音陪伴 | **Replika** | 沉浸式单屏、情绪芯片、打字动画、AR 在场感、sleek minimal | 陪伴类标杆中"存在感"做得最好，界面克制不花哨，契合竹笌"信纸式对话 + 3D 角色同屏" |
| 语音陪伴 | **Character.AI** | 角色人设、记忆连续性、quick-reply、情绪徽章 | 证明"角色人格 + 记忆"是陪伴留存核心，指导狗子/竹笌的 mood & loveMeter 系统 |
| 音乐创作 | **Suno** | 左侧创作面板、时间线编辑器、媒体 App 式直觉、快 | 入门门槛最低、流程最顺；指导音乐狗子"创作台"的 prompt→生成→编辑 一行流 |
| 音乐创作（声场氛围） | **Udio** | 深色工作室、波形元素、发光脉冲按钮、几何无衬线 | 借鉴其"录音棚能量"，但**将其霓虹粉 `#E30B5D` 替换为竹绿/暖橙能量**，规避紫粉渐变 |
| 结构/设置 | **Linear / Notion** | 列表密度、聚焦态、空状态、设置分组 | 指导"我的/设置/记忆历史"的信息架构，做到可信赖而非模板 |

**不对标**：Character.AI 的纯文字头像（我们要 3D 在场）、Candy AI 的艳俗动漫风（过度情色化、廉价感）、Udio 的霓虹粉（P0 紫粉渐变红线）。

---

## 2. 完整 Design Token（四层架构：A1 / A2 / B-slot / C-extension）

> 命名按**用途**而非色相（不叫 `--green`）。所有组件**禁止硬编码色值**，一律引用以下 Token。
> 唯一例外：`#FFFFFF`/`#000000` 仅用于纯白描边/纯黑遮罩。

### 2.1 Surface（表面层）

| Token | 层 | 浅色 | 深色 | 用途 |
|-------|----|------|------|------|
| `--bg` | A1 | `#F1F6EE` 竹雾 | `#0E1512` 深竹黑 | 页面背景（替换旧 `#EDF7F0` 统一命名） |
| `--surface` | A1 | `#FFFFFF` | `#16201B` | 卡片/容器 |
| `--surface-warm` | B | `#FBF4E9` 暖米 | `#1E1A14` 暖深 | 音乐狗子/我的页暖区（替换旧 `#F5EFE5`/`#FFF8F0`） |
| `--surface-sunken` | B | `#E9F0E5` | `#0A0F0D` | 输入框/凹陷区 |

### 2.2 Foreground（前景层）

| Token | 层 | 浅色 | 深色 | 用途 |
|-------|----|------|------|------|
| `--fg` | A1 | `#1E2B1E` 竹墨 | `#E8F0E4` | 主文本（替换旧 `#212121`，加绿调） |
| `--fg-2` | B | `#44563F` | `#B6C4AE` | 次级文本 |
| `--muted` | A1 | `#6E7C68` | `#859384` | 辅助/说明（替换旧 `#757575`） |
| `--meta` | B | `#9AA89A` | `#5C685C` | 三级/元数据 |

### 2.3 Border（边框层）

| Token | 层 | 浅色 | 深色 | 用途 |
|-------|----|------|------|------|
| `--border` | A1 | `#DDE6D8` | `#253029` | 默认 1px 边框 |
| `--border-soft` | B | `#EAF0E7` | `#1C251F` | 内部行分隔 |

### 2.4 Accent（强调色 —— ⚠️ 每屏 ≤ 2 处可见使用）

| Token | 层 | 浅色 | 深色 | 用途 |
|-------|----|------|------|------|
| `--accent` | A1 | `#7CB342` 竹绿 | `#8BD14F` 亮竹 | 品牌主色：按钮/图标/Logo/发送键 |
| `--accent-deep` | A2 | `#4E7C2A` 深竹 | `#5E9E2E` | 竹底上的文字、按下态、左边线 |
| `--accent-soft` | C | `#E8F3DE` | `#1C2A17` | 选中/高亮底（chip、active tab） |
| `--sun` | A2 | `#F2A33C` 暖金 | `#F4B454` | **音乐狗子能量色** + 用户气泡（替换旧 `#FFD54F`/`orange`） |
| `--sun-soft` | C | `#FCEBD2` | `#2A2113` | 暖区底 |
| `--ember` | C | `#FF7A45` 暖珊瑚 | `#FF8A5C` | **音乐动作色**（录音/生成/播放），**暖橙非粉** |
| `--ember-soft` | C | `#FFE3D6` | `#2A1813` | 动作态底 |

### 2.5 Semantic（语义色 —— 全部非粉系）

| Token | 层 | 浅色 | 深色 | 用途 |
|-------|----|------|------|------|
| `--success` | A2 | `#4CAF50` | `#5FBF63` | 成功/在线 |
| `--warn` | A2 | `#E0A106` | `#E8AE1C` | 警告 |
| `--danger` | A2 | `#C1463B` | `#D96458` | 错误/挂断（暖红，**非粉**） |
| `--info` | A2 | `var(--accent)` | `var(--accent)` | 信息 |

### 2.6 Typography（字体 —— 禁止 Fraunces/Playfair/Space Grotesk 等模板字体）

```css
--font-display: "Smiley Sans", "Inter", "Noto Sans SC", sans-serif; /* 少年系 punchy 短标题，稀疏使用 */
--font-body:    "Inter", "Noto Sans SC", sans-serif;                /* 正文/英文/数字 */
--font-mono:    "JetBrains Mono", "Space Mono", monospace;          /* 歌词时间轴/波形标签/技术态 */
```

**字阶（8 级）**：`--text-xs 12` · `--text-sm 14` · `--text-base 16` · `--text-md 18` · `--text-lg 20` · `--text-xl 24` · `--text-2xl 32` · `--text-3xl 40`（Hero 可到 48，用 `--font-display`）。

**字距规则**：正文 `0`；小字/ALL-CAPS `0.04–0.08em`；标题 ≥32px `-0.01em`；`--font-display` 短标题 `-0.02em`。
**字重**：Read 400 · Emphasize 510 · Announce 590/700（display 用 700/900）。
**行高**：正文 1.6 · 标题 1.2。

### 2.7 Spacing（4px 网格，禁止 5/7/13/15/22/30）

`--space-1 4` · `--space-2 8` · `--space-3 12` · `--space-4 16` · `--space-5 20` · `--space-6 24` · `--space-8 32` · `--space-10 40` · `--space-12 48` · `--space-16 64` · `--space-20 80`。

### 2.8 Radius（圆角）

`--radius-sm 8`（小组件/标签）· `--radius-md 12`（卡片）· `--radius-lg 16`（大卡片）· `--radius-xl 20`（气泡/主按钮）· `--radius-pill 9999`。**卡片上限 16，禁止 ≥24 过度圆滑**。

### 2.9 Elevation（阴影 / 层级）

| Token | 值（浅/深） | 用途 |
|-------|-------------|------|
| `--elev-flat` | `none` | 默认（用边框界定） |
| `--elev-ring` | `0 0 0 1px var(--border)` | hover/选中环 |
| `--elev-raised` | `0 1px 2px rgba(30,43,30,.04), 0 4px 12px rgba(30,43,30,.06)` | 浮起卡片/弹层 |

深色模式**靠亮度递进表达层级，不靠阴影**（bg→surface→surface-warm 三档亮度）。

### 2.10 Focus & Motion

```css
--focus-ring: 0 0 0 3px color-mix(in srgb, var(--accent) 35%, transparent);
--motion-fast: 150ms;   /* hover/选中 */
--motion-base: 200ms;   /* 进入/展开 */
--motion-page: 320ms;   /* 跨页 */
--ease-standard: cubic-bezier(0.2, 0, 0, 1);
```
**必须** `@media (prefers-reduced-motion: reduce)` 关闭非必要动画。

### 2.11 主题切换（浅/深）

- 浅色：竹雾底 `--bg` + 白卡 `--surface`，少年感阳光。
- 深色：**竹调深底**（替换旧 navy-purple `#1A1A2E`），避免紫调。背景 `#0E1512`，表面 `#16201B`，强调色提亮到 `#8BD14F`。
- 跟随系统 + 设置手动覆盖（`themeProvider`）。

---

## 3. 图标系统（⚠️ P0：禁止 emoji 图标）

**锁定图标库：Lucide（`lucide.dev`）** —— 统一 24px 网格、描边线图标、跨端一致（Web SVG + Flutter `lucide_icons` 包）。
**尺寸规范**：`16px`（行内/小标）· `20px`（按钮内）· `24px`（导航/独立图标）。描边 `1.75`（16px）/ `2`（20–24px），`stroke-linecap: round`。颜色 `currentColor`，不单独设色。

**现状迁移映射（旧 Material/emoji → Lucide）**：

| 旧代码 | 问题 | 新 Lucide |
|--------|------|-----------|
| `Icons.arrow_back` | Material | `ArrowLeft` |
| `Icons.music_note` | Material | `Music` |
| `Icons.library_music` | Material | `Library` |
| `Icons.pets` | Material | `Dog` |
| `Icons.chevron_right` | Material | `ChevronRight` |
| `Icons.settings` | Material | `Settings` |
| `🐕` (pet_studio) | **emoji P0** | `Dog` |
| `💕` (loveMeter) | **emoji P0** | `Heart` |
| `😄` (mood) | **emoji P0** | `Smile` / 情绪用 `--sun` 色点 |

**铁律**：任何功能图标一律走 Lucide；emoji 仅允许出现在用户 UGC 文本，绝不作 UI 图标。

---

## 4. 页面清单与设计意图（全量重设计）

| # | 路由 | 页面 | 一句话设计方向 |
|---|------|------|----------------|
| 1 | `/splash` | 启动页 | 竹笋破土生长微动画 + 品牌字 reveal，300ms 内过渡到首页，不堆标语。 |
| 2 | `/home`（`/chat`） | 首页·聊天陪伴 | 「信纸式对话 + 3D 竹笌同屏」：左/上角色在场、下信纸气泡流、底部语音优先输入，情绪芯片悬浮。 |
| 3 | `/music` | 音乐狗子模块 | 狗子 3D 宠物居中 + 底部三态切换（创作台/歌词库/宠物），竹绿×暖橙"声场"，录音/生成用 `--ember` 脉冲。 |
| 4 | `/discover` | 发现·竹林 | 沉浸竹林背景（CustomPaint 竹柱）+ 左下吉祥物入口，去 tab、大留白，点竹笌进 `/avatar`。 |
| 5 | `/avatar` | 3D 角色页 | 全屏角色互动：表情/换装/背景切换，用 `--accent-soft` 面板而非侧条纹卡片。 |
| 6 | `/voice` | 实时语音通话 | LiveKit 全屏角色 + 实时波形（mono 标签时间轴），挂断键用 `--danger` 暖红圆钮。 |
| 7 | `/profile` | 我的 | 统一竹系（弃用旧米棕 `#F5EFE5`），头像 + 收藏/模块/设置的清晰分组（Linear 密度）。 |
| 8 | `/settings` | 设置 | 分组列表（外观/账号/数据/关于），右侧 `ChevronRight`，切换用 `--accent` 开关。 |
| 9 | `/settings/memory` | 记忆历史 | 时间线式记忆流，空状态有引导文案 + 操作钮（无"暂无数据"裸字）。 |
| 10 | `/settings/modules` | 模块信息 | 已启模块卡片（竹笌/狗子），`--accent-soft` 标识开启态。 |
| 11 | 音乐狗子·创作台 | 创作台（模块内） | 左 prompt 输入 + 右生成结果，快捷语 chip 用 `--sun-soft`，生成中骨架屏。 |
| 12 | 音乐狗子·歌词库 | 歌词库（模块内） | 歌词卡片列表，mono 时间轴，点击展开编辑（Suno 式时间线）。 |
| 13 | 音乐狗子·宠物 | 宠物状态（模块内） | 狗子 mood（Lucide `Smile` 等）+ loveMeter 进度条用 `--sun`，**去粉去 emoji**。 |

---

## 5. 组件状态矩阵（5 态必覆盖）

每个核心组件（按钮/卡片/输入/列表/生成结果）覆盖：**Default · Hover · Focus(`--focus-ring`) · Active · Disabled · Loading(骨架/Spinner) · Error(具体文案+重试) · Empty(引导+操作) · Success(短暂 toast)**。

- 输入：可见 label + 错误近字段 + helper text。
- 生成结果：Loading 用波形骨架，Error 暴露"重试"而非技术栈。
- 列表：空状态必有引导动作。

---

## 6. ⛔ P0 反模式规避清单（违反=退回）

| # | 反模式 | 本项目具体红线 | 替代方案 |
|---|--------|----------------|----------|
| ① | **emoji 作功能图标** | 旧 `🐕💕😄` 一律禁；全量改 Lucide | `Dog`/`Heart`/`Smile` 线图标 |
| ② | **紫粉渐变主视觉** | 禁 `#7C3AED→#EC4899` 及任意 Indigo→Pink；旧 `#1A1A2E` 深底带紫调需改竹调深 | 竹绿单色 + 暖橙 `--ember` 能量；同色系深浅渐变 |
| ③ | **硬编码颜色** | 旧 `0xFF3D6B1E`/`0xFF212121`/`Colors.pink`/`Colors.orange` 散落全代码 | 全部引用 Token；Flutter 侧 `AppTheme` 常量改名对齐 Token |
| ④ | **AI 模板味文案** | 禁 "Welcome to"/"Get started"/"Seamless"；中文禁"赋能""一站式"空话 | 具体动作："3 分钟写下你的第一首歌""点竹笌进入全屏" |
| ⑤ | **千篇一律 Hero 堆砌** | 禁"大标题+副标题+居中 CTA+抽象图形"；`DESIGN_VARIANCE=5` 强制左对齐/非对称 | 角色同屏、真实界面截图、具体数据 |
| ⑥ | 侧条纹边框强调 | 禁 `border-left>1px` 彩条 | hover 时 `--border`→`--accent` |
| ⑦ | 渐变文字 | 禁 `background-clip:text` | 纯色 + 字重/字号强调 |
| ⑧ | 过度圆角 | 禁卡片 ≥24px | 上限 16px |
| ⑨ | 幽灵卡片 | 禁 `1px 边框 + blur≥16 阴影` 同元素 | 二选一 |

**现状代码整改项（合并重设计必做）**：
1. `pet_studio_page.dart`：`🐕💕😄` → Lucide；`Colors.pink` 好感度 → `--sun`；`Colors.orange` 顶栏 → `--sun`/`--ember`；`#FFF8F0` → `--surface-warm`。
2. `app_theme.dart`：`darkBg #1A1A2E` → `#0E1512` 竹调深；`coral/mint` 弃用项删除；新增 `--sun`/`--ember`/`--accent-deep`。
3. `profile_page.dart`：`#F5EFE5`/`#3D2914` 米棕 → `--surface-warm`/`--fg`（统一竹系）。
4. 全页 `Color(0xFF...)` 硬编码 → 引用 `AppTheme`/Token，杜绝散落。

---

## 7. 响应式与移动端

- 断点：phone <640 · tablet ≥768 · desktop ≥1024。移动端优先（陪伴/音乐均在手机）。
- 触摸目标 ≥44×44px；底部 TabBar（首页/发现/音乐/我的）≤5 项；`<768px` 非对称布局回退单列。
- 安全区：`env(safe-area-inset-bottom)` 34px（刘海屏）。

---

## 8. Agent 实现提示（给前端/Flutter Agent）

- **Token 落地**：`AppTheme` 常量名与本文 Token 一一对应；新增 `sun`/`ember`/`accentDeep` 字段；废弃 `coral`/`mint`/`darkBg(navy)`。
- **图标**：`pubspec.yaml` 加 `lucide_icons`，全局替换 `Icons.*` 与 emoji。
- **主题**：浅/深共用 Token 映射，深色走竹调深底；`themeProvider` 控制。
- **动效**：所有 transition ≤ `var(--motion-base)`；`reduced-motion` 兜底。
- **可访问**：对比度正文 ≥4.5:1；图标按钮带 `aria-label`/tooltip；键盘可达。
