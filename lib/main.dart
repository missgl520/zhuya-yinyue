// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌 App - 主入口
// 负责：Hive 初始化 → 全局 ProviderScope → MaterialApp.router
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'dart:typed_data'; // Uint8List（HiveAesCipher 密钥类型）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 已 re-export HiveAesCipher / Box
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/sync/sync_engine.dart';
import 'core/security/local_encryption.dart';
import 'presentation/providers/app_providers.dart';

/// 打开受信任 Hive box，失败时回退到无加密（兼容老设备/旧数据）。
Future<Box> _openBox(String name, {Uint8List? encryptionKey}) async {
  if (encryptionKey != null) {
    try {
      // 优先以加密方式打开（生产推荐）
      return await Hive.openBox(
        name,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (_) {
      // 加密失败（可能是旧 box 或 key 不匹配），降级到无加密
      return await Hive.openBox(name);
    }
  }
  return await Hive.openBox(name);
}

void main() async {
  // Flutter 异步初始化必须调用
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive 本地存储（类 IndexedDB，用于持久化）
  await Hive.initFlutter();

  // 获取 AES 加密密钥（存于 flutter_secure_storage，设备级安全）；
  // 密钥不存在时自动生成并持久化。Hive 加密保护 settings/messages/memory。
  final hiveKey = await LocalEncryption.getHiveKey();

  // 打开三个 box，均启用 AES-256 加密（敏感数据：API Key / 聊天记录 / 记忆）
  await Future.wait([
    _openBox('settings', encryptionKey: hiveKey),
    _openBox('messages', encryptionKey: hiveKey),
    _openBox('memory', encryptionKey: hiveKey),
  ]);

  // 初始化后端配置（必须先于 App 运行，因为它决定 Dio baseUrl）
  await BackendConfig.instance.init();

  // 启动离线优先同步引擎（监听联网恢复，自动补发发件箱消息）
  await SyncEngine.instance.start();

  // 首次启动：若用户从未改过后端地址，将默认值落库（默认 = 模拟器地址，
  // 生产构建通过 --dart-define=ZHUYU_API_BASE_URL 注入域名后此处即域名）。
  // 用户在设置页手动改过的不覆盖。
  if (Hive.box('settings').get('backendUrl') == null) {
    Hive.box('settings').put('backendUrl', BackendConfig.instance.baseUrl);
  }

  // Riverpod 跨组件状态管理，child 能通过 ref.watch/read 获取 providers
  runApp(const ProviderScope(child: ZhuyApp()));
}

/// 根 Widget：
/// - MaterialApp.router：用 go_router 做声明式路由
/// - 根据 themeProvider 切换亮/暗主题
/// 竹笌 App 根组件，负责主题与全局状态挂载。
class ZhuyApp extends ConsumerWidget {
  const ZhuyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider); // GoRouter 实例
    final isDarkMode = ref.watch(themeProvider); // true = 暗色主题

    return MaterialApp.router(
      title: '竹笌',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light, // 亮色主题配色
      darkTheme: AppTheme.dark, // 暗色主题配色
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router, // 注入路由配置
    );
  }
}
