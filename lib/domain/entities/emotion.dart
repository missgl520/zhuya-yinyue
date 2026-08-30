// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 情绪实体（Emotion Entity）
//
// 位于：domain/entities/emotion.dart
// 职责：描述竹笌当前的情绪状态，与存储/传输无关
//
// 情绪维度说明（14 维 PAD 情绪模型）：
//   joy        喜悦
//   sadness    悲伤
//   anger      愤怒
//   fear       恐惧
//   curiosity  好奇
//   shame      羞耻
//   guilt      内疚
//   pride      自豪
//   attachment 依恋
//   aversion   厌恶
//   trust      信任
//   disgust    反感
//   frustration 沮丧
//   awe        敬畏
//
// 情绪来源：后端 /emotion 接口，返回识别结果
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/foundation.dart';

/// 情绪数据实体
@immutable
class Emotion {
  /// 主要情绪标签
  /// 可选值：happy / sad / angry / fearful / surprised /
  ///         disgusted / neutral / curious / proud / ashamed
  final String emotion;

  /// 置信度（0.0 ~ 1.0），越高越确定
  final double confidence;

  /// 14 维情绪强度（各维度 0.0 ~ 1.0）
  final Map<String, double> scores;

  const Emotion({
    this.emotion = 'neutral',
    this.confidence = 0.5,
    this.scores = const {},
  });

  /// 从后端 JSON 构造
  /// 后端返回格式：{ "emotion": "happy", "confidence": 0.92, "scores": {...} }
  factory Emotion.fromJson(Map<String, dynamic> json) {
    return Emotion(
      emotion: json['emotion'] as String? ?? 'neutral',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      scores:
          (json['scores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
    );
  }

  /// 转 JSON（用于调试/日志）
  Map<String, dynamic> toJson() => {
    'emotion': emotion,
    'confidence': confidence,
    'scores': scores,
  };

  /// 获取某一维度的情绪强度
  double score(String dimension) => scores[dimension] ?? 0.0;

  /// 是否为正面情绪（joy / happy / proud / curious）
  bool get isPositive =>
      ['happy', 'joy', 'proud', 'curious', 'trust'].contains(emotion);

  /// 是否为负面情绪（sad / angry / fearful / disgusted）
  bool get isNegative =>
      ['sad', 'angry', 'fearful', 'disgusted', 'ashamed'].contains(emotion);

  @override
  String toString() => 'Emotion($emotion, confidence=$confidence)';
}

/// 情绪标签 → emoji 图标（UI 展示用，集中管理避免散落各处）
String emotionEmoji(String label) {
  switch (label.toLowerCase()) {
    case 'happy':
    case 'joy':
      return '😊';
    case 'sad':
      return '😢';
    case 'angry':
      return '😠';
    case 'anxious':
      return '😟';
    case 'fearful':
    case 'fear':
      return '😨';
    case 'surprised':
      return '😲';
    case 'disgusted':
      return '🤢';
    case 'curious':
      return '🤔';
    case 'proud':
      return '🥰';
    case 'ashamed':
      return '😳';
    case 'neutral':
    default:
      return '😐';
  }
}

/// 情绪标签 → 中文文案
String emotionLabel(String label) {
  switch (label.toLowerCase()) {
    case 'happy':
    case 'joy':
      return '开心';
    case 'sad':
      return '难过';
    case 'angry':
      return '生气';
    case 'anxious':
      return '焦虑';
    case 'fearful':
    case 'fear':
      return '害怕';
    case 'surprised':
      return '惊讶';
    case 'disgusted':
      return '反感';
    case 'curious':
      return '好奇';
    case 'proud':
      return '自豪';
    case 'ashamed':
      return '羞愧';
    case 'neutral':
    default:
      return '平静';
  }
}
