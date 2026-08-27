// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 路由配置（GoRouter）
//
// 声明式路由：路径 → 页面
//
// 路由列表（对齐 zhuyapp-design-2.0.md）：
//   /        → 启动页（SplashPage，2.5s 后自动跳转 /chat）
//   /chat    → 对话页（ChatPage），带淡入+上滑过渡动画
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../pages/splash/splash_page.dart';
import '../../pages/chat/chat_page.dart';
import '../../pages/settings/memory_history_page.dart';
import '../../pages/voice/voice_call_page.dart';
import '../../pages/legal/legal_page.dart';
import '../../pages/settings/info_modules_page.dart';
import '../../pages/avatar/avatar_fullscreen_page.dart';
import '../../pages/discover/discover_page.dart';
import '../../pages/profile/profile_page.dart';

/// GoRouter 实例 Provider
/// main.dart 用 ref.watch(routerProvider) 注入到 MaterialApp.router
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // 启动页：/ → SplashPage → 2.5s 后 context.go('/chat')
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // 对话页：自定义过渡动画（淡入 + 微微上滑）
      GoRoute(
        path: '/chat',
        name: 'chat',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ChatPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              ),
            );
          },
        ),
      ),
      // 实时语音通话页（全屏覆盖）
      GoRoute(
        path: '/voice-call',
        name: 'voice-call',
        builder: (context, state) => const VoiceCallPage(),
      ),
      // 记忆历史页
      GoRoute(
        path: '/memory-history',
        name: 'memory-history',
        builder: (context, state) => const MemoryHistoryPage(),
      ),
      // 法律文档页（隐私政策 / 用户协议）
      GoRoute(
        path: '/legal',
        name: 'legal',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'privacy';
          return LegalPage(type: type);
        },
      ),
      // 信息模块页（个人信息收集 / 第三方共享 / 版本介绍）
      GoRoute(
        path: '/info',
        name: 'info',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'version-intro';
          return InfoModulesPage(type: type);
        },
      ),
      // 3D 角色独立全屏页（二级程序：把「狗子」放在独立全屏查看）
      GoRoute(
        path: '/avatar',
        name: 'avatar',
        builder: (context, state) => const AvatarFullscreenPage(),
      ),

      // 首页 · 竹笌聊天唤醒陪伴（聊天页带 3D 竹笌角色）
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const ChatPage(),
      ),

      // 发现页 · 竹林一角（图 2 场景：浅绿背景 + 装饰竹柱 + 左下角小竹笌吉祥物）
      GoRoute(
        path: '/discover',
        name: 'discover',
        builder: (context, state) => const DiscoverPage(),
      ),

      // 我的页（通用：设置 / 记忆 / 隐私等）
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
    ],
  );
});
