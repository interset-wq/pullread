import 'dart:io';

import 'package:flutter/material.dart';

import '../../books/book.dart';
import '../../books/book_outline.dart';
import '../../notes/note_index.dart';
import '../../notes/note_scanner.dart';
import '../home_feed.dart';
import 'reader_pane.dart';
import 'reader_session.dart';

/// 多开阅读：平板/桌面左右并排，手机用底部分段切换。
///
/// 两栏各自拥有独立的 [Navigator] 与 [ReaderPane] 状态，查找、进度、菜单
/// 互不影响；入口仅从最近阅读选择，不跨页面共享滚动状态。
class SplitReaderPage extends StatefulWidget {
  const SplitReaderPage({required this.candidates, super.key});

  final List<HomeRecentEntry> candidates;

  @override
  State<SplitReaderPage> createState() => _SplitReaderPageState();
}

class _SplitReaderPageState extends State<SplitReaderPage> {
  final ReaderSession _session = ReaderSession();

  /// 600–900dp 的手动分屏开关：null/false 用底部切换器，true 切为左右分屏。
  /// ≥900dp 始终分屏，<600dp 不提供开关。
  bool _splitOverride = false;

  Future<void> _pickFor(int index) async {
    final entry = await showDialog<HomeRecentEntry>(
      context: context,
      builder: (dialogContext) => _PanePickerDialog(
        candidates: widget.candidates,
        paneIndex: index,
        isOpenElsewhere: (key) => _session.isOpenElsewhere(index, key),
      ),
    );
    if (!mounted || entry == null) return;
    final resolved = _resolve(entry);
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件已不存在')),
      );
      return;
    }
    setState(() => _session.setPane(index, resolved));
  }

  ReaderEntry? _resolve(HomeRecentEntry entry) {
    final file = File(
      '${entry.source.path}${Platform.pathSeparator}'
      '${entry.relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!file.existsSync()) return null;
    final stat = file.statSync();
    return ReaderEntry(
      repoRoot: entry.source.path,
      note: NoteFile(
        relativePath: entry.relativePath,
        absolutePath: file.path,
        modified: stat.modified,
        sizeBytes: stat.size,
      ),
    );
  }

  void _closePane(int index) {
    setState(() => _session.clearPane(index));
  }

  Widget _buildPane(int index) {
    final entry = _session.panes[index];
    if (entry == null) {
      return _EmptyPane(
        label: index == 0 ? '左栏' : '右栏',
        onPick: () => _pickFor(index),
      );
    }
    return Navigator(
      key: ValueKey('pane-$index-${entry.key}'),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => ReaderPane(
          note: entry.note,
          repoRoot: entry.repoRoot,
          embedded: true,
          leading: IconButton(
            tooltip: '关闭此栏',
            icon: const Icon(Icons.close),
            onPressed: () => _closePane(index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900 || (width >= 600 && _splitOverride);
    final manualToggle = width >= 600 && width < 900;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('多开阅读'),
        actions: [
          if (manualToggle)
            IconButton(
              tooltip: _splitOverride ? '收起分屏' : '切换分屏',
              icon: Icon(
                _splitOverride
                    ? Icons.splitscreen_outlined
                    : Icons.splitscreen,
              ),
              onPressed:
                  () => setState(() => _splitOverride = !_splitOverride),
            ),
          IconButton(
            tooltip: '选择文档',
            icon: const Icon(Icons.add),
            onPressed: () => _pickFor(_session.activePane),
          ),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildPane(0)),
                const VerticalDivider(width: 1),
                Expanded(child: _buildPane(1)),
              ],
            )
          : IndexedStack(
              index: _session.activePane,
              children: [_buildPane(0), _buildPane(1)],
            ),
      bottomNavigationBar: wide
          ? null
          : Material(
              color: theme.colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('左栏')),
                      ButtonSegment(value: 1, label: Text('右栏')),
                    ],
                    selected: {_session.activePane},
                    onSelectionChanged: (selection) {
                      setState(() => _session.select(selection.first));
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.label, required this.onPick});

  final String label;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            '$label还没有文档',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onPick,
            child: const Text('选择文档'),
          ),
        ],
      ),
    );
  }
}

/// 栏内容选择器：「最近」来自跨来源最近阅读，「书单」从 `.meta` 缓存的
/// 书根展开章节列表；两者都返回 [HomeRecentEntry] 供外层解析打开。
class _PanePickerDialog extends StatefulWidget {
  const _PanePickerDialog({
    required this.candidates,
    required this.paneIndex,
    required this.isOpenElsewhere,
  });

  final List<HomeRecentEntry> candidates;
  final int paneIndex;
  final bool Function(String key) isOpenElsewhere;

  @override
  State<_PanePickerDialog> createState() => _PanePickerDialogState();
}

