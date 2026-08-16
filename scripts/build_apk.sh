#!/usr/bin/env bash
# =====================================================================
# 竹笌（zhuyapp）Android APK 一键构建脚本
# ---------------------------------------------------------------------
# 用途：本地命令行或 CI 中一键产出「可直接安装到设备的 release APK」。
#
# 用法：
#   bash scripts/build_apk.sh
#
# 可选环境变量（均为可选，缺省走默认行为）：
#   BUILD_FLAVOR      Flutter 构建风味（如 prod/dev），留空 = 默认
#   SPLIT_PER_ABI     设为 1 时按 ABI 拆分 APK（arm64-v8a / armeabi-v7a / x86_64）
#   OBFUSCATE         设为 1 时启用 Dart 混淆（同时生成 build/debug-info 符号表）
#   MINIFY            设为 1 时开启 R8 压缩/混淆（gradle -PzhuyappMinify=true）
#   STRICT_SIGNING   设为 1 时强制要求 release 签名，缺失则报错退出
#   OUTPUT_DIR        产物输出目录（默认 build/release）
#   JAVA_HOME         JDK 路径；留空则脚本自动探测可用 JDK
#
# CI 签名（不把 keystore 提交到仓库）：
#   KEYSTORE_BASE64   经 base64 编码的 keystore 文件内容（CI secret）
#   KEYSTORE_FILE     keystore 文件路径（默认 android/app/upload-keystore.jks）
#   KEYSTORE_PASSWORD / KEY_ALIAS / KEY_PASSWORD  （CI secret）
#   脚本检测到 KEYSTORE_BASE64 时会自动解码为 KEYSTORE_FILE。
# =====================================================================

set -euo pipefail

# ---------- 定位项目根目录 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> 工作目录: $PROJECT_ROOT"

# ---------- 检查 flutter ----------
if ! command -v flutter >/dev/null 2>&1; then
  echo "✗ 未找到 flutter，请先将其加入 PATH（https://flutter.dev/docs/get-started/install）" >&2
  exit 1
fi

