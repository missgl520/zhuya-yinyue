// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 隐私协议同意门
//
// 首次进入 App 时检测用户是否已同意当前版本条款，
// 未同意则弹全屏同意卡，同意后写入 Hive 不再弹出。
// 使用方式：Wrap(ConsentGate(child: HomePage()))
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// 隐私政策 / 用户协议版本号。条款更新时务必同步此版本，
/// 以便未同意新版本的用户在下次启动时被要求重新确认。
const String legalVersion = '2026-08-11';

/// 同意门 Widget：首次启动弹同意卡，之后不再弹
class ConsentGate extends StatefulWidget {
  final Widget child;

  const ConsentGate({super.key, required this.child});

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  bool _consentVisible = false;

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    final box = Hive.box('settings');
    final agreed = box.get('agreedToLegal', defaultValue: false) as bool;
    final agreedVersion = box.get('agreedToLegalVersion', defaultValue: '') as String;
    if (!agreed || agreedVersion != legalVersion) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _consentVisible = true);
    }
  }

  Future<void> _accept() async {
    final box = Hive.box('settings');
    await box.put('agreedToLegal', true);
    await box.put('agreedToLegalVersion', legalVersion);
    if (mounted) setState(() => _consentVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        widget.child,
        if (_consentVisible)
          Container(
            color: Colors.black.withValues(alpha: isDark ? 0.7 : 0.5),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '欢迎使用竹芽音乐宠物',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.softText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '竹芽音乐宠物是一款情感陪伴 AI，会收集并处理您的对话内容、语音及好感度等数据以提供陪伴服务。使用前请阅读并同意以下条款。',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[300] : AppTheme.subText,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _LegalTile(
                              icon: Icons.privacy_tip_outlined,
                              label: '隐私政策',
                              onTap: () => context.push('/legal?type=privacy'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LegalTile(
                              icon: Icons.description_outlined,
                              label: '用户协议',
                              onTap: () => context.push('/legal?type=terms'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _accept,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.bamboo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                            ),
                          ),
                          child: const Text(
                            '我已知晓并同意',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 同意卡内的法律入口小卡片
class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LegalTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.bamboo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: AppTheme.bamboo.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.bambooDeep, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : AppTheme.softText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
