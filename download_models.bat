@echo off
chcp 65001 >nul
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REM 竹笌 Sherpa-ONNX 模型下载脚本
REM 
REM 模型列表：
REM   ASR: Paraformer-zh（中文语音识别，~46MB）
REM   TTS: Vits 中文（语音合成，~50MB）
REM
REM 使用方法：把脚本放项目根目录，直接运行
REM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setlocal enabledelayedexpansion

REM 配置
set PROJECT_ROOT=%~dp0
set ASSETS_DIR=%PROJECT_ROOT%assets\models
set ASR_DIR=%ASSETS_DIR%\asr
set TTS_DIR=%ASSETS_DIR%\tts

echo ================================================
echo   竹笌 Sherpa-ONNX 模型下载
echo ================================================
echo.

REM 创建目录
echo [1/4] 创建模型目录...
if not exist "%ASR_DIR%" mkdir "%ASR_DIR%"
if not exist "%TTS_DIR%" mkdir "%TTS_DIR%"
echo   完成
echo.

REM ════════════════════════════════════════════════════
REM ASR 模型：Paraformer-zh
REM ════════════════════════════════════════════════════
echo [2/4] 下载 ASR 模型 (Paraformer-zh, ~46MB)...

REM 模型下载地址（GitHub releases）
set ASR_BASE=https://github.com/k2-fsa/sherpa-onnx/releases/download
set ASR_VERSION=1.13.7

REM Paraformer-zh 模型（int8 量化版，更小更快）
REM 注：如果链接失效，去 https://k2-fsa.github.io/sherpa/onnx/ 找最新链接
set ASR_MODEL_URL=%ASR_BASE%/v%ASR_VERSION%/sherpa-onnx-paraformer-zh-2024-03-09.tar.bz2

echo   下载地址: %ASR_MODEL_URL%
echo   (如果下载失败，请访问上方 GitHub 手动下载)
echo.

REM 检查 curl 是否可用
where curl >nul 2>&1
if %errorlevel%==0 (
    echo   使用 curl 下载...
    curl -L -o "%TEMP%\paraformer-zh.tar.bz2" "%ASR_MODEL_URL%" --progress-bar
    if %errorlevel%==0 (
        echo   解压到 %ASR_DIR%...
        tar -xjf "%TEMP%\paraformer-zh.tar.bz2" -C "%ASR_DIR%"
        move "%ASR_DIR%\sherpa-onnx-paraformer-zh-2024-03-09\*" "%ASR_DIR%\" >nul 2>&1
        echo   ASR 模型下载完成
    ) else (
        echo   [错误] 下载失败，请手动下载
    )
) else (
    echo   [提示] curl 未安装，请手动下载模型：
    echo   %ASR_MODEL_URL%
    echo   解压到: %ASR_DIR%
)

REM 清理
del "%TEMP%\paraformer-zh.tar.bz2" 2>nul

REM ════════════════════════════════════════════════════
REM TTS 模型：Vits 中文
REM ════════════════════════════════════════════════════
echo.
echo [3/4] 下载 TTS 模型 (Vits 中文, ~50MB)...

set TTS_BASE=https://github.com/k2-fsa/sherpa-onnx/releases/download
set TTS_VERSION=1.13.7

REM Vits 中文模型
set TTS_MODEL_URL=%TTS_BASE%/v%TTS_VERSION%/vits-zh-hf-ljspeech-onnx-audio.tar.bz2

echo   下载地址: %TTS_MODEL_URL%
echo   (如果链接失效，请访问 GitHub 手动下载)
echo.

where curl >nul 2>&1
if %errorlevel%==0 (
    echo   使用 curl 下载...
    curl -L -o "%TEMP%\vits-zh.tar.bz2" "%TTS_MODEL_URL%" --progress-bar
    if %errorlevel%==0 (
        echo   解压到 %TTS_DIR%...
        tar -xjf "%TEMP%\vits-zh.tar.bz2" -C "%TTS_DIR%"
        echo   TTS 模型下载完成
    ) else (
        echo   [错误] 下载失败，请手动下载
    )
) else (
    echo   [提示] curl 未安装，请手动下载模型：
    echo   %TTS_MODEL_URL%
    echo   解压到: %TTS_DIR%
)

del "%TEMP%\vits-zh.tar.bz2" 2>nul

REM ════════════════════════════════════════════════════
REM 完成
REM ════════════════════════════════════════════════════
echo.
echo [4/4] 检查模型文件...
echo.

set MISSING=0

if exist "%ASR_DIR%\model.onnx" (
    for %%F in ("%ASR_DIR%\model.onnx") do echo   ASR模型: %%~nxf  %%~zF bytes
) else (
    echo   [缺失] ASR model.onnx
    set MISSING=1
)

if exist "%ASR_DIR%\tokens.txt" (
    echo   ASR词表: tokens.txt
) else (
    echo   [缺失] ASR tokens.txt
    set MISSING=1
)

if exist "%TTS_DIR%\model.onnx" (
    for %%F in ("%TTS_DIR%\model.onnx") do echo   TTS模型: %%~nxf  %%~zF bytes
) else (
    echo   [缺失] TTS model.onnx
    set MISSING=1
)

echo.
if %MISSING%==0 (
    echo ================================================
    echo   模型下载完成！
    echo ================================================
    echo.
    echo   模型位置：
    echo   - ASR: %ASR_DIR%
    echo   - TTS: %TTS_DIR%
    echo.
    echo   下一步：运行 flutter pub get
    echo   然后：flutter run
) else (
    echo ================================================
    echo   部分模型缺失，请手动下载
    echo ================================================
    echo.
    echo   访问以下链接手动下载：
    echo   https://github.com/k2-fsa/sherpa-onnx/releases
)

echo.
pause
