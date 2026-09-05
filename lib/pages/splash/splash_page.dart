// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 启动页（Splash Page）
//
// 全屏展示 assets/logo/splash_cover.png
// 首次启动弹隐私政策/用户协议同意卡
// 动画结束或点击屏幕后自动跳转到首页 /home
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/app_theme.dart';

/// 隐私政策 / 用户协议版本号。条款更新时务必同步此版本，
/// 以便未同意新版本的用户在下次启动时被要求重新确认。
const String _legalVersion = '2026-08-11';

/// 启动页 Widget：有状态，需要管理多个动画控制器
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// 用户是否已同意隐私政策 / 用户协议
  bool _agreed = false;

  /// 是否显示全屏同意卡
  bool _consentVisible = false;

  @override
  void initState() {
    super.initState();
    _initConsent();
  }

  /// 检查是否已同意当前版本的法律条款
  Future<void> _initConsent() async {
    // boxes 由 main.dart 在 runApp 前统一初始化（已加密），此处直接引用
    final box = Hive.box('settings');
    final agreed = box.get('agreedToLegal', defaultValue: false) as bool;
    final agreedVersion =
        box.get('agreedToLegalVersion', defaultValue: '') as String;
    if (agreed && agreedVersion == _legalVersion) {
      if (mounted) setState(() => _agreed = true);
      _scheduleNavigate();
    } else {
      if (mounted) setState(() => _consentVisible = true);
    }
  }

  /// 已同意后延时跳转到竹芽首页
  void _scheduleNavigate() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) context.go('/home');
    });
  }

  /// 同意按钮：写入 Hive，关闭卡片并跳转
  Future<void> _acceptConsent() async {
    // boxes 由 main.dart 在 runApp 前统一初始化（已加密），此处直接引用
    final box = Hive.box('settings');
    await box.put('agreedToLegal', true);
    await box.put('agreedToLegalVersion', _legalVersion);
    if (mounted) {
      setState(() {
        _agreed = true;
        _consentVisible = false;
      });
      context.go('/home');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.paper,
      body: GestureDetector(
        onTap: () {
          if (_agreed) {
            context.go('/home');
          } else if (!_consentVisible) {
            // 已同意跳过；未同意则弹出全屏同意卡
            setState(() => _consentVisible = true);
          }
        },
        child: Stack(
          children: [
            // 全屏启动图
            Positioned.fill(
              child: Image.asset(
                'assets/logo/splash_cover.png',
                fit: BoxFit.cover,
              ),
            ),

            // 全屏同意卡（半透明遮罩 + 居中品牌卡片，不挡视觉）
            if (_consentVisible)
              _ConsentCard(
                isDark: isDark,
                onPrivacy: () => context.push('/legal?type=privacy'),
                onTerms: () => context.push('/legal?type=terms'),
                onAccept: _acceptConsent,
              ),
          ],
        ),
      ),
    );
  }
}

/// 全屏同意品牌卡片
class _ConsentCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final Future<void> Function() onAccept;

  const _ConsentCard({
    required this.isDark,
    required this.onPrivacy,
    required this.onTerms,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.35),
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
                  color: Colors.black.withValues(alpha: 0.15),
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
                  '欢迎使用竹笌',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.softText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '竹笌是一款情感陪伴 AI，会收集并处理您的对话内容、语音及好感度等数据'
                  '以提供陪伴服务。使用前请阅读并同意以下条款。',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : AppTheme.subText,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 隐私 / 协议 两栏
                Row(
                  children: [
                    Expanded(
                      child: _LegalTile(
                        icon: Icons.privacy_tip_outlined,
                        label: '隐私政策',
                        onTap: onPrivacy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LegalTile(
                        icon: Icons.description_outlined,
                        label: '用户协议',
                        onTap: onTerms,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 主按钮
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAccept,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
