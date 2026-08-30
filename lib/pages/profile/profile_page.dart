// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 我的页（占位）
//
// 竹芽底部导航第三项。当前是简单占位（个人头像 + 设置入口），
// 后续可接入登录、收藏、设置、关于等。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE5),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 顶部留白 + 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: const [
                  Text(
                    '我的',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3D2914),
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),

            // 内容
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 用户卡片
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFBE4D5),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '🐶',
                            style: TextStyle(fontSize: 28),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '主人',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3D2914),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '与狗子相伴的第 1 天',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7A5D44),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 功能列表
                  _MenuTile(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    onTap: () {
                      // TODO: 设置页
                    },
                  ),
                  _MenuTile(
                    icon: Icons.history,
                    label: '记忆历史',
                    onTap: () => context.push('/memory-history'),
                  ),
                  _MenuTile(
                    icon: Icons.privacy_tip_outlined,
                    label: '隐私政策',
                    onTap: () => context.push('/legal?type=privacy'),
                  ),
                  _MenuTile(
                    icon: Icons.description_outlined,
                    label: '用户协议',
                    onTap: () => context.push('/legal?type=terms'),
                  ),
                  _MenuTile(
                    icon: Icons.info_outline,
                    label: '关于竹笌',
                    onTap: () => context.push('/info?type=version-intro'),
                  ),
                ],
              ),
            ),

            // 注意：底部导航已移除（竹笌不再有首页/发现/我的 tab），保留完整菜单。
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF8B4513)),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF3D2914),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
      ),
    );
  }
}
