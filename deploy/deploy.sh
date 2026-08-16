#!/usr/bin/env bash
# 竹笌后端 · 腾讯云 CVM 一键部署脚本（Ubuntu 22.04 / 24.04）
#
# 前置：
#   1) 代码已放到服务器：/opt/zhuyu-backend（含 deploy/ 子目录）
#      本地同步示例（排除 venv/.git/data/.env）：
#        rsync -avz --exclude venv --exclude .git --exclude data --exclude .env \
#              ./ 用户@服务器IP:/opt/zhuyu-backend/
#   2) 已生成生产 .env：
#        cp deploy/.env.production.example /opt/zhuyu-backend/.env
#        并填写 ZHUYU_API_KEY / ZHUYU_ENC_KEY / OPERATOR_NAME / 邮箱 等
#   3) 以 root 或有 sudo 的账号执行：sudo bash /opt/zhuyu-backend/deploy/deploy.sh
set -euo pipefail

APP_DIR=/opt/zhuyu-backend
DEPLOY_DIR="$APP_DIR/deploy"

echo "==> [1/5] 安装 Docker（若未安装）"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  # 让当前用户免 sudo 用 docker（重新登录后生效）
  usermod -aG docker "${SUDO_USER:-$USER}" || true
  echo "    已安装 Docker，请重新登录使 docker 组生效（或后续用 sudo）。"
fi

echo "==> [2/5] 校验 .env"
if [ ! -f "$APP_DIR/.env" ]; then
  echo "错误：缺少 $APP_DIR/.env，请先复制 deploy/.env.production.example 并填写。" >&2
  exit 1
fi
if grep -q "__CHANGE_ME_TO_STRONG_RANDOM__" "$APP_DIR/.env"; then
  echo "错误：.env 中的 ZHUYU_API_KEY 仍是占位值，请改成强随机值。" >&2
  exit 1
fi

echo "==> [3/5] 构建并启动服务（backend + nginx）"
cd "$DEPLOY_DIR"
docker compose up -d --build

echo "==> [4/5] 等待健康检查"
sleep 8
docker compose ps
if curl -fsS "http://localhost/health" >/dev/null 2>&1; then
  echo "    健康检查通过：nginx -> backend 链路正常"
else
  echo "    警告：健康检查未通过，请查看：docker compose logs backend"
fi

echo "==> [5/5] 开放防火墙（若启用 ufw）"
ufw allow 22/tcp 2>/dev/null || true
ufw allow 80/tcp 2>/dev/null || true
ufw allow 443/tcp 2>/dev/null || true

echo ""
echo "完成。下一步："
echo "  1) 在腾讯云控制台【安全组】放行 80/443 入站。"
echo "  2) 域名 DNS 解析 A 记录指向本机公网 IP。"
echo "  3) 申请 HTTPS 证书（见 deploy/README.deploy.md 的 certbot 步骤）。"
echo "  4) 前端打包注入：--dart-define=ZHUYU_API_BASE_URL=https://你的域名 --dart-define=ZHUYU_API_KEY=<与 .env 一致>"