# ---------- 自动探测 JDK（仅当 JAVA_HOME 未设置或不可用） ----------
detect_jdk() {
  local candidates=(
    "${JAVA_HOME:-}"
    "/f/Android/SDK/jbr"
    "/f/Android/AndroidStudio/jbr"
    "/c/Program Files/Android/Android Studio/jbr"
    "/c/Users/ROG/.jdks/jbr-17.0.14"
    "/c/Program Files/Java"/*
    "/usr/lib/jvm"/*
    "/opt/homebrew/opt/openjdk"*
    "/usr/local/opt/openjdk"*
  )
  for c in "${candidates[@]}"; do
    [ -z "${c:-}" ] && continue
    local java_bin="$c/bin/java"
    if [ -x "$java_bin" ] && "$java_bin" -version >/dev/null 2>&1; then
      echo "$c"
      return 0
    fi
  done
  # 退而求其次：直接用 PATH 中的 java
  if command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1; then
    command -v java | sed 's#/bin/java##'
    return 0
  fi
  return 1
}

if [ -z "${JAVA_HOME:-}" ] || ! "${JAVA_HOME}/bin/java" -version >/dev/null 2>&1; then
  DETECTED="$(detect_jdk || true)"
  if [ -n "$DETECTED" ]; then
    export JAVA_HOME="$DETECTED"
    echo "==> 使用 JDK: $JAVA_HOME"
  else
    echo "⚠️ 未探测到可用 JDK，将交由 flutter/gradle 自行查找（若失败请设置 JAVA_HOME）"
  fi
else
  echo "==> 使用 JAVA_HOME: $JAVA_HOME"
fi

# ---------- 解析版本号（来自 pubspec.yaml: version: 1.0.0+1）----------
VERSION_LINE="$(grep -m1 '^version:' pubspec.yaml || true)"
VERSION_NAME="$(echo "$VERSION_LINE" | sed -E 's/.*version:[[:space:]]*([0-9.]+)\+?[0-9]*/\1/')"
VERSION_CODE="$(echo "$VERSION_LINE" | sed -E 's/.*\+([0-9]+).*/\1/')"
VERSION_NAME="${VERSION_NAME:-1.0.0}"
VERSION_CODE="${VERSION_CODE:-1}"
echo "==> 版本: $VERSION_NAME (+$VERSION_CODE)"

# ---------- CI：从 base64 解码 keystore ----------
if [ -n "${KEYSTORE_BASE64:-}" ]; then
  : "${KEYSTORE_FILE:=$PROJECT_ROOT/android/app/upload-keystore.jks}"
  echo "==> 解码 KEYSTORE_BASE64 -> $KEYSTORE_FILE"
  mkdir -p "$(dirname "$KEYSTORE_FILE")"
  echo "$KEYSTORE_BASE64" | base64 -d > "$KEYSTORE_FILE"
  export KEYSTORE_FILE
fi

# ---------- 拼接构建参数 ----------
EXTRA_ARGS=()
[ -n "${BUILD_FLAVOR:-}" ] && EXTRA_ARGS+=(--flavor "$BUILD_FLAVOR")
[ "${SPLIT_PER_ABI:-}" = "1" ] && EXTRA_ARGS+=(--split-per-abi)
if [ "${OBFUSCATE:-}" = "1" ]; then
  EXTRA_ARGS+=(--obfuscate --split-debug-info=build/debug-info)
fi
GRADLE_PROPS=()
[ "${MINIFY:-}" = "1" ] && GRADLE_PROPS+=(-PzhuyappMinify=true)
[ "${STRICT_SIGNING:-}" = "1" ] && GRADLE_PROPS+=(-PzhuyappStrictSigning=true)

# ---------- dart-define（密钥/后端地址注入，不写进源码/git）----------
# 这些变量由本地/CI 环境提供，缺省则不打入（App 走默认值）。
DART_DEFINES=()
[ -n "${ZHUYU_API_BASE_URL:-}" ] && DART_DEFINES+=(--dart-define=ZHUYU_API_BASE_URL="$ZHUYU_API_BASE_URL")
[ -n "${ZHUYU_API_KEY:-}" ]      && DART_DEFINES+=(--dart-define=ZHUYU_API_KEY="$ZHUYU_API_KEY")
[ -n "${MINIMAX_API_KEY:-}" ]    && DART_DEFINES+=(--dart-define=MINIMAX_API_KEY="$MINIMAX_API_KEY")

OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/build/release}"
mkdir -p "$OUTPUT_DIR"

# ---------- 执行构建 ----------
echo "==> flutter pub get"
flutter pub get

echo "==> flutter build apk --release ${EXTRA_ARGS[*]:-} ${GRADLE_PROPS[*]:-} ${DART_DEFINES[*]:-}"
flutter build apk --release "${EXTRA_ARGS[@]}" "${GRADLE_PROPS[@]}" "${DART_DEFINES[@]}"

# ---------- 收集产物到输出目录 ----------
SRC_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"
shopt -s nullglob
count=0
for src in "$SRC_DIR"/app*-release.apk; do
  base="$(basename "$src")"
  # base 形如 app-release.apk / app-arm64-v8a-release.apk / app-prod-release.apk
  suffix="${base#app}"                 # -release.apk / -arm64-v8a-release.apk / -prod-release.apk
  suffix="${suffix%-release.apk}"      # '' / -arm64-v8a / -prod / -prod-arm64-v8a
  dest="$OUTPUT_DIR/zhuyapp-v$VERSION_NAME$suffix-release.apk"
  cp -f "$src" "$dest"
  echo "✓ 产物: $dest ($(du -h "$dest" | cut -f1))"
  count=$((count + 1))
done
shopt -u nullglob

if [ "$count" -eq 0 ]; then
  echo "✗ 未在 $SRC_DIR 找到构建产物，构建可能失败" >&2
  exit 1
fi

echo ""
echo "🎉 构建完成！release APK 已生成："
ls -1 "$OUTPUT_DIR"/*.apk
echo ""
echo "安装到设备：adb install -r \"$OUTPUT_DIR/zhuyapp-v$VERSION_NAME-release.apk\""
