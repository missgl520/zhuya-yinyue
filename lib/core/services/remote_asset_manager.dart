// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 远程资产管家（Remote Asset Manager）
//
// 背景：3D 角色 GLB（char_girl/boy 等）共约 132MB，已全部从 git 仓库移除，
//   改为发布到 GitHub Release（vrm-assets），App 运行时按本 manifest 按需下载
//   到应用文档目录缓存，避免仓库持续膨胀。
//
// 职责：
//   - init()：读取 assets/remote_assets.json（随 app 打包的小 JSON），建立
//     key → 文件名 / 远程 baseUrl 映射。
//   - resolveLocalPath(key)：返回本地可访问的 file:// 路径；若文档目录缓存不存在
//     或为空，则从远程下载到缓存再返回。下载失败抛异常，由调用方决定回退。
//
// 缓存语义：每个 GLB 只下载一次，之后始终命中本地缓存（file://），不重复拉取。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RemoteAssetManager {
  RemoteAssetManager._();

  static final RemoteAssetManager instance = RemoteAssetManager._();

  String? _baseUrl;
  final Map<String, String> _glbs = {};

  /// 读取 manifest（assets/remote_assets.json，随 app 打包）。
  /// 必须在 runApp 前调用一次（见 lib/main.dart 的 main()）。
  Future<void> init() async {
    final raw = await rootBundle.loadString('assets/remote_assets.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _baseUrl = map['baseUrl'] as String;
    final glbs = map['glbs'] as Map<String, dynamic>;
    for (final e in glbs.entries) {
      _glbs[e.key] = e.value as String;
    }
  }

  /// 返回本地可访问的 `file://` 路径；不存在则从远程下载到文档目录缓存。
  /// 失败抛异常，由调用方决定回退（如回退到占位模型）。
  Future<String> resolveLocalPath(String key) async {
    final fileName = _glbs[key];
    if (fileName == null) throw ArgumentError('unknown glb key: $key');

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, fileName));

    // 命中本地缓存：直接复用，不重复下载。
    if (await file.exists() && await file.length() > 0) {
      return 'file://${file.path}';
    }

    // 缓存缺失：从 release 下载（GitHub 会对 download URL 302 重定向到
    // objects.githubusercontent.com，http 包默认跟随重定向）。
    final resp = await http.get(Uri.parse('$_baseUrl/$fileName'));
    if (resp.statusCode != 200) {
      throw Exception('download $fileName failed: ${resp.statusCode}');
    }
    await file.writeAsBytes(resp.bodyBytes);
    return 'file://${file.path}';
  }
}
