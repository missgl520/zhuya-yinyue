# 竹笌后端 Docker 镜像
# 用法（在仓库根目录执行）：
#   docker build -f deploy/Dockerfile -t zhuyu-backend:latest .
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_INDEX_URL=https://mirrors.cloud.tencent.com/pypi/simple/ \
    PIP_TRUSTED_HOST=mirrors.cloud.tencent.com

WORKDIR /app

# 健康检查需要 curl（python 镜像已含 python，这里补 curl）
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# 先装依赖，利用镜像层缓存（腾讯云 PyPI 镜像加速）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制源码（.dockerignore 已排除 venv/.git/data/.env）
COPY . .

# 非 root 用户运行（uvicorn 绑 8000 端口，非特权端口无需 root）
RUN useradd -m -u 10001 appuser && chown -R appuser:appuser /app
# 预建数据目录（SQLite 需要父目录存在；云托管里 data/ 不进镜像）
RUN mkdir -p /app/data && chown appuser:appuser /app/data
USER appuser

EXPOSE 8000

# 容器内健康检查（不依赖 curl，用 python 自带 urllib）
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"

# UVICORN_WORKERS 可在 compose / .env 中覆盖；单 worker 足以支撑演示与中小流量
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port 8000 --workers ${UVICORN_WORKERS:-1}"]
