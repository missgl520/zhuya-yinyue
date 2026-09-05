// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 首页槽位模型
//
// 9 个固定槽位，每个槽位可独立配置：
//   - 图标 / 文字
//   - 点击行为（路由跳转 / 外部链接 / 空槽）
//   - 尺寸（普通格 / 中央大格）
//
// 槽位索引：
//   入口1  入口2  入口3  入口4  入口5
//                  入口6（中央大格）
//   入口7  入口8  入口9
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';

/// 槽位类型
enum SlotType {
  /// 空槽位
  empty,

  /// 关于（logo 图标入口）
  about,

  /// 3D 音乐狗（进入换装/展示）
  musicDog,

  /// 设置
  settings,

  /// 图库（宠物/穿搭素材库）
  gallery,

  /// 语音通话
  voiceCall,

  /// 文本聊天
  chat,

  /// 音乐播放
  music,

  /// 自定义（任意跳转）
  custom,
}

/// 槽位配置
class HomeSlot {
  /// 槽位索引（0-8）
  final int index;

  /// 槽位类型
  final SlotType type;

  /// 自定义时显示的文字
  final String? label;

  /// 自定义时显示的图标（IconData 或 Asset）
  final IconData? icon;

  /// 自定义时点击跳转的路由或 URL
  final String? route;

  /// 是否中央大格（index == 6）
  bool get isCenter => index == 6;

  /// 是否空槽
  bool get isEmpty => type == SlotType.empty;

  const HomeSlot({
    required this.index,
    this.type = SlotType.empty,
    this.label,
    this.icon,
    this.route,
  });

  /// 快速创建空槽
  factory HomeSlot.empty(int index) => HomeSlot(index: index);

  /// 槽位类型 → 默认图标
  static IconData defaultIcon(SlotType type) {
    switch (type) {
      case SlotType.empty:
        return Icons.circle_outlined;
      case SlotType.about:
        return Icons.info_outline;
      case SlotType.musicDog:
        return Icons.pets;
      case SlotType.settings:
        return Icons.settings_outlined;
      case SlotType.gallery:
        return Icons.photo_library_outlined;
      case SlotType.voiceCall:
        return Icons.mic;
      case SlotType.chat:
        return Icons.chat_bubble_outline;
      case SlotType.music:
        return Icons.music_note;
      case SlotType.custom:
        return Icons.apps;
    }
  }

  /// 槽位类型 → 默认文字
  static String defaultLabel(SlotType type) {
    switch (type) {
      case SlotType.empty:
        return '';
      case SlotType.about:
        return '关于';
      case SlotType.musicDog:
        return '音乐狗';
      case SlotType.settings:
        return '设置';
      case SlotType.gallery:
        return '图库';
      case SlotType.voiceCall:
        return '语音';
      case SlotType.chat:
        return '聊天';
      case SlotType.music:
        return '音乐';
      case SlotType.custom:
        return '功能';
    }
  }

  /// 槽位类型 → 默认路由
  static String? defaultRoute(SlotType type) {
    switch (type) {
      case SlotType.empty:
        return null;
      case SlotType.about:
        return '/info';
      case SlotType.musicDog:
        return '/music-dog';
      case SlotType.settings:
        return '/settings';
      case SlotType.gallery:
        return '/pet/library';
      case SlotType.voiceCall:
        return '/voice';
      case SlotType.chat:
        return '/chat';
      case SlotType.music:
        return '/music';
      case SlotType.custom:
        return null;
    }
  }

  HomeSlot copyWith({
    int? index,
    SlotType? type,
    String? label,
    IconData? icon,
    String? route,
  }) {
    return HomeSlot(
      index: index ?? this.index,
      type: type ?? this.type,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      route: route ?? this.route,
    );
  }
}
