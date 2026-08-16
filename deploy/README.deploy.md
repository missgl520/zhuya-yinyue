# 竹笌后端 · 部署指南（腾讯云）

竹笌后端是标准 FastAPI 服务，推荐用 **Docker + Nginx** 部署到腾讯云 CVM。
本文覆盖三种形态，任选其一。所有部署文件在 `deploy/` 目录，与具体服务器无关。

---

## 架构总览

```
公网用户 / 竹笌 App
        │  HTTPS :443
        ▼
   [Nginx 容器]  (80 仅做 ACME 挑战 + 301 跳转 HTTPS)
        │  http://backend:8000  (仅 zhuyu-net 内网)
        ▼
   [Backend 容器]  uvicorn main:app :8000
        │
        ▼
   SQLite (volume: ../data)   或   腾讯云 TencentDB for MySQL (DATABASE_URL)
```

- 公网只暴露 80/443；后端 8000 不暴露在宿主机。
- 用户数据持久化在宿主机的 `../data`，镜像重建不丢。
- 环境变量来自仓库根目录 `.env`（模板见 `.env.production.example`）。

---

## 方式一：腾讯云 CVM + Docker（推荐）

### 1. 准备云服务器
- 腾讯云控制台购买 **CVM**（建议 2 核 4G 起；系统选 **Ubuntu 22.04/24.04 LTS**）。
- 【安全组】入站放行：`22/tcp`（SSH）、`80/tcp`、`443/tcp`。
- 记录公网 IP。

### 2. 上传代码到服务器
本地（开发机）排除无关目录后同步：

```bash
rsync -avz --exclude venv --exclude .git --exclude data --exclude .env \
      ./ 你的用户名@服务器IP:/opt/zhuyu-backend/
```

> 也可用 `git clone`（需服务器有仓库读权限）。重点是服务器上最终有 `/opt/zhuyu-backend`，且含 `deploy/` 子目录。

### 3. 准备生产环境变量
```bash
ssh 你的用户名@服务器IP
cd /opt/zhuyu-backend
cp deploy/.env.production.example .env
# 编辑 .env，至少填写：ZHUYU_API_KEY / ZHUYU_ENC_KEY / OPERATOR_NAME / 邮箱
#   ZHUYU_API_KEY:   openssl rand -hex 32
#   ZHUYU_ENC_KEY:   python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### 4. 一键部署
```bash
sudo bash /opt/zhuyu-backend/deploy/deploy.sh
```
脚本会安装 Docker、构建镜像、启动 `backend` + `nginx` 两个容器、开放防火墙。
验证：`curl http://localhost/health` 应返回 `{"status":"ok",...}`。

### 5. 申请 HTTPS 证书（Let's Encrypt）
域名 DNS 的 A 记录先指向服务器公网 IP，然后：
```bash
sudo apt-get update && sudo apt-get install -y certbot
sudo certbot certonly --webroot \
  -w /opt/zhuyu-backend/deploy/nginx/www \
  -d 你的域名
# 把证书复制/软链到 nginx 挂载目录：
sudo cp /etc/letsencrypt/live/你的域名/fullchain.pem /opt/zhuyu-backend/deploy/nginx/certs/
sudo cp /etc/letsencrypt/live/你的域名/privkey.pem  /opt/zhuyu-backend/deploy/nginx/certs/
# 编辑 deploy/nginx/conf.d/zhuyu.conf，把两处 api.example.com 改成你的域名
sudo docker compose -f /opt/zhuyu-backend/deploy/docker-compose.yml restart nginx
```
> 证书 90 天过期，`certbot renew` 自动续期；续期后重新复制证书并 `restart nginx` 即可（可写进 crontab）。

### 6. 前端联动配置（关键）
后端强制接口签名，**前端必须用相同 key**，否则全部 401。生产构建：
```bash
flutter build apk --dart-define=ZHUYU_API_BASE_URL=https://你的域名 \
                  --dart-define=ZHUYU_API_KEY=<与 .env 的 ZHUYU_API_KEY 完全一致>
```
- `ZHUYU_API_BASE_URL`：竹笌 App 连接的后端地址（HTTPS 域名）。
- `ZHUYU_API_KEY`：见 `lib/core/auth/client_auth.dart`，必须与后端一致。
- 也可在 App 内「设置 → 后端地址」手动填写（仅调试用）。

### 7. 升级 / 回滚
```bash
# 拉最新代码到服务器后重新构建
cd /opt/zhuyu-backend && docker compose -f deploy/docker-compose.yml up -d --build
# 看日志
docker compose -f deploy/docker-compose.yml logs -f backend
# 备份数据
tar czf zhuyu-data-$(date +%F).tar.gz -C /opt/zhuyu-backend data
```

---

## 方式二：腾讯云 CloudBase 云托管（容器，免管服务器）

