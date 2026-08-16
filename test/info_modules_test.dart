// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 信息模块页 widget 测试
//
// 验证三个模块（个人信息收集 / 第三方共享 / 版本介绍）
// 能正常构建渲染、不抛异常，且标题正确。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhuyapp/pages/settings/info_modules_page.dart';
import 'package:zhuyapp/core/theme/app_theme.dart';

void main() {
  testWidgets('三个信息模块页面可正常渲染', (WidgetTester tester) async {
    const cases = {
      'pi-collection': '个人信息收集清单',
      'third-party-sharing': '与第三方共享清单',
      'version-intro': '版本介绍',
    };

    for (final entry in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: InfoModulesPage(type: entry.key),
        ),
      );
      await tester.pumpAndSettle();

      // 页面存在且标题正确
      expect(find.byType(InfoModulesPage), findsOneWidget);
      expect(find.text(entry.value), findsWidgets);

      // 关键内容块存在（验证不是空白页）
      switch (entry.key) {
        case 'pi-collection':
          expect(find.text('对话文本内容'), findsWidgets);
          break;
        case 'third-party-sharing':
          expect(find.text('Agnes AI（大模型对话服务）'), findsWidgets);
          break;
        case 'version-intro':
          expect(find.text('核心功能'), findsWidgets);
          break;
      }
    }
  });
}
