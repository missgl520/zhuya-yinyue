// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 首页（Home Page）
//
// 9 个固定槽位网格，槽位可独立配置跳转功能
// 布局：
//   入口1  入口2  入口3  入口4  入口5
//                  入口6（中央大格）
//   入口7  入口8  入口9
//
// 当前默认配置：
//   入口1 → 关于   入口3 → 音乐狗   入口5 → 设置
//   入口7 → 图库   入口8 → 语音     入口9 → 聊天
//   入口2/4/6 → 空（后续可配置）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/home_slot.dart';

/// 首页默认槽位配置（启动时从 Hive 读取，支持运行时热改）
List<HomeSlot> _buildDefaultSlots() {
  return [
    // 顶部一行 5 格
    const HomeSlot(index: 0, type: SlotType.about),
    HomeSlot.empty(1),
    const HomeSlot(index: 2, type: SlotType.musicDog),
    HomeSlot.empty(3),
    const HomeSlot(index: 4, type: SlotType.settings),
    // 中间 1 格（中央大格）
    HomeSlot.empty(5),
    // 底部一行 3 格
    const HomeSlot(index: 6, type: SlotType.gallery),
    const HomeSlot(index: 7, type: SlotType.voiceCall),
    const HomeSlot(index: 8, type: SlotType.chat),
  ];
}

/// 读取槽位配置（Hive 持久化，支持用户自定义）
List<HomeSlot> _loadSlots() {
  try {
    final box = Hive.box('settings');
    final raw = box.get('homeSlots');
    if (raw != null && raw is List) {
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return HomeSlot(
          index: m['index'] as int,
          type: SlotType.values[m['type'] as int? ?? 0],
          label: m['label'] as String?,
          route: m['route'] as String?,
        );
      }).toList();
    }
  } catch (_) {}
  return _buildDefaultSlots();
}

/// 保存槽位配置到 Hive
Future<void> _saveSlots(List<HomeSlot> slots) async {
  try {
    final box = Hive.box('settings');
    await box.put('homeSlots', slots.map((s) => {
      'index': s.index,
      'type': s.type.index,
      'label': s.label,
      'route': s.route,
    }).toList());
  } catch (_) {}
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<HomeSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = _loadSlots();
  }

  void _onSlotTap(HomeSlot slot) {
    if (slot.isEmpty) return;
    final route = slot.route ?? HomeSlot.defaultRoute(slot.type);
    if (route != null) {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // 顶部 5 格
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _SlotTile(slot: _slots[0], onTap: () => _onSlotTap(_slots[0])),
                    _SlotTile(slot: _slots[1], onTap: () => _onSlotTap(_slots[1])),
                    _SlotTile(slot: _slots[2], onTap: () => _onSlotTap(_slots[2])),
                    _SlotTile(slot: _slots[3], onTap: () => _onSlotTap(_slots[3])),
                    _SlotTile(slot: _slots[4], onTap: () => _onSlotTap(_slots[4])),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 中间 1 格（大格）
              Expanded(
                flex: 2,
                child: _SlotTile(slot: _slots[5], onTap: () => _onSlotTap(_slots[5]), large: true),
              ),
              const SizedBox(height: 8),
              // 底部 3 格
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _SlotTile(slot: _slots[6], onTap: () => _onSlotTap(_slots[6])),
                    _SlotTile(slot: _slots[7], onTap: () => _onSlotTap(_slots[7])),
                    _SlotTile(slot: _slots[8], onTap: () => _onSlotTap(_slots[8])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个槽位 Tile
class _SlotTile extends StatelessWidget {
  final HomeSlot slot;
  final VoidCallback onTap;
  final bool large;

  const _SlotTile({
    required this.slot,
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: slot.isEmpty ? null : onTap,
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: slot.isEmpty
                ? Colors.transparent
                : isDark
                    ? AppTheme.darkCard
                    : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: slot.isEmpty
                ? null
                : Border.all(
                    color: AppTheme.bamboo.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
            boxShadow: slot.isEmpty
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: slot.isEmpty
              ? null
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      slot.icon ?? HomeSlot.defaultIcon(slot.type),
                      size: large ? 36 : 28,
                      color: AppTheme.bamboo,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      slot.label ?? HomeSlot.defaultLabel(slot.type),
                      style: TextStyle(
                        fontSize: large ? 13 : 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : AppTheme.softText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
