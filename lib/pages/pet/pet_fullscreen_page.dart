// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐狗子全屏页（PetFullscreenPage）
//
// 位于：pages/pet/pet_fullscreen_page.dart
// 路由：/pet/full
//
// 功能：独立全屏查看音乐狗子角色 + 详细状态面板
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/backend_service.dart';
import '../../widgets/app_icon.dart';

class PetFullscreenPage extends StatefulWidget {
  const PetFullscreenPage({super.key});

  @override
  State<PetFullscreenPage> createState() => _PetFullscreenPageState();
}

class _PetFullscreenPageState extends State<PetFullscreenPage> {
  Map<String, dynamic> _petState = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await BackendService.instance.getPetState();
    setState(() {
      _petState = state;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.darkAccent))
          : Stack(
              children: [
                // 角色展示区（全屏）
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppTheme.sunSoft.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.sun, width: 3),
                        ),
                        child: const Center(
                          child: AppIcon(name: AppIconName.dog, size: AppIconSize.lg, color: AppTheme.sun),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        '音乐狗子',
                        style: TextStyle(fontSize: AppTheme.textXl, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        'Lv.${_petState['level'] ?? 1}',
                        style: TextStyle(fontSize: AppTheme.textMd, color: AppTheme.sun),
                      ),
                    ],
                  ),
                ),
                // 顶部返回按钮
                Positioned(
                  top: 40,
                  left: AppTheme.space4,
                  child: IconButton(
                    icon: const AppIcon(name: AppIconName.close, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
                // 底部状态面板
                Positioned(
                  left: AppTheme.space4,
                  right: AppTheme.space4,
                  bottom: AppTheme.space6,
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.space4),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('能量', '${(_petState['energy'] ?? 0).toInt()}', AppTheme.accent),
                        _buildStat('羁绊', '${(_petState['bond'] ?? 0).toInt()}', AppTheme.sun),
                        _buildStat('快乐', '${(_petState['happiness'] ?? 0).toInt()}', AppTheme.success),
                        _buildStat('交互', '${(_petState['total_interactions'] ?? 0).toInt()}', AppTheme.info),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: AppTheme.textLg, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted)),
      ],
    );
  }
}
