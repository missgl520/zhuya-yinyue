// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 后端配置（Backend Config）
//
// 位于：core/config.dart
// 职责：集中管理所有后端相关配置
//
// 配置来源（优先级从高到低）：
//   1. 运行时修改（代码中调用 setBaseUrl / setWakeWord）
//   2. 本地持久化（Hive storage）
//   3. 硬编码默认值（代码里的 default）
//
// 为什么用单例（Singleton）？
//   配置是全局的，不需要每次 new 一个实例。
//   整个 App 共享同一份后端地址、唤醒词等配置。
//
// 持久化方案：Hive（轻量本地数据库，比 SharedPreferences 更快）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:hive_flutter/hive_flutter.dart';

class BackendConfig {
  BackendConfig._();

  /// 单例访问器
  /// 使用方式：BackendConfig.instance.baseUrl
  static final BackendConfig instance = BackendConfig._();

  // ── 硬编码默认值（最低优先级）───────────────────────
  // 这些值会被 Hive 里的值覆盖

  /// 后端服务地址
  /// 开发环境默认：安卓模拟器地址 http://10.0.2.2:8000
  /// 生产环境：打包时用 --dart-define=ZHUYU_API_BASE_URL=https://你的域名:8000 注入
  ///   （也可直接用 http://域名:8000，但公网强烈建议走 HTTPS）
  static const String _defaultBaseUrl = String.fromEnvironment(
    'ZHUYU_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// 默认唤醒词（用户还没设置过时的兜底值）
  static const String _defaultWakeWord = '竹笌竹笌';

  /// 情感语音角色
  /// 可选：gentle（温柔）/ playful（俏皮）/ wise（智慧）
  static const String _defaultPersona = 'gentle';

  // ── 运行时配置（代码可以动态修改）───────────────────

  String _baseUrl = _defaultBaseUrl;
  String _wakeWord = _defaultWakeWord;
  String _persona = _defaultPersona;

  /// 当前后端地址
  String get baseUrl => _baseUrl;

  /// 当前唤醒词
  String get wakeWord => _wakeWord;

  /// 当前情感角色
  String get persona => _persona;

  // ── 初始化（App 启动时调用一次）─────────────────────

  /// 从 Hive 恢复持久化配置
  ///
  /// 在 main() 里调用：
  /// ```dart
  /// await BackendConfig.instance.init();
  /// ```
  Future<void> init() async {
    // 打开名为 'settings' 的 Hive 盒子
    final box = await Hive.openBox('settings');

    // 恢复各配置项。优先级规则（修复「切换后端域名后出错了」的坑）：
    //   - 若用户曾在设置页显式改过（Hive 中确实存过该 key），则用 Hive 值；
    //   - 否则一律用编译期 dart-define 注入的值（含云端生产 URL）。
    // 这样打包时注入的 ZHUYU_API_BASE_URL 在首次安装上一定生效，不会被空 Hive 覆盖。
    _baseUrl = box.containsKey('backendUrl')
        ? box.get('backendUrl')
        : _defaultBaseUrl;
    _wakeWord = box.containsKey('wakeWord')
        ? box.get('wakeWord')
        : _defaultWakeWord;
    _persona = box.containsKey('persona')
        ? box.get('persona')
        : _defaultPersona;
  }

  // ── 运行时修改（会自动写入 Hive）────────────────────

  /// 修后端地址
  /// [url] 必须是有效的 http/https URL
  void setBaseUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw FormatException('后端地址必须是 http/https 开头');
    }
    _baseUrl = url;
    _save('backendUrl', url);
  }

  /// 修改唤醒词
  /// [word] 2-20字，中英文均可
  void setWakeWord(String word) {
    _wakeWord = word.trim();
    _save('wakeWord', _wakeWord);
  }

  /// 修改情感角色
  void setPersona(String persona) {
    if (!['gentle', 'playful', 'wise'].contains(persona)) {
      throw ArgumentError('persona 必须是 gentle/playful/wise 之一');
    }
    _persona = persona;
    _save('persona', persona);
  }

  /// 保存到 Hive
  Future<void> _save(String key, dynamic value) async {
    try {
      final box = await Hive.openBox('settings');
      await box.put(key, value);
    } catch (_) {
      // Hive 写入失败不影响主流程，内存值已更新
    }
  }
}
