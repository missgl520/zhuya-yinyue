// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 法律文档页（LegalPage）
//
// 从后端 /legal/{type} 拉取隐私政策 / 用户协议并展示。
// 该接口为公开路径（免签名），便于未登录用户查看。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/theme/app_theme.dart';

class LegalPage extends StatefulWidget {
  final String type; // 'privacy' | 'terms'

  const LegalPage({super.key, required this.type});

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  String _text = '';
  bool _loading = true;

  String get _title => widget.type == 'terms' ? '用户协议' : '隐私政策';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final base = BackendConfig.instance.baseUrl;
      final resp = await http.get(Uri.parse('$base/legal/${widget.type}'));
      if (mounted) {
        setState(() {
          _text = resp.statusCode == 200
              ? resp.body
              : '加载失败（${resp.statusCode}）';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _text = '加载失败：$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.paper,
        foregroundColor: AppTheme.softText,
        elevation: 0,
        title: Text(_title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: _buildContent(),
              ),
            ),
    );
  }

  /// 轻量文本渲染：识别 # / ## 标题层级，其余为段落，提升长文阅读舒适度。
  Widget _buildContent() {
    final lines = _text.split('\n');
    final widgets = <Widget>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(
              line.substring(3),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.softText,
              ),
            ),
          ),
        );
      } else if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              line.substring(2),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.bambooDeep,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SelectableText(
              line,
              style: const TextStyle(
                fontSize: 15,
                height: 1.75,
                color: AppTheme.softText,
              ),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
