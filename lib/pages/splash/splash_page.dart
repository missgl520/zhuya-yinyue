// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 启动页（Splash Page）
//
// 竹子 Logo + 品牌名 + 呼吸浮动 / 缩放 / 淡入动效
// 简约少年系：白底 + 嫩绿点缀，去掉多余的飘落装饰
// 同意门：全屏品牌卡片（隐私 / 协议两栏 + 主按钮），不挡视觉
// 动画结束或点击屏幕后自动跳转到对话页 /chat
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

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // 人物上下浮动动画控制器（呼吸感）
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  // Logo 整体缩放动画控制器（弹性放大）
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  // 整体淡入动画控制器
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  /// 用户是否已同意隐私政策 / 用户协议
  bool _agreed = false;

  /// 是否显示全屏同意卡
  bool _consentVisible = false;

  @override
  void initState() {
    super.initState();

    // 人物浮动：上下微微飘动，呼吸感
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 整体缩放：从0.6弹性放大到1.0
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // 整体淡入
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // 启动动画
    _fadeController.forward();
    _scaleController.forward();

    // 合规同意检查：已同意则延时跳转，未同意则显示全屏同意卡
    _initConsent();
  }

  /// 检查是否已同意当前版本的法律条款
  Future<void> _initConsent() async {
    final box = await Hive.openBox('settings');
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
    final box = await Hive.openBox('settings');
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
    _floatController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
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
            // 背景：paper → 淡绿 渐变
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [AppTheme.darkBg, const Color(0xFF223A2A)]
                      : [AppTheme.paper, const Color(0xFFEAF4DD)],
                ),
              ),
            ),

            // 中央内容
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_fadeAnim, _scaleAnim]),
                builder: (context, _) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 竹笌 Logo - 浮动动画
                          AnimatedBuilder(
                            animation: _floatAnim,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _floatAnim.value),
                                child: child,
                              );
                            },
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.bambooDeep.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 40,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                // 全局 Logo 竹子图案
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // 品牌名称 "竹  笌"
                          Text(
                            '竹  笌',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.bambooDeep,
                              letterSpacing: 12,
                              shadows: [
                                Shadow(
                                  color: AppTheme.bambooDeep.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 品牌 Slogan
                          Text(
                            '情感陪伴 · 随时倾听',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
