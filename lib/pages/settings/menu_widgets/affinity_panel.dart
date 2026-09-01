// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 好感度详情（信任 / 亲密 / 熟悉 三项进度条）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../presentation/providers/app_providers.dart';

/// 好感度详情面板（信任/亲密/熟悉三条进度条）
class AffinityPanel extends StatelessWidget {
  final AffinityData affinity;

  const AffinityPanel({super.key, required this.affinity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '关系状态',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          AffinityBar(label: '信任', value: affinity.trust, max: 100),
          const SizedBox(height: 6),
          AffinityBar(label: '亲密', value: affinity.intimacy, max: 100),
          const SizedBox(height: 6),
          AffinityBar(label: '熟悉', value: affinity.familiarity, max: 100),
        ],
      ),
    );
  }
}

/// 单条好感度进度条
class AffinityBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;

  const AffinityBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bamboo,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '${value.toInt()}/$max',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
