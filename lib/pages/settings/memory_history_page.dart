// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 记忆历史页
//
// 展示今天的对话记忆列表，支持搜索过往记忆
// 数据来源：后端 /memory/today + /memory/search
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config.dart';
import '../../core/auth/client_auth.dart';
import '../../core/theme/app_theme.dart';

final _memoryDio = Dio(
  BaseOptions(
    baseUrl: BackendConfig.instance.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
)..interceptors.add(SigningInterceptor());

class MemoryHistoryPage extends ConsumerStatefulWidget {
  const MemoryHistoryPage({super.key});

  @override
  ConsumerState<MemoryHistoryPage> createState() => _MemoryHistoryPageState();
}

class _MemoryHistoryPageState extends ConsumerState<MemoryHistoryPage> {
  List<MemoryItem> _memories = [];
  bool _loading = true;
  String? _error;
  bool _isSearchMode = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodayMemories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayMemories() async {
    // 跟随设置页修改的后端地址（否则换地址后记忆页仍打旧地址）
    _memoryDio.options.baseUrl = BackendConfig.instance.baseUrl;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _memoryDio.get('/memory/today');
      final data = resp.data as Map<String, dynamic>;
      final List memories = data['memories'] ?? [];
      setState(() {
        _memories = memories.map((m) => MemoryItem.fromJson(m)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    // 跟随设置页修改的后端地址
    _memoryDio.options.baseUrl = BackendConfig.instance.baseUrl;
    if (query.trim().isEmpty) {
      _loadTodayMemories();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _isSearchMode = true;
    });
    try {
      final resp = await _memoryDio.get(
        '/memory/search',
        queryParameters: {'q': query, 'limit': 20},
      );
      final data = resp.data as Map<String, dynamic>;
      final List memories = data['memories'] ?? [];
      setState(() {
        _memories = memories.map((m) => MemoryItem.fromJson(m)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _exitSearchMode() {
    _searchController.clear();
    setState(() {
      _isSearchMode = false;
    });
    _loadTodayMemories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        backgroundColor: AppTheme.paper,
        foregroundColor: AppTheme.softText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: _isSearchMode
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: AppTheme.softText),
                decoration: InputDecoration(
                  hintText: '搜索记忆...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                ),
                onSubmitted: _search,
              )
            : const Text('对话记忆 🌿'),
        actions: [
          if (_isSearchMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSearchMode,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() {
                _isSearchMode = true;
              }),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.bamboo),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('加载失败', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadTodayMemories, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_memories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.bamboo.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco,
                size: 48,
                color: AppTheme.bambooDeep,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isSearchMode ? '没有找到相关记忆' : '今天还没有对话记忆',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSearchMode ? '换个关键词试试' : '和竹笌聊聊，记忆会自动保存',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppTheme.bamboo,
      onRefresh: _isSearchMode
          ? () => _search(_searchController.text)
          : _loadTodayMemories,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _memories.length,
        itemBuilder: (context, index) => _MemoryCard(item: _memories[index]),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryItem item;

  const _MemoryCard({required this.item});

  bool get _isUser {
    if (item.category == 'user_memory') return true;
    if (item.category == 'chat_memory') {
      return item.content.startsWith('用户：');
    }
    return false;
  }

  String _stripPrefix(String content) {
    return content.replaceFirst(RegExp(r'^(用户|竹笌|User|AI)[:：]\s*'), '');
  }

  String _formatTime(String createdAt) {
    if (createdAt.length < 16) return createdAt;
    return createdAt.substring(11, 16); // HH:mm
  }

  @override
  Widget build(BuildContext context) {
    final isUser = _isUser;
    final roleColor = isUser ? AppTheme.warmYellow : AppTheme.bamboo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isUser ? '👤' : '🌱', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                isUser ? '你' : '竹笌',
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(item.createdAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _stripPrefix(item.content),
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF333333),
            ),
          ),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.tags.take(4).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(color: roleColor, fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class MemoryItem {
  final int id;
  final String content;
  final String category;
  final List<String> tags;
  final String createdAt;

  MemoryItem({
    required this.id,
    required this.content,
    required this.category,
    required this.tags,
    required this.createdAt,
  });

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      category: json['category'] ?? 'chat_memory',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      createdAt: json['created_at'] ?? '',
    );
  }
}