class _PanePickerDialogState extends State<_PanePickerDialog> {
  // 书单模式状态：选中的来源根、展开的书根、每来源的章节大纲缓存
  int _mode = 0; // 0 = 最近，1 = 书单
  String? _bookSource;
  String? _expandedRoot;
  final Map<String, BookOutline?> _outlineCache = {};

  List<String> get _sources => <String>{
    for (final entry in widget.candidates) entry.source.path,
  }.toList()..sort(compareNatural);

  List<BookRoot> _rootsFor(String source) =>
      BookOutlineReader.readCachedRoots(source);

  /// 正在后台扫描的来源（缓存缺失时补一次扫描，完成后刷新章节列表）。
  final Set<String> _scanningSources = {};

  BookOutline? _outlineFor(String source, BookRoot root) {
    final key = '$source|${root.path}';
    if (_outlineCache.containsKey(key)) return _outlineCache[key];
    final files = NoteIndexCache.read(source);
    if (files == null) {
      // 缓存缺失：后台补扫一次，写回缓存后刷新章节列表
      _scanSourceInBackground(source);
      return null;
    }
    final outline = BookOutlineReader.read(source, root.path, files);
    _outlineCache[key] = outline;
    return outline;
  }

  Future<void> _scanSourceInBackground(String source) async {
    if (!_scanningSources.add(source)) return;
    try {
      final files = await scanNotesInBackground(source);
      await NoteIndexCache.write(source, files);
      _outlineCache.clear();
      if (mounted) setState(() {});
    } on Object {
      // 扫描失败保持「章节缓存不可用」提示
    } finally {
      _scanningSources.remove(source);
    }
  }

  void _openChapter(String source, BookChapter chapter) {
    final key = '$source|${chapter.path}';
    if (widget.isOpenElsewhere(key)) return;
    Navigator.pop(
      context,
      HomeRecentEntry(
        source: Directory(source),
        relativePath: chapter.path,
        isLocal: false,
      ),
    );
  }

  Widget _buildRecentsList(BuildContext context) {
    return ListView.builder(
      itemCount: widget.candidates.length,
      itemBuilder: (context, i) {
        final candidate = widget.candidates[i];
        final key = '${candidate.source.path}|${candidate.relativePath}';
        final disabled = widget.isOpenElsewhere(key);
        return ListTile(
          enabled: !disabled,
          leading: Icon(
            candidate.isLocal
                ? Icons.folder_outlined
                : Icons.folder_copy_outlined,
          ),
          title: Text(
            candidate.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            candidate.source.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: disabled ? null : () => Navigator.pop(context, candidate),
        );
      },
    );
  }

  Widget _buildBooksList(BuildContext context) {
    final sources = _sources;
    if (_bookSource == null || !sources.contains(_bookSource)) {
      _bookSource = sources.isEmpty ? null : sources.first;
    }
    final source = _bookSource;
    if (source == null) {
      return const Center(child: Text('暂无可用来源'));
    }
    final roots = _rootsFor(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sources.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButtonFormField<String>(
              initialValue: source,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: '来源',
              ),
              items: [
                for (final s in sources)
                  DropdownMenuItem(value: s, child: Text(_baseName(s))),
              ],
              onChanged: (value) => setState(() {
                _bookSource = value;
                _expandedRoot = null;
              }),
            ),
          ),
        Expanded(
          child: roots.isEmpty
              ? const Center(child: Text('暂无书单缓存，先在仓库页打开一次电子书模式'))
              : ListView.builder(
                  itemCount: roots.length,
                  itemBuilder: (context, i) {
                    final root = roots[i];
                    final expanded = _expandedRoot == root.path;
                    final outline = expanded
                        ? _outlineFor(source, root)
                        : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: Icon(
                            expanded
                                ? Icons.folder_open_outlined
                                : Icons.menu_book_outlined,
                          ),
                          title: Text(
                            root.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('${root.chapterCount} 章'),
                          onTap: () => setState(() {
                            _expandedRoot = expanded ? null : root.path;
                          }),
                        ),
                        if (expanded && outline == null)
                          const ListTile(
                            enabled: false,
                            title: Text('章节缓存不可用'),
                          ),
                        if (expanded && outline != null)
                          for (final chapter in outline.chapters)
                            ListTile(
                              contentPadding:
                                  EdgeInsets.only(left: 24 + chapter.depth * 20),
                              dense: true,
                              enabled: !widget.isOpenElsewhere(
                                '$source|${chapter.path}',
                              ),
                              title: Text(
                                chapter.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _openChapter(source, chapter),
                            ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _baseName(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    return name.isEmpty ? path : name;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('选择${widget.paneIndex == 0 ? '左' : '右'}栏文档'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('最近')),
                ButtonSegment(value: 1, label: Text('书单')),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _mode == 0
                  ? _buildRecentsList(context)
                  : _buildBooksList(context),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
