// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 音乐库页（PetLibraryPage）
//
// 位于：pages/pet/pet_library_page.dart
// 路由：/pet/library
//
// 功能：
//   Tab 1：歌词库 —— 列表 / 创建 / 查看 / 删除
//   Tab 2：歌曲库 —— 列表 / 播放 / 收藏 / 删除
//   Tab 3：生成历史 —— 音乐生成任务记录
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/backend_service.dart';
import '../../widgets/app_icon.dart';

class PetLibraryPage extends StatefulWidget {
  const PetLibraryPage({super.key});

  @override
  State<PetLibraryPage> createState() => _PetLibraryPageState();
}

class _PetLibraryPageState extends State<PetLibraryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _lyrics = [];
  List<Map<String, dynamic>> _songs = [];
  bool _loadingLyrics = true;
  bool _loadingSongs = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLyrics();
    _loadSongs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    setState(() => _loadingLyrics = true);
    final items = await BackendService.instance.listLyrics();
    setState(() {
      _lyrics = items;
      _loadingLyrics = false;
    });
  }

  Future<void> _loadSongs() async {
    setState(() => _loadingSongs = true);
    final items = await BackendService.instance.listSongs();
    setState(() {
      _songs = items;
      _loadingSongs = false;
    });
  }

  Future<void> _showCreateLyricsDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('新建歌词', style: TextStyle(color: AppTheme.fg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '标题', hintText: '给这首歌起个名字'),
            ),
            const SizedBox(height: AppTheme.space3),
            TextField(
              controller: contentController,
              maxLines: 6,
              decoration: const InputDecoration(labelText: '歌词内容', hintText: '写下你的灵感...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) return;
              await BackendService.instance.createLyrics(
                title: titleController.text.trim(),
                content: contentController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadLyrics();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    titleController.dispose();
    contentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: const Text('音乐库', style: TextStyle(color: AppTheme.fg, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const AppIcon(name: AppIconName.arrowLeft, color: AppTheme.fg),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.accentDeep,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.accent,
          tabs: const [
            Tab(text: '歌词'),
            Tab(text: '歌曲'),
            Tab(text: '历史'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLyricsTab(),
          _buildSongsTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: AppTheme.accent,
              onPressed: _showCreateLyricsDialog,
              child: const AppIcon(name: AppIconName.plus, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildLyricsTab() {
    if (_loadingLyrics) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_lyrics.isEmpty) {
      return _buildEmptyState('还没有歌词', '点击右下角按钮创建第一首歌词', AppIconName.fileText);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space4),
      itemCount: _lyrics.length,
      itemBuilder: (ctx, i) {
        final item = _lyrics[i];
        return Card(
          color: AppTheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(color: AppTheme.border.withValues(alpha: 0.5), width: 0.5),
          ),
          child: ListTile(
            leading: const AppIcon(name: AppIconName.fileText, color: AppTheme.accent),
            title: Text(item['title'] ?? '未命名', style: const TextStyle(color: AppTheme.fg, fontWeight: FontWeight.w500)),
            subtitle: Text(
              (item['content'] ?? '').toString().split('\n').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted),
            ),
            trailing: IconButton(
              icon: const AppIcon(name: AppIconName.trash, size: AppIconSize.xs, color: AppTheme.danger),
              onPressed: () async {
                await BackendService.instance.deleteLyrics(item['id']);
                _loadLyrics();
              },
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: Text(item['title'] ?? '未命名', style: const TextStyle(color: AppTheme.fg)),
                  content: SingleChildScrollView(
                    child: Text(item['content'] ?? '', style: TextStyle(color: AppTheme.fg2, height: 1.6)),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSongsTab() {
    if (_loadingSongs) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_songs.isEmpty) {
      return _buildEmptyState('还没有歌曲', '去音乐狗子主页生成第一首歌', AppIconName.music);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.space4),
      itemCount: _songs.length,
      itemBuilder: (ctx, i) {
        final item = _songs[i];
        return Card(
          color: AppTheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(color: AppTheme.border.withValues(alpha: 0.5), width: 0.5),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.emberSoft, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              child: const Center(child: AppIcon(name: AppIconName.music, size: AppIconSize.xs, color: AppTheme.ember)),
            ),
            title: Text(item['title'] ?? '未命名', style: const TextStyle(color: AppTheme.fg, fontWeight: FontWeight.w500)),
            subtitle: Text(
              '播放 ${item['play_count'] ?? 0} 次',
              style: TextStyle(fontSize: AppTheme.textXs, color: AppTheme.muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: AppIcon(
                    name: (item['is_favorite'] ?? false) ? AppIconName.heartFilled : AppIconName.heart,
                    size: AppIconSize.xs,
                    color: (item['is_favorite'] ?? false) ? AppTheme.danger : AppTheme.muted,
                  ),
                  onPressed: () async {
                    await BackendService.instance.toggleSongFavorite(item['id']);
                    _loadSongs();
                  },
                ),
                IconButton(
                  icon: const AppIcon(name: AppIconName.trash, size: AppIconSize.xs, color: AppTheme.danger),
                  onPressed: () async {
                    await BackendService.instance.deleteSong(item['id']);
                    _loadSongs();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return Center(
      child: _buildEmptyState('生成历史', '音乐生成任务记录将显示在这里', AppIconName.history),
    );
  }

  Widget _buildEmptyState(String title, String desc, AppIconName icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppTheme.surfaceSunken, shape: BoxShape.circle),
            child: Center(child: AppIcon(name: icon, size: AppIconSize.md, color: AppTheme.muted)),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(title, style: TextStyle(fontSize: AppTheme.textMd, color: AppTheme.fg2, fontWeight: FontWeight.w500)),
          const SizedBox(height: AppTheme.space1),
          Text(desc, style: TextStyle(fontSize: AppTheme.textSm, color: AppTheme.muted)),
        ],
      ),
    );
  }
}
