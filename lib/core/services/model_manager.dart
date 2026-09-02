// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Sherpa-ONNX 模型管理器
//
// 支持两种模式：
// 1. APK 内置：模型打包在 assets/models/，首次启动复制到 AppDocuments
// 2. 增量更新：检测 CDN 是否有新版本，有则下载替换
//
// 模型目录结构：
//   sherpa_models/
//   ├── asr/
//   │   ├── model.onnx       # Paraformer-zh ASR 模型
//   │   └── tokens.txt       # 词表
//   ├── tts/
//   │   ├── model.onnx       # Vits 中文 TTS 模型
//   │   ├── tokens.txt
//   │   └── lexicon.txt      # 音素词典（可选）
//   └── version.json         # 版本信息（用于增量更新）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 模型版本信息
class ModelVersion {
  final String version;     // 语义化版本 "1.0.0"
  final String modelHash;   // SHA256 校验（确保完整）
  final int sizeBytes;      // 文件大小
  final String? cdnUrl;     // CDN 下载地址（增量更新用）

  const ModelVersion({
    required this.version,
    required this.modelHash,
    required this.sizeBytes,
    this.cdnUrl,
  });

  factory ModelVersion.fromJson(Map<String, dynamic> json) {
    return ModelVersion(
      version: json['version'] ?? '1.0.0',
      modelHash: json['modelHash'] ?? '',
      sizeBytes: json['sizeBytes'] ?? 0,
      cdnUrl: json['cdnUrl'],
    );
  }
  Map<String, dynamic> toJson() => {
    'version': version,
    'modelHash': modelHash,
    'sizeBytes': sizeBytes,
    'cdnUrl': cdnUrl,
  };
}

/// 单个模型状态
class ModelState {
  final String name;
  final String localPath;
  final bool exists;
  final bool isBuiltin;      // APK 内置
  final bool needsUpdate;    // CDN 有更新
  final String? cdnUrl;      // 更新地址
  final String localVersion;
  final String? remoteVersion;

  const ModelState({
    required this.name,
    required this.localPath,
    this.exists = false,
    this.isBuiltin = false,
    this.needsUpdate = false,
    this.cdnUrl,
    this.localVersion = '0.0.0',
    this.remoteVersion,
  });
}

/// 模型管理器
class ModelManager {
  static final ModelManager _instance = ModelManager._();
  factory ModelManager() => _instance;
  ModelManager._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  /// 内置模型版本（打包在 APK 里的版本）
  /// 格式：模型名 → ModelVersion
  static const Map<String, ModelVersion> _builtinVersions = {
    'asr-paraformer-zh': ModelVersion(
      version: '1.0.0',
      modelHash: '',
      sizeBytes: 0,
    ),
    'tts-vits-zh': ModelVersion(
      version: '1.0.0',
      modelHash: '',
      sizeBytes: 0,
    ),
  };

  /// CDN 版本检查接口（可替换为实际 CDN）
  /// 返回 JSON: { "models": { "asr-paraformer-zh": ModelVersion, ... } }
  static const String _versionCheckUrl =
      'https://github.com/your-org/sherpa-models/releases/latest/download/version.json';

  // ════════════════════════════════════════════════════════
  // 核心方法
  // ════════════════════════════════════════════════════════

