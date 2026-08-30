@echo off
REM =====================================================================
REM 竹笌 (zhuyapp) Android APK 一键构建脚本 (Windows cmd)
REM ---------------------------------------------------------------------
REM 用法：双击或在 cmd 中执行  scripts\build_apk.bat
REM 说明：本地已包含 key.properties + upload-keystore.jks 时可直接出 release 包。
REM       CI 请使用 build_apk.sh（GitHub Actions 运行在 Linux 上）。
REM 可选环境变量：SPLIT_PER_ABI=1 按 ABI 拆分；OBFUSCATE=1 开启混淆；
REM               MINIFY=1 开启 R8 压缩；OUTPUT_DIR 指定输出目录。
REM =====================================================================
setlocal
cd /d %~dp0\..

REM ---- JDK 探测（优先使用 Android SDK 自带 JBR）----
if not defined JAVA_HOME (
  if exist "F:\Android\SDK\jbr\bin\java.exe" set "JAVA_HOME=F:\Android\SDK\jbr"
  if exist "F:\Android\AndroidStudio\jbr\bin\java.exe" set "JAVA_HOME=F:\Android\AndroidStudio\jbr"
)
echo Using JAVA_HOME=%JAVA_HOME%

where flutter >nul 2>nul || (echo [ERR] flutter not found in PATH & exit /b 1)

REM ---- 解析版本号 (pubspec.yaml: version: 1.0.0+1) ----
set "VERNAME=1.0.0"
for /f "tokens=2 delims=: " %%v in ('findstr /r "^version:" pubspec.yaml') do set "VER=%%v"
for /f "tokens=1 delims=+" %%a in ("%VER%") do set "VERNAME=%%a"
echo Building version %VERNAME%

REM ---- 输出目录 ----
if not defined OUTPUT_DIR set "OUTPUT_DIR=%CD%\build\release"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM ---- 构建参数 ----
set "EXTRA="
if "%SPLIT_PER_ABI%"=="1" set "EXTRA=%EXTRA% --split-per-abi"
if "%OBFUSCATE%"=="1" set "EXTRA=%EXTRA% --obfuscate --split-debug-info=build/debug-info"
set "GRADLE_PROPS="
if "%MINIFY%"=="1" set "GRADLE_PROPS=-PzhuyappMinify=true"

REM ---- dart-define（密钥/后端地址注入，不写进源码/git）----
set "DART_DEFINES="
if not "%ZHUYU_API_BASE_URL%"=="" set "DART_DEFINES=%DART_DEFINES% --dart-define=ZHUYU_API_BASE_URL=%ZHUYU_API_BASE_URL%"
if not "%ZHUYU_API_KEY%"=="" set "DART_DEFINES=%DART_DEFINES% --dart-define=ZHUYU_API_KEY=%ZHUYU_API_KEY%"
if not "%MINIMAX_API_KEY%"=="" set "DART_DEFINES=%DART_DEFINES% --dart-define=MINIMAX_API_KEY=%MINIMAX_API_KEY%"

REM ---- 执行构建 ----
echo flutter pub get
call flutter pub get
echo flutter build apk --release %EXTRA% %GRADLE_PROPS% %DART_DEFINES%
call flutter build apk --release %EXTRA% %GRADLE_PROPS% %DART_DEFINES%

REM ---- 收集产物到输出目录 ----
set "SRC=build\app\outputs\flutter-apk"
if not exist "%SRC%" (
  echo [ERR] build output not found & exit /b 1
)
for %%f in ("%SRC%\app*-release.apk") do (
  copy /Y "%%f" "%OUTPUT_DIR%\%%~nxf" >nul
  echo [OK] %OUTPUT_DIR%\%%~nxf
)
REM 把通用包重命名为易识别的名字
if exist "%SRC%\app-release.apk" (
  copy /Y "%SRC%\app-release.apk" "%OUTPUT_DIR%\zhuyapp-v%VERNAME%-release.apk" >nul
  echo [OK] %OUTPUT_DIR%\zhuyapp-v%VERNAME%-release.apk
)

echo.
echo Build complete. APKs in: %OUTPUT_DIR%
echo Install: adb install -r "%OUTPUT_DIR%\zhuyapp-v%VERNAME%-release.apk"
endlocal
