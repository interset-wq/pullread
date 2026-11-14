import 'dart:io';

import 'package:flutter/material.dart';

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

  Future<void> _pickFor(int index) async {
    final entry = await showDialog<HomeRecentEntry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('选择${index == 0 ? '左' : '右'}栏文档'),
        content: SizedBox(
          width: 520,
          height: 420,
          child: ListView.builder(
            itemCount: widget.candidates.length,
            itemBuilder: (context, i) {
              final candidate = widget.candidates[i];
              final entry = _resolve(candidate);
              final disabled =
                  entry == null ||
                  _session.isOpenElsewhere(index, entry.key);
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
                onTap: disabled
                    ? null
                    : () => Navigator.pop(dialogContext, candidate),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
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
    final wide = width >= 900;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('多开阅读'),
        actions: [
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
