// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 信息模块页（InfoModulesPage）
//
// 承载三个合规 / 信息展示模块，通过 type 区分：
//   pi-collection      → 个人信息收集清单
//   third-party-sharing → 与第三方共享清单
//   version-intro       → 版本介绍
//
// 纯静态内容（不依赖后端），如实反映竹笌当前的数据流向。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class InfoModulesPage extends StatelessWidget {
  final String
  type; // 'pi-collection' | 'third-party-sharing' | 'version-intro'

  const InfoModulesPage({super.key, required this.type});

  String get _title {
    return switch (type) {
      'pi-collection' => '个人信息收集清单',
      'third-party-sharing' => '与第三方共享清单',
      'version-intro' => '版本介绍',
      _ => '信息',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : AppTheme.paper,
        foregroundColor: isDark ? Colors.white : AppTheme.softText,
        elevation: 0,
        title: Text(_title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildContent(type),
          ),
        ),
      ),
    );
  }

  /// 各模块正文（如实反映竹笌当前数据流向）
  List<Widget> _buildContent(String type) {
    final items = switch (type) {
      'pi-collection' => _piCollection(),
      'third-party-sharing' => _thirdPartySharing(),
      'version-intro' => _versionIntro(),
      _ => <Widget>[const Text('暂无内容')],
    };
    return items;
  }

  // ──────────────────────────────────────────────
  // 1. 个人信息收集清单
  // ──────────────────────────────────────────────
  List<Widget> _piCollection() {
    return [
      _intro(
        '竹笌仅在为你提供情感陪伴、对话记忆与语音交互服务所必需的范围内收集个人信息。'
        '以下清单说明我们收集的信息类别、用途及是否可由你控制。',
      ),
      _sectionTitle('一、我们收集的信息'),
      _card(
        title: '对话文本内容',
        subtitle: '你输入给竹笌的文字，以及竹笌生成的回复文本',
        rows: const [
          ('用途', '生成 AI 回复、维护对话上下文'),
          ('是否可关闭', '否（服务核心功能）'),
          ('存储位置', '云端后端 · 加密长期记忆'),
        ],
      ),
      _card(
        title: '语音输入音频',
        subtitle: '使用语音输入时采集的麦克风音频',
        rows: const [
          ('用途', '经语音识别转为文字后再处理'),
          ('是否可关闭', '是（不授权麦克风即仅能用文字）'),
          ('存储位置', '设备端识别，原始音频不上传第三方'),
        ],
      ),
      _card(
        title: '设备与系统信息',
        subtitle: '设备型号、操作系统版本、App 版本号、网络状态',
        rows: const [
          ('用途', '兼容性适配与异常排查'),
          ('是否可关闭', '否（运行所必需）'),
          ('存储位置', '本地 / 后端运行日志'),
        ],
      ),
      _card(
        title: '关系与情绪数据',
        subtitle: '好感度（信任 / 亲密 / 熟悉）、情绪识别结果、连续互动天数',
        rows: const [
          ('用途', '呈现你们的关系状态与互动反馈'),
          ('是否可关闭', '否（陪伴体验核心）'),
          ('存储位置', '云端后端 · 加密存储'),
        ],
      ),
      _card(
        title: '记忆与摘要',
        subtitle: '跨会话长期记忆、自动生成的对话摘要',
        rows: const [
          ('用途', '让竹笌记住你、保持对话连贯'),
          ('是否可关闭', '是（可在「记忆管理」中清空）'),
          ('存储位置', '云端数据库 · 加密存储'),
        ],
      ),
      _card(
        title: '个性化设置',
        subtitle: '角色设定、唤醒词、后端地址、音色偏好',
        rows: const [
          ('用途', '定制竹笌的性格与交互方式'),
          ('是否可关闭', '是（随时可重置）'),
          ('存储位置', '本地（Hive）· 部分同步云端'),
        ],
      ),
      _sectionTitle('二、你的权利'),
      _intro(
        '你有权随时在「设置 → 记忆管理」中查看或清空对话记忆；'
        '可在「声音设置」关闭语音播报、在「语音设置」收回麦克风授权。'
        '如需删除账户相关数据，可联系开发者协助处理。',
      ),
    ];
  }

  // ──────────────────────────────────────────────
  // 2. 与第三方共享清单
  // ──────────────────────────────────────────────
  List<Widget> _thirdPartySharing() {
    return [
      _intro(
        '为提供对话、语音合成与云端存储能力，竹笌会将必要的个人信息共享给以下第三方服务商。'
        '我们仅共享实现对应功能所必需的数据，并要求其按约定用途处理。',
      ),
      _sectionTitle('共享对象清单'),
      _card(
        title: 'Agnes AI（大模型对话服务）',
        subtitle: '国内版 / 国际版，用于生成 AI 回复',
        rows: const [
          ('共享内容', '对话文本'),
          ('用途', '理解你的输入并生成竹笌的回复'),
          ('数据出境', '国际版部署在境外，切换需你单独同意'),
        ],
      ),
      _card(
        title: 'MiniMax（语音合成服务）',
        subtitle: '用于把文字回复合成为语音播放',
        rows: const [('共享内容', 'AI 回复文本'), ('用途', '文字转语音（TTS）'), ('数据出境', '国内')],
      ),
      _card(
        title: '腾讯云 CloudBase（后端托管）',
        subtitle: '竹笌后端服务的运行平台',
        rows: const [
          ('共享内容', '上述全部云端处理的数据'),
          ('用途', '对话、记忆、好感度计算与持久化'),
          ('数据出境', '国内'),
        ],
      ),
      _card(
        title: 'SQLPub（云数据库）',
        subtitle: '长期记忆与关系数据的持久化存储',
        rows: const [
          ('共享内容', '记忆数据、好感度数据（加密）'),
          ('用途', '跨设备持久化存储'),
          ('数据出境', '国内'),
        ],
      ),
      _card(
        title: '系统语音识别（设备端）',
        subtitle: '设备自带的语音转文字能力',
        rows: const [
          ('共享内容', '语音输入音频'),
          ('用途', '转为文字后交由竹笌处理'),
          ('数据出境', '不外传第三方'),
        ],
      ),
      _sectionTitle('我们不做的事'),
      _intro(
        '竹笌不会将上述个人信息用于广告定向投放，不会出售你的个人信息，'
        '也不会在未经你同意的情况下向清单之外的第三方共享。',
      ),
    ];
  }

  // ──────────────────────────────────────────────
  // 3. 版本介绍
  // ──────────────────────────────────────────────
  List<Widget> _versionIntro() {
    return [
      // 版本卡
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bamboo.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.bamboo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: AppTheme.bamboo,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '竹笌',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '当前版本 1.0.0',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '竹笌是一个 2D 虚拟角色语音陪聊 App，随时倾听你的心声，'
              '陪你聊天、记住你、慢慢变得熟悉。',
              style: TextStyle(fontSize: 14, height: 1.65),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _sectionTitle('核心功能'),
      _bullet('🗨️ 文字 / 语音对话：和竹笌自然聊天，支持语音输入'),
      _bullet('🔊 情感语音播报：用 MiniMax 语音合成朗读回复'),
      _bullet('🌱 长期记忆：跨会话记住你说过的话与偏好'),
      _bullet('💞 关系与好感度：信任、亲密、熟悉随互动成长'),
      _bullet('😊 情绪识别：感知你的情绪并温柔回应'),
      _bullet('🎭 角色设定：自定义竹笌的性格与说话风格'),
      _bullet('🐱 Live2D 形象：可切换的 2D 虚拟形象'),
      const SizedBox(height: 18),
      _sectionTitle('版本历史'),
      _card(
        title: '1.0.0',
        subtitle: '首发版本',
        rows: const [
          ('类型', '正式版'),
          ('日期', '2026-08'),
          ('亮点', '对话记忆、语音播报、好感度系统'),
        ],
      ),
      const SizedBox(height: 12),
      _intro('本页信息随功能迭代更新。如对某些能力有疑问，可在「隐私政策」中查看完整条款。'),
    ];
  }

  // ── 通用构件 ──
  Widget _intro(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, height: 1.7, color: Colors.grey),
    ),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 14, height: 1.6)),
  );

  Widget _card({
    required String title,
    String? subtitle,
    required List<(String, String)> rows,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 10),
          ...rows.map((r) => _kvRow(r.$1, r.$2)),
        ],
      ),
    );
  }

  Widget _kvRow(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            k,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
      ],
    ),
  );
}
