import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../git/repo_meta.dart';
import '../../local/local_folder_service.dart';
import '../../local/mirror_state.dart';
import '../../theme/app_prefs.dart';
import '../storage_page.dart';
import 'settings_components.dart';

class DataSettingsPage extends StatefulWidget {
  const DataSettingsPage({required this.prefs, super.key});

  final AppPrefs prefs;

  @override
  State<DataSettingsPage> createState() => _DataSettingsPageState();
}

class _DataSettingsPageState extends State<DataSettingsPage> {
  String _reposRoot = '';
  String _localRoot = '';
  int? _recentsCount;
  int? _starsCount;
  int? _pendingCount;
  int _conflictCount = 0;

  AppPrefs get _prefs => widget.prefs;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    var reposRoot = '';
    var localRoot = '';
    try {
      final docs = await getApplicationDocumentsDirectory();
      reposRoot = '${docs.path}${Platform.pathSeparator}repos';
      localRoot = '${docs.path}${Platform.pathSeparator}local';
    } on Object {
      reposRoot = '';
      localRoot = '';
    }
    var pendingCount = 0;
    var conflictCount = 0;
    try {
      final pending = await LocalFolderService.allPending();
      pendingCount = pending.length;
      conflictCount = pending.where((item) => item.$2.conflict).length;
    } on Object {
      pendingCount = 0;
      conflictCount = 0;
    }
    var counts = (recents: 0, stars: 0);
    if (reposRoot.isNotEmpty) {
      try {
        counts = await Isolate.run(
          () => _readHistoryCounts([reposRoot, localRoot]),
        );
      } on Object {
        counts = (recents: 0, stars: 0);
      }
    }
    if (!mounted) return;
    setState(() {
      _reposRoot = reposRoot;
      _localRoot = localRoot;
      _recentsCount = counts.recents;
      _starsCount = counts.stars;
      _pendingCount = pendingCount;
      _conflictCount = conflictCount;
    });
  }

  Future<void> _openPending() async {
    List<(LocalFolder, PendingEdit)> items;
    try {
      items = await LocalFolderService.allPending();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('读取待写回记录失败')));
      return;
    }
    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有待写回的修改')));
      await _loadCounts();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _PendingDialog(items: items),
    );
    await _loadCounts();
  }

  Future<void> _clearRecents() async {
    final roots = [
      _reposRoot,
      _localRoot,
    ].where((root) => root.isNotEmpty).toList();
    if (roots.isEmpty) return;
    final count = _recentsCount ?? 0;
    final ok = await confirmDestructiveAction(
      context,
      title: '清空阅读历史',
      message: '将删除最近阅读 $count 条记录，此操作不可撤销。',
    );
    if (!ok || !mounted) return;
    await Isolate.run(() {
      for (final root in roots) {
        RepoMeta.clearRecents(root);
      }
    });
    await _loadCounts();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已清空阅读历史')));
  }

  Future<void> _clearStars() async {
    final roots = [
      _reposRoot,
      _localRoot,
    ].where((root) => root.isNotEmpty).toList();
    if (roots.isEmpty) return;
    final count = _starsCount ?? 0;
    final ok = await confirmDestructiveAction(
      context,
      title: '清空收藏',
      message: '将删除所有来源的 $count 篇收藏文章，此操作不可撤销。',
    );
    if (!ok || !mounted) return;
    await Isolate.run(() {
      for (final root in roots) {
        RepoMeta.clearAllStars(root);
      }
    });
    await _loadCounts();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已清空收藏')));
  }

  Future<void> _clearSearchHistory() async {
    final count = _prefs.searchHistory.length;
    final ok = await confirmDestructiveAction(
      context,
      title: '清空搜索历史',
      message: '将删除 $count 条搜索历史，此操作不可撤销。',
    );
    if (!ok) return;
    await _prefs.clearSearchHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已清空搜索历史')));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _prefs,
      builder: (context, _) {
        final pending = _pendingCount;
        final recents = _recentsCount;
        final stars = _starsCount;
        final searchCount = _prefs.searchHistory.length;
        return SettingsSubpage(
          title: '存储与数据',
          children: [
            SettingsSection(
              title: '存储',
              children: [
                SettingsNavTile(
                  icon: Icons.storage_outlined,
                  title: '存储占用',
                  subtitle: '仓库、镜像、图片缓存与元数据',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StoragePage(),
                    ),
                  ),
                ),
                SettingsNavTile(
                  icon: _conflictCount > 0
                      ? Icons.error_outline
                      : Icons.cloud_done_outlined,
                  title: '未写回的修改',
                  subtitle: switch (pending) {
                    null => '检查中…',
                    0 => '没有待写回的修改',
                    _ when _conflictCount > 0 =>
                      '$_conflictCount 个冲突，$pending 个文件待写回',
                    _ => '$pending 个文件待写回原文件夹',
                  },
                  value: pending == null ? null : '$pending 个',
                  onTap: _openPending,
                ),
                SettingsNavTile(
                  icon: Icons.search_off_outlined,
                  title: '清空搜索历史',
                  subtitle: searchCount == 0 ? '暂无搜索历史' : '$searchCount 条搜索历史',
                  value: searchCount == 0 ? null : '$searchCount 条',
                  enabled: searchCount > 0,
                  onTap: _clearSearchHistory,
                ),
              ],
            ),
            SettingsSection(
              title: '危险操作',
              children: [
                SettingsNavTile(
                  icon: Icons.history_toggle_off,
                  title: '清空阅读历史',
                  subtitle: recents == null
                      ? '检查中…'
                      : recents == 0
                      ? '暂无记录'
                      : '最近阅读 $recents 条',
                  destructive: true,
                  enabled: recents != null && recents > 0,
                  onTap: _clearRecents,
                ),
                SettingsNavTile(
                  icon: Icons.star_outline,
                  title: '清空收藏',
                  subtitle: stars == null
                      ? '检查中…'
                      : stars == 0
                      ? '暂无收藏'
                      : '收藏 $stars 篇',
                  destructive: true,
                  enabled: stars != null && stars > 0,
                  onTap: _clearStars,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

({int recents, int stars}) _readHistoryCounts(List<String> roots) {
  var recents = 0;
  var stars = 0;
  for (final root in roots) {
    if (root.isEmpty) continue;
    if (!Directory(root).existsSync()) continue;
    recents += RepoMeta.readRecents(root).length;
    // 收藏按来源根 `.meta/*.json` 统计，本地镜像与仓库一视同仁。
    stars += RepoMeta.countStars(root);
  }
  return (recents: recents, stars: stars);
}

class _PendingDialog extends StatefulWidget {
  const _PendingDialog({required this.items});

  final List<(LocalFolder, PendingEdit)> items;

  @override
  State<_PendingDialog> createState() => _PendingDialogState();
}

class _PendingDialogState extends State<_PendingDialog> {
  late List<(LocalFolder, PendingEdit)> _items = widget.items;
  bool _busy = false;

  Future<void> _retry({required bool force}) async {
    if (_busy) return;
    setState(() => _busy = true);
    var ok = 0;
    var failed = 0;
    final folders = <String, LocalFolder>{
      for (final item in _items) item.$1.name: item.$1,
    };
    for (final folder in folders.values) {
      final result = await LocalFolderService.retryPending(
        folder,
        force: force,
      );
      ok += result.$1;
      failed += result.$2;
    }
    final remaining = await LocalFolderService.allPending();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _items = remaining;
    });
    final message = switch ((ok, failed)) {
      (0, 0) => '没有可写回的文件',
      (_, 0) => '已写回 $ok 个文件',
      (0, _) => '写回失败（$failed 个）',
      _ => '写回成功 $ok 个，失败 $failed 个',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('未写回的修改'),
      content: SizedBox(
        width: double.maxFinite,
        child: _items.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('全部已写回'),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final (folder, edit) = _items[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      edit.relativePath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      edit.conflict
                          ? '${folder.name} · 源文件已改动，直接写回会覆盖它'
                          : folder.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: edit.conflict
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        TextButton(
          onPressed: _busy || _items.isEmpty
              ? null
              : () => _retry(force: false),
          child: const Text('重试写回'),
        ),
        FilledButton(
          onPressed: _busy || _items.isEmpty ? null : () => _retry(force: true),
          child: const Text('以镜像为准覆盖'),
        ),
      ],
    );
  }
}
