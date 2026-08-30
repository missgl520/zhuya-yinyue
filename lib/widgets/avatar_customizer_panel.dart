import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/avatar_provider.dart';
import '../../core/theme/app_theme.dart';

/// 换装选择面板
class AvatarCustomizerPanel extends ConsumerWidget {
  const AvatarCustomizerPanel({super.key});

  // ─── 预设搭配 ────────────────────────────
  static const List<Map<String, String?>> _presets = [
    // 男
    {'gender': 'male', 'hair': 'black_short', 'top': 'tshirt_blue', 'bottom': 'jeans_blue', 'shoes': 'sneaker_white', 'label': '休闲少年'},
    {'gender': 'male', 'hair': 'brown_short', 'top': 'hoodie_grey', 'bottom': 'pants_grey', 'shoes': 'boots_brown', 'label': '暖冬男孩'},
    {'gender': 'male', 'hair': 'blonde_short', 'top': 'tshirt_red', 'bottom': 'jeans_black', 'shoes': 'sneaker_black', 'label': '活力运动'},
    // 女
    {'gender': 'female', 'hair': 'black_long', 'top': 'dress_pink', 'bottom': 'skirt_red', 'shoes': 'sandal_beige', 'label': '甜美少女'},
    {'gender': 'female', 'hair': 'brown_bob', 'top': 'hoodie_purple', 'bottom': 'jeans_blue', 'shoes': 'sneaker_white', 'label': '酷女孩'},
    {'gender': 'female', 'hair': 'black_bun', 'top': 'sweater_beige', 'bottom': 'pants_khaki', 'shoes': 'boots_brown', 'label': '文艺森系'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(avatarStateProvider);
    final notifier = ref.read(avatarStateProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          // 拖动条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
              children: [
                // ── 快速搭配预设 ─────────────────
                _SectionTitle('快速搭配'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final p = _presets[i];
                      final isActive = state.genderStr == p['gender'] &&
                          state.hairId == p['hair'] &&
                          state.topId == p['top'] &&
                          state.bottomId == p['bottom'] &&
                          state.shoesId == p['shoes'];
                      return GestureDetector(
                        onTap: () {
                          notifier.switchGender(p['gender'] == 'male' ? Gender.male : Gender.female);
                          notifier.setHair(p['hair']);
                          notifier.setTop(p['top']);
                          notifier.setBottom(p['bottom']);
                          notifier.setShoes(p['shoes']);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.accent : AppTheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isActive ? AppTheme.accent : AppTheme.border,
                              width: isActive ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            p['label']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              color: isActive ? Colors.white : AppTheme.fg2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                // ── 性别切换 ──────────────────────
                _SectionTitle('角色'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _GenderChip(
                      label: '👦 少年',
                      selected: state.gender == Gender.male,
                      onTap: () => notifier.switchGender(Gender.male),
                    ),
                    const SizedBox(width: 10),
                    _GenderChip(
                      label: '👧 少女',
                      selected: state.gender == Gender.female,
                      onTap: () => notifier.switchGender(Gender.female),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ── 发型 ─────────────────────────
                _SectionTitle('发型'),
                const SizedBox(height: 8),
                _PartGrid(
                  options: state.gender == Gender.male
                      ? AvatarCatalog.maleHair : AvatarCatalog.femaleHair,
                  selected: state.hairId,
                  onTap: (id) => notifier.setHair(id),
                  nameFn: (id) => AvatarCatalog.name('hair', id),
                ),

                const SizedBox(height: 18),

                // ── 上装 ─────────────────────────
                _SectionTitle('上装'),
                const SizedBox(height: 8),
                _PartGrid(
                  options: state.gender == Gender.male
                      ? AvatarCatalog.maleTops : AvatarCatalog.femaleTops,
                  selected: state.topId,
                  onTap: (id) => notifier.setTop(id),
                  nameFn: (id) => AvatarCatalog.name('top', id),
                ),

                const SizedBox(height: 18),

                // ── 下装 ─────────────────────────
                _SectionTitle('下装'),
                const SizedBox(height: 8),
                _PartGrid(
                  options: state.gender == Gender.male
                      ? AvatarCatalog.maleBottoms : AvatarCatalog.femaleBottoms,
                  selected: state.bottomId,
                  onTap: (id) => notifier.setBottom(id),
                  nameFn: (id) => AvatarCatalog.name('bottom', id),
                ),

                const SizedBox(height: 18),

                // ── 鞋子 ─────────────────────────
                _SectionTitle('鞋子'),
                const SizedBox(height: 8),
                _PartGrid(
                  options: state.gender == Gender.male
                      ? AvatarCatalog.maleShoes : AvatarCatalog.femaleShoes,
                  selected: state.shoesId,
                  onTap: (id) => notifier.setShoes(id),
                  nameFn: (id) => AvatarCatalog.name('shoes', id),
                ),

                const SizedBox(height: 18),

                // ── 瞳色 ─────────────────────────
                _SectionTitle('瞳色'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: AvatarCatalog.eyeColors.map((c) {
                    final swatch = AvatarCatalog.eyeColorSwatch[c]!;
                    return _EyeColorChip(
                      color: swatch,
                      name: AvatarCatalog.name('eye', c),
                      selected: state.eyeColor == c,
                      onTap: () => notifier.setEyeColor(c),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 22),

                // 重置
                Center(
                  child: TextButton.icon(
                    onPressed: () => notifier.reset(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('恢复默认'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.fg2,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext ctx) {
    return Text(title, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: AppTheme.fg2, letterSpacing: 0.5,
    ));
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? Colors.white : AppTheme.fg2,
        )),
      ),
    );
  }
}

class _PartGrid extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final void Function(String) onTap;
  final String Function(String) nameFn;

  const _PartGrid({
    required this.options, required this.selected,
    required this.onTap, required this.nameFn,
  });

  @override
  Widget build(BuildContext ctx) {
    return Wrap(
      spacing: 7, runSpacing: 7,
      children: options.map((id) {
        final isSelected = selected == id;
        return GestureDetector(
          onTap: () => onTap(isSelected ? '🔚CLEAR🔚' : id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accent.withValues(alpha: 0.10) : AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.accent : AppTheme.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(nameFn(id), style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.accent : AppTheme.fg2,
            )),
          ),
        );
      }).toList(),
    );
  }
}

class _EyeColorChip extends StatelessWidget {
  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _EyeColorChip({
    required this.color, required this.name,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withValues(alpha: 0.09) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 5),
            Text(name, style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppTheme.accent : AppTheme.fg2,
            )),
          ],
        ),
      ),
    );
  }
}
