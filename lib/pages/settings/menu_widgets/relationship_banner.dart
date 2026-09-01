// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 角色关系 Banner（头像 + 昵称 + 等级 + 好感度环形进度）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/emotion.dart';
import '../../presentation/providers/app_providers.dart';

/// 好感度环形进度（信任/亲密/熟悉均值）
class AffinityRing extends StatelessWidget {
  final AffinityData affinity;

  const AffinityRing({super.key, required this.affinity});

  @override
  Widget build(BuildContext context) {
    final avg = (affinity.trust + affinity.intimacy + affinity.familiarity) / 3;
    final pct = (avg / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct,
            strokeWidth: 4,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            color: AppTheme.bambooDeep,
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${avg.toInt()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.bambooDeep,
            ),
          ),
        ],
      ),
    );
  }
}

/// 角色关系 Banner
class RelationshipBanner extends StatelessWidget {
  final AffinityData affinity;
  final String currentEmotion;

  const RelationshipBanner({
    super.key,
    required this.affinity,
    required this.currentEmotion,
  });

  String get _levelDescription {
    return switch (affinity.level) {
      '灵魂伴侣' => '彼此理解，心有灵犀',
      '知己' => '懂你心思，默契十足',
      '好友' => '相处融洽，互相关心',
      '朋友' => '开始熟悉，愿意倾听',
      '认识' => '初次相识，还在了解',
      _ => '我们刚认识，可以随便聊聊',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.bamboo.withValues(alpha: 0.15),
            AppTheme.warmYellow.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 竹笌头像
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.bamboo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/logo_mascot.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '竹笌',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.bamboo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        affinity.level,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.bamboo,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  affinity.streakDays > 0
                      ? '🔥 ${affinity.streakDays} 天连续 · $_levelDescription'
                      : _levelDescription,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (currentEmotion != 'neutral') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        emotionEmoji(currentEmotion),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '现在${emotionLabel(currentEmotion)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 好感度环形进度
          AffinityRing(affinity: affinity),
        ],
      ),
    );
  }
}
