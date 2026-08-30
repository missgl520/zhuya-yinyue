// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 竹笌 App Widget 测试
//
// 测试内容：
//   - 按 main() 的方式初始化（Hive + ProviderScope）后启动 App
//   - 验证启动页上能找到品牌文字 "竹  笌"
//
// 运行命令：
//   flutter test
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zhuyapp/main.dart';
import 'package:zhuyapp/core/config.dart';

void main() {
  testWidgets('竹笌 App 启动测试', (WidgetTester tester) async {
    // 模拟 main() 的初始化：否则缺少 ProviderScope / Hive 会导致 build 失败
    TestWidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    await Hive.openBox('settings');
    await Hive.openBox('messages');
    await Hive.openBox('memory');
    await BackendConfig.instance.init();

    // 加载根 Widget（与 main() 一致，包在 ProviderScope 内）
    await tester.pumpWidget(const ProviderScope(child: ZhuyApp()));
    // 等待首帧构建完成
    await tester.pump();

    // 断言：启动页上存在且仅存在一个 "竹  笌" 文本
    expect(find.text('竹  笌'), findsOneWidget);
  });
}
