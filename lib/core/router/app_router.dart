// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 路由配置（GoRouter）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../pages/splash/splash_page.dart';
import '../../pages/home/home_page.dart';
import '../../pages/chat/chat_page.dart';
import '../../pages/voice/voice_call_page.dart';
import '../../pages/legal/legal_page.dart';
import '../../pages/settings/info_modules_page.dart';
import '../../pages/settings/settings_page.dart';
import '../../pages/pet/pet_library_page.dart';
import '../../pages/music/music_page.dart';
import '../../pages/music_dog/music_dog_page.dart';
import '../../pages/avatar/avatar_customize_page.dart';
import '../../widgets/consent_gate.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // 启动页
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // 首页：9 槽位网格
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),

      // 对话页
      GoRoute(
        path: '/chat',
        name: 'chat',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ConsentGate(child: ChatPage()),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              ),
            );
          },
        ),
      ),

      // 语音通话页
      GoRoute(
        path: '/voice-call',
        name: 'voice-call',
        builder: (context, state) => const VoiceCallPage(),
      ),

      // 法律文档页
      GoRoute(
        path: '/legal',
        name: 'legal',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'privacy';
          return LegalPage(type: type);
        },
      ),

      // 信息模块页
      GoRoute(
        path: '/info',
        name: 'info',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'version-intro';
          return InfoModulesPage(type: type);
        },
      ),

      // 设置页
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),



      // 3D 音乐狗换装定制页
      GoRoute(
        path: '/avatar',
        name: 'avatar',
        builder: (context, state) => const AvatarFullscreenPage(),
      ),
      GoRoute(
        path: '/avatar/customize',
        name: 'avatar-customize',
        builder: (context, state) => const AvatarCustomizePage(),
      ),

      // 音乐库（歌词 + 歌曲）
      // 音乐狗页（3D狗+播放+图库合并）
      GoRoute(
        path: '/music-dog',
        name: 'music-dog',
        builder: (context, state) => const AvatarCustomizePage(),
      ),
      GoRoute(
        path: '/pet/library',
        name: 'pet-library',
        builder: (context, state) => const PetLibraryPage(),
      ),

      // 音乐播放页
      GoRoute(
        path: '/music',
        name: 'music',
        builder: (context, state) => const MusicPage(),
      ),
    ],
  );
});
