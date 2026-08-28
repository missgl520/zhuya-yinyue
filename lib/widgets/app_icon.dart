// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// AppIcon —— 全项目图标唯一门面
//
// 位于：widgets/app_icon.dart
// 职责：统一封装图标，禁止全项目直接使用 Icons.* / CupertinoIcons.* / emoji
//
// P0 红线（DESIGN.md §6）：
//   - 任何功能图标一律走 AppIcon 门面访问
//   - emoji 仅允许出现在用户 UGC 文本（用户自己发的消息），绝不作 UI 图标
//   - 全项目 grep "Icons\.|CupertinoIcons\." 必须为 0（业务代码层）
//
// 底层实现说明：
//   原计划使用 lucide_icons 包，但该包最新版 0.257.0 不兼容 Flutter 3.47+
//   （IconData 变为 final class，无法继承）。当前底层映射到 Material Icons，
//   业务代码通过 AppIconName 枚举访问，后续替换底层实现只需修改映射表。
//
// 尺寸规范（DESIGN.md §3）：
//   16px —— 行内/小标
//   20px —— 按钮内
//   24px —— 导航/独立图标
//   32px —— 大图标
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';

/// 图标尺寸枚举
enum AppIconSize {
  /// 16px —— 行内/小标
  xs(16.0),

  /// 20px —— 按钮内
  sm(20.0),

  /// 24px —— 导航/独立图标
  md(24.0),

  /// 32px —— 大图标
  lg(32.0);

  final double value;
  const AppIconSize(this.value);
}

/// AppIcon —— 全项目图标唯一门面
///
/// 用法：
/// ```dart
/// AppIcon(name: AppIconName.arrowLeft)
/// AppIcon(name: AppIconName.music, size: AppIconSize.sm, color: AppTheme.accent)
/// ```
class AppIcon extends StatelessWidget {
  /// 图标名称（从 AppIconName 枚举选择）
  final AppIconName name;

  /// 图标尺寸，默认 md(24px)
  final AppIconSize size;

  /// 图标颜色，默认 currentColor（跟随父级文本颜色）
  final Color? color;

  const AppIcon({
    super.key,
    required this.name,
    this.size = AppIconSize.md,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      name.iconData,
      size: size.value,
      color: color,
    );
  }
}

/// 图标名称枚举 —— 全项目可用图标在此声明
///
/// 新增图标时：在此枚举添加一项，映射到对应的 IconData。
/// 禁止在业务代码中直接使用 Icons.xxx，必须经此门面。
///
/// 当前底层映射到 Material Icons；后续替换为 Lucide/SVG 时只需修改映射表。
enum AppIconName {
  // ── 导航与操作 ──
  arrowLeft(Icons.arrow_back_ios_new),
  arrowRight(Icons.arrow_forward_ios),
  chevronRight(Icons.chevron_right),
  chevronDown(Icons.keyboard_arrow_down),
  chevronUp(Icons.keyboard_arrow_up),
  close(Icons.close),
  menu(Icons.menu),
  settings(Icons.settings),
  search(Icons.search),
  refresh(Icons.refresh),
  info(Icons.info_outline),
  help(Icons.help_outline),

  // ── 音乐与创作 ──
  music(Icons.music_note),
  music2(Icons.music_note_outlined),
  music4(Icons.library_music),
  library(Icons.library_music),
  play(Icons.play_arrow),
  pause(Icons.pause),
  skipForward(Icons.skip_next),
  skipBack(Icons.skip_previous),
  volume2(Icons.volume_up),
  volumeX(Icons.volume_off),
  headphones(Icons.headphones),
  disc(Icons.album),
  mic(Icons.mic),
  micOff(Icons.mic_off),
  send(Icons.send),
  edit(Icons.edit),
  plus(Icons.add),
  trash(Icons.delete_outline),
  download(Icons.download),
  share(Icons.share),

  // ── 宠物与情感 ──
  dog(Icons.pets),
  heart(Icons.favorite_border),
  heartFilled(Icons.favorite),
  smile(Icons.sentiment_satisfied_alt),
  frown(Icons.sentiment_dissatisfied),
  angry(Icons.sentiment_very_dissatisfied),
  zap(Icons.bolt),
  flame(Icons.local_fire_department),
  sparkles(Icons.auto_awesome),
  star(Icons.star_border),

  // ── 对话与消息 ──
  messageCircle(Icons.chat_bubble_outline),
  messagesSquare(Icons.forum_outlined),
  image(Icons.image_outlined),
  camera(Icons.photo_camera_outlined),
  paperclip(Icons.attach_file),

  // ── 状态与反馈 ──
  check(Icons.check),
  checkCircle(Icons.check_circle_outline),
  alertCircle(Icons.error_outline),
  alertTriangle(Icons.warning_amber_rounded),
  loader(Icons.autorenew),
  clock(Icons.schedule),
  calendar(Icons.calendar_today),
  history(Icons.history),

  // ── 用户与账号 ──
  user(Icons.person_outline),
  users(Icons.people_outline),
  shield(Icons.verified_user_outlined),
  lock(Icons.lock_outline),
  logOut(Icons.logout),

  // ── 植物与自然（竹笌品牌） ──
  leaf(Icons.eco),
  sprout(Icons.local_florist),
  treePine(Icons.forest),
  sun(Icons.wb_sunny_outlined),
  moon(Icons.nightlight_round),

  // ── 电话与通话 ──
  phone(Icons.phone),
  phoneOff(Icons.phone_disabled),
  phoneCall(Icons.call),
  video(Icons.videocam_outlined),

  // ── 文件与数据 ──
  fileText(Icons.description_outlined),
  folder(Icons.folder_outlined),
  database(Icons.storage),
  hardDrive(Icons.memory),

  // ── 布局与界面 ──
  home(Icons.home_outlined),
  grid(Icons.grid_view),
  list(Icons.list),
  filter(Icons.filter_list),
  sliders(Icons.tune),
  moreHorizontal(Icons.more_horiz),
  moreVertical(Icons.more_vert),
  externalLink(Icons.open_in_new),

  // ── 主题与显示 ──
  palette(Icons.palette_outlined),
  type(Icons.text_fields),
  eye(Icons.visibility_outlined),
  eyeOff(Icons.visibility_off_outlined),

  // ── 设备与硬件 ──
  smartphone(Icons.smartphone),
  monitor(Icons.monitor),
  speaker(Icons.speaker),
  bluetooth(Icons.bluetooth),
  wifi(Icons.wifi),
  wifiOff(Icons.wifi_off),
  battery(Icons.battery_full),
  cpu(Icons.memory),

  // ── 安全与合规 ──
  shieldAlert(Icons.gpp_bad_outlined),
  fileWarning(Icons.report_gmailerrorred),
  scale(Icons.balance),
  badgeCheck(Icons.verified_outlined),

  // ── 其他常用 ──
  link(Icons.link),
  unlink(Icons.link_off),
  copy(Icons.copy),
  scissors(Icons.content_cut),
  maximize(Icons.fullscreen),
  minimize(Icons.fullscreen_exit),
  move(Icons.open_with),
  rotate(Icons.rotate_right),
  zoomIn(Icons.zoom_in),
  zoomOut(Icons.zoom_out),
  ;

  /// 对应的 IconData（当前底层为 Material Icons）
  final IconData iconData;

  const AppIconName(this.iconData);
}
