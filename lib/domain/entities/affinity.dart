// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 好感度实体（Affinity Entity）
//
// 位于：domain/entities/affinity.dart
// 职责：描述用户与竹笌之间的好感度/关系状态
//
// 好感度体系（参考 GalGame 好感度设计）：
//   trust        信任值：用户对竹笌的信任程度（0-100）
//   intimacy    亲密度：情感连接的深度
//   familiarity 熟悉度：对用户习惯/喜好的了解程度
//
// 等级划分（累计互动轮数决定）：
//   0~10       陌生人  → 竹笌称呼用户为"你"
//   11~30      熟人    → 开始有昵称
//   31~60      朋友    → 可以撒娇
//   61~100     亲密    → 特殊称呼/行为解锁
//   100+       灵魂伴侣 → 最深层关系
//
// 数据来源：后端 /affinity 接口，SinoMem 持久化
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/foundation.dart';

/// 好感度实体
@immutable
class Affinity {
  /// 信任值（0-100），影响竹笌愿意分享的私密程度
  final double trust;

  /// 亲密度（0-100），影响竹笌的语气亲昵程度
  final double intimacy;

  /// 熟悉度（0-100），影响竹笌对用户习惯的记忆准确度
  final double familiarity;

  /// 累计对话轮数
  final int totalInteractions;

  /// 连续互动天数（签到奖励机制用）
  final int streakDays;

  const Affinity({
    this.trust = 30,
    this.intimacy = 20,
    this.familiarity = 5,
    this.totalInteractions = 0,
    this.streakDays = 0,
  });

  /// 初始值（新建用户）
  factory Affinity.initial() => const Affinity();

  /// 从后端 JSON 构造
  factory Affinity.fromJson(Map<String, dynamic> json) {
    return Affinity(
      trust: (json['trust'] as num?)?.toDouble() ?? 30,
      intimacy: (json['intimacy'] as num?)?.toDouble() ?? 20,
      familiarity: (json['familiarity'] as num?)?.toDouble() ?? 5,
      totalInteractions: (json['total_interactions'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
    );
  }

  /// 转 JSON
  Map<String, dynamic> toJson() => {
    'trust': trust,
    'intimacy': intimacy,
    'familiarity': familiarity,
    'total_interactions': totalInteractions,
    'streak_days': streakDays,
  };

  /// 关系等级描述文字
  String get level {
    if (totalInteractions >= 100) return '灵魂伴侣';
    if (totalInteractions >= 61) return '亲密';
    if (totalInteractions >= 31) return '朋友';
    if (totalInteractions >= 11) return '熟人';
    return '陌生人';
  }

  /// 好感度总分（用于排名/徽章展示）
  double get total => (trust + intimacy + familiarity) / 3;

  /// 好感度是否为空（初始状态）
  bool get isEmpty => totalInteractions == 0;

  /// 好感度是否达到某个阈值
  bool hasReached(double threshold) => total >= threshold;

  /// 克隆并修改字段
  Affinity copyWith({
    double? trust,
    double? intimacy,
    double? familiarity,
    int? totalInteractions,
    int? streakDays,
  }) {
    return Affinity(
      trust: trust ?? this.trust,
      intimacy: intimacy ?? this.intimacy,
      familiarity: familiarity ?? this.familiarity,
      totalInteractions: totalInteractions ?? this.totalInteractions,
      streakDays: streakDays ?? this.streakDays,
    );
  }

  @override
  String toString() =>
      'Affinity(level=$level, trust=$trust, intimacy=$intimacy, familiarity=$familiarity)';
}