  /// 获取模型根目录
  Future<String> get modelsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'sherpa_models');
  }

  /// ASR 模型路径
  Future<String> get asrModelPath async =>
      p.join(await modelsDir, 'asr', 'model.onnx');

  Future<String> get asrTokensPath async =>
      p.join(await modelsDir, 'asr', 'tokens.txt');

  /// TTS 模型路径
  Future<String> get ttsModelPath async =>
      p.join(await modelsDir, 'tts', 'model.onnx');

  Future<String> get ttsTokensPath async =>
      p.join(await modelsDir, 'tts', 'tokens.txt');

  Future<String> get ttsLexiconPath async =>
      p.join(await modelsDir, 'tts', 'lexicon.txt');

  // ════════════════════════════════════════════════════════
  // 模型初始化（首次启动调用）
  // ════════════════════════════════════════════════════════

  /// 初始化所有模型
  ///
  /// 流程：
  /// 1. 检查本地模型是否存在
  /// 2. 如不存在，从 assets 复制到 AppDocuments
  /// 3. 检查 CDN 是否有新版本
  /// 4. 有则后台下载更新
  ///
  /// [onProgress] 进度回调（model, progress, status）
  Future<void> initializeModels({
    void Function(String model, double progress, String status)? onProgress,
  }) async {
    final dir = await modelsDir;
    await Directory(dir).create(recursive: true);

    // ── ASR 模型 ──
    await _ensureModel(
      name: 'asr-paraformer-zh',
      assetDir: 'assets/models/asr',
      localDir: p.join(dir, 'asr'),
      files: const ['model.onnx', 'tokens.txt'],
      onProgress: onProgress,
    );

    // ── TTS 模型 ──
    await _ensureModel(
      name: 'tts-vits-zh',
      assetDir: 'assets/models/tts',
      localDir: p.join(dir, 'tts'),
      files: const ['model.onnx', 'tokens.txt', 'lexicon.txt'],
      onProgress: onProgress,
    );

    // ── 版本信息写入 ──
    await _writeVersionFile();

    // ── 后台检查增量更新 ──
    _checkForUpdatesInBackground();
  }

  /// 确保模型存在（优先本地 → assets → CDN）
  Future<void> _ensureModel({
    required String name,
    required String assetDir,
    required String localDir,
    required List<String> files,
    void Function(String model, double progress, String status)? onProgress,
  }) async {
    await Directory(localDir).create(recursive: true);

    for (var i = 0; i < files.length; i++) {
      final fileName = files[i];
      final localPath = p.join(localDir, fileName);
      final localFile = File(localPath);

      if (await localFile.exists()) {
        onProgress?.call(name, (i + 1) / files.length, '已有本地模型');
        continue; // 本地已有，跳过
      }

      // ── 从 assets 复制 ──
      onProgress?.call(name, i / files.length, '复制内置模型…');
      await _copyFromAssets(assetDir, fileName, localPath);
      onProgress?.call(name, (i + 0.5) / files.length, '已复制');
    }
  }

  /// 从 APK assets 复制文件到本地
  Future<void> _copyFromAssets(String assetDir, String fileName, String localPath) async {
    try {
      final assetPath = '$assetDir/$fileName';
      final assetData = await rootBundle.load(assetPath);
      final localFile = File(localPath);
      await localFile.writeAsBytes(
        assetData.buffer.asUint8List(assetData.offsetInBytes, assetData.lengthInBytes),
      );
    } catch (e) {
      // assets 中没有该文件（还没下载模型），忽略
    }
  }

  /// 写入版本文件
  Future<void> _writeVersionFile() async {
    final dir = await modelsDir;
    final versionFile = File(p.join(dir, 'version.json'));
    final versions = <String, dynamic>{};

    for (final entry in _builtinVersions.entries) {
      versions[entry.key] = entry.value.toJson();
    }

    await versionFile.writeAsString(jsonEncode({
      'bundled': versions,
      'updated': {},
      'lastCheck': DateTime.now().toIso8601String(),
    }));
  }

  // ════════════════════════════════════════════════════════
  // 增量更新（后台检查 CDN）
  // ════════════════════════════════════════════════════════

  /// 后台检查更新（有新版本则静默下载）
  Future<void> _checkForUpdatesInBackground() async {
    try {
      onProgress?.call('check', 0, '检查更新…');
      // TODO: 调用 CDN version.json 接口，对比版本
      // 如有新版本，启动下载
    } catch (_) {}
  }

  /// 下载并替换模型（有更新时调用）
  Future<bool> downloadUpdate({
    required String modelName,
    required String cdnUrl,
    required String localPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // 下载到临时文件
      final tempPath = '$localPath.tmp.downloading';
      await _dio.download(
        cdnUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );

      // SHA256 校验
      // final hash = await _sha256(File(tempPath));
      // if (hash != expectedHash) throw Exception('文件校验失败');

      // 替换旧文件
      final oldFile = File(localPath);
      if (await oldFile.exists()) await oldFile.delete();
      await File(tempPath).rename(localPath);

      return true;
    } catch (e) {
      return false;
    }
  }

  // ════════════════════════════════════════════════════════
  // 状态查询
  // ════════════════════════════════════════════════════════

  /// 获取所有模型状态
  Future<Map<String, ModelState>> getModelsStatus() async {
    final dir = await modelsDir;
    final versionFile = File(p.join(dir, 'version.json'));

    Map<String, dynamic> localVersions = {};
    if (await versionFile.exists()) {
      localVersions = jsonDecode(await versionFile.readAsString()) as Map;
    }

    final status = <String, ModelState>{};

    for (final entry in _builtinVersions.entries) {
      final name = entry.key;
      final builtin = entry.value;
      final localVer = (localVersions['updated'] as Map?)?[name] ?? (localVersions['bundled'] as Map?)?[name];
      final versionData = localVer is Map ? ModelVersion.fromJson(localVer) : builtin;

      final modelFile = File(p.join(dir, name.startsWith('asr') ? 'asr' : 'tts', 'model.onnx'));
      final exists = await modelFile.exists();

      status[name] = ModelState(
        name: name,
        localPath: modelFile.path,
        exists: exists,
        isBuiltin: true,
        localVersion: versionData.version,
      );
    }

    return status;
  }

  /// 获取模型总大小（MB）
  Future<int> getTotalSizeMB() async {
    try {
      final dir = Directory(await modelsDir);
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final e in dir.list(recursive: true)) {
        if (e is File) total += await e.length();
      }
      return total ~/ 1024 ~/ 1024;
    } catch (_) {
      return 0;
    }
  }

  /// 删除所有模型（恢复出厂）
  Future<void> clearAllModels() async {
    final dir = await modelsDir;
    await Directory(dir).delete(recursive: true);
  }

  /// 检查模型是否就绪
  Future<bool> isReady() async {
    final asr = File(await asrModelPath);
    final tts = File(await ttsModelPath);
    return await asr.exists() && await tts.exists();
  }
}

// 进度回调（供外部使用）
void Function(String model, double progress, String status)? onProgress;