适合不想运维 CVM 的场景。用同一份 `deploy/Dockerfile` 构建镜像：

1. 在 CloudBase 控制台创建「云托管」服务，关联代码仓库或用**镜像仓库**（TCR）。
2. 构建配置：Dockerfile 路径 `deploy/Dockerfile`，构建上下文为仓库根。
3. 环境变量：在云托管控制台填入 `.env.production.example` 中的必填项。
4. 云托管默认提供 HTTPS 域名，直接把该域名填进前端 `ZHUYU_API_BASE_URL`。
5. 注意：CloudBase 云托管是无状态容器，**数据卷不持久**——请使用「方式一」里的腾讯云 TencentDB for MySQL（`DATABASE_URL`），否则重启丢数据。

### 已上线实例（实测可用）

- **环境**：`zhuya-d2g09hrf1dff724ae`（上海 ap-shanghai，试用套餐）
- **服务**：`zhuyu-backend`（容器型，PUBLIC 公网访问）
- **访问域名**（HTTPS）：
  - `https://zhuyu-backend-297911-11-1432495298.sh.run.tcloudbase.com/`
  - `https://zhuyu-backend-zhuya-d2g09hrf1dff724ae-1432495298.ap-shanghai.run.wxcloudrun.com/`
- **当前配置**：`MinNum=1`（常驻，便于联调）；mock 模式（未配 `AGNES_API_KEY`）；SQLite 在容器临时层（重建/重启丢数据，符合"暂不持久化"目标）。
- **已验证**：`/health`→200；`/chat/v2` 签名请求→200 且 SSE 正常推送 `text/emotion` 事件。
- **联调用 API Key**（已写入服务 EnvParams，前端须用同一值）：
  `1668ce9bea0a9a8bfe32291788941e8359220f16f3dfb96b872f0c686b4eec44`
- **重部署**：源码在仓库根，直接 `manageCloudRun deploy` 传 `targetPath=<仓库根>`、`Dockerfile=deploy/Dockerfile` 即可（根 `.dockerignore` 已排除 venv/data/.env）。

> 排坑记录：容器启动期 `db.init()` 需 SQLite 父目录存在，而 `data/` 被 `.dockerignore` 排除导致镜像内无此目录、启动即崩、健康检查失败、网关报 `SERVICE_VERSION_NOT_FOUND`。已在 `db.py` 的 `init()` 开头 `os.makedirs(DATA_DIR, exist_ok=True)` 修复，并在 Dockerfile 预建 `/app/data`。

---

## 方式三：纯 systemd + venv（轻量备选）

不想要 Docker 时，直接在 CVM 上跑：

```bash
sudo apt-get install -y python3-venv
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
# 复制 .env 并填写（同方式一步骤 3）
# 用 gunicorn + uvicorn worker（或用 uvicorn 单进程演示）
pip install gunicorn
gunicorn -k uvicorn.workers.UvicornWorker -w 2 -b 0.0.0.0:8000 main:app
```
再配 `systemd` 单元 + nginx 反代（nginx 配置复用 `deploy/nginx/conf.d/zhuyu.conf`）。

---

## 生产必填清单

- [ ] `ZHUYU_API_KEY`：强随机，且与前端 `--dart-define=ZHUYU_API_KEY` 一致
- [ ] `ZHUYU_ENC_KEY`：Fernet key，设置后勿更改
- [ ] `OPERATOR_NAME` / `PRIVACY_CONTACT_EMAIL` / `SERVICE_CONTACT_EMAIL`
- [ ] `ALLOWED_ORIGINS`：填前端实际来源（如用 Web/调试）
- [ ] 安全组放行 80/443；域名解析到位
- [ ] HTTPS 证书已申请并挂载
- [ ] 前端打包注入 `ZHUYU_API_BASE_URL` + `ZHUYU_API_KEY`
- [ ] （可选）`AGNES_API_KEY` 接真实对话；`LIVEKIT_*` 接真实语音房
- [ ] （高并发）`DATABASE_URL` 指向 TencentDB for MySQL

## 故障排查

| 现象 | 可能原因 | 处理 |
|---|---|---|
| App 全部 401 | 前后端 `ZHUYU_API_KEY` 不一致 | 确认两者完全相同后重新构建前端 |
| 进聊天页红屏/无回复 | 后端未起或签名失败 | `docker compose logs backend` 看报错 |
| 流式回复卡住 | nginx 缓冲了 SSE | 确认 `proxy_buffering off` 已配置并 `restart nginx` |
| 数据重启后丢失 | 用了容器但没挂 volume / 用了无状态云托管 | 挂 `../data` 或切 TencentDB |
| HTTPS 不生效 | 证书路径/域名不符 | 检查 `zhuyu.conf` 域名与 `certs/` 文件 |
