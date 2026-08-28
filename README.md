# 竹笌 × 音乐狗子（zhuya-yinyue）

竹笌（AI 语音陪聊 App）与音乐狗子（AI 音乐创作伴侣）合并重设计后的**汇总仓**。
为清晰区分前后端，本仓库用**两个分支**分别承载完整工程树（非 monorepo 子目录）：

| 分支 | 内容 | 技术栈 |
|---|---|---|
| `qianduan`（默认） | 前端 Flutter App（竹笌主基底 + 音乐狗子模块） | Flutter 3.47 · Riverpod · GoRouter · Lucide 风格图标门面 |
| `houduan` | 后端 FastAPI 服务（对话 / 记忆 / 情绪 / 音乐生成 / 宠物状态） | Python 3.13 · FastAPI · SQLAlchemy · SQLite/MySQL |

> ⚠️ 两个分支是**互相独立的完整工程树**。切换分支 = 切换整个工程，不会在同一目录同时出现前后端。

## 获取代码

```bash
# 只要前端
git clone -b qianduan https://github.com/missgl520/zhuya-yinyue.git zhuyu-frontend

# 只要后端
git clone -b houduan https://github.com/missgl520/zhuya-yinyue.git zhuyu-backend

# 或单仓全拿，再切分支
git clone https://github.com/missgl520/zhuya-yinyue.git
cd zhuya-yinyue && git checkout houduan
```

## 分支用途

### `qianduan` — 前端
- 竹笋形象 3D 角色（model_viewer_plus 渲染）+ 音乐狗子 2D 模块（/pet 页）。
- 图标统一走 `lib/widgets/app_icon.dart` 门面，禁止 emoji / 直接 `Icons.*` 作功能图标。
- 设计令牌见 `lib/core/theme/app_theme.dart`（竹绿主色 + 暖金/暖珊瑚点缀）。

### `houduan` — 后端
- 路由按能力拆分：`chat / memory / emotion / tts / pet / lyrics / music / songs / affinity / legal / livekit / user`。
- **音乐生成**：`routers/music.py` + `ace_music.py` 接入真实 ACE Music
  （`POST https://api.acemusic.ai/v1/chat/completions`，Bearer 鉴权）。
  - 密钥仅从 `.env` 的 `ACE_MUSIC_API_KEY` 读取；**留空则自动降级 Mock 占位**，流程不断。
  - 旧硬编码密钥已废弃，切勿写回代码，需去服务商轮换后填入 `.env`。
- 持久化：`pet_state_store` / `lyrics_store` / `music_store`（统一库，按 user_id 隔离）。
- 接口鉴权：HMAC-SHA256 签名（开发模式 `ZHUYU_API_KEY=zhuyu-dev-key-change-me`）。

## 本地运行

后端：复制 `.env.example` 为 `.env` 按需填写，依赖装好后 `uvicorn main:app --reload`。
前端：`flutter pub get` 后 `flutter run`（Android 连后端用 `http://10.0.2.2:8000`）。
