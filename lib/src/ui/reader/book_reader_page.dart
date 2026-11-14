import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../books/book.dart';
import '../../books/book_outline.dart';
import '../../git/repo_meta.dart';
import '../../notes/note_index.dart';
import '../../notes/note_scanner.dart';
import '../home_feed.dart';
import '../markdown_viewer.dart';

/// 电子书入口：书级目录、书根切换与继续阅读。
///
/// 章节正文仍由 [MarkdownViewerPage] / ReaderPane 渲染，本页只负责
/// 选书、选章与书级进度；章内位置由单篇进度恢复。
class BookReaderPage extends StatefulWidget {
  const BookReaderPage({
    required this.repoRoot,
    this.rootPath = '',
    this.files,
    super.key,
  });

  final String repoRoot;

  /// 当前书根（相对仓库根，'' = 仓库根）。
  final String rootPath;

  /// 仓库页已经扫描好的文件列表；为空时本页自行读缓存/后台扫描。
  final List<NoteFile>? files;

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  late String _rootPath = BookOutlineReader.normalizeRoot(widget.rootPath);
  List<NoteFile>? _files;
  BookOutline? _outline;
  List<BookRoot> _roots = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 书单切换器先用 .meta 缓存即时显示（若文件扫描较慢，用户已能看到候选）
    if (_roots.isEmpty) {
      final cached = BookOutlineReader.readCachedRoots(widget.repoRoot);
      if (cached.isNotEmpty && mounted) {
        setState(() => _roots = cached);
      }
    }
    setState(() => _loading = true);
    var files = widget.files;
    if (files == null) {
      files = NoteIndexCache.read(widget.repoRoot);
      if (files == null) {
        try {
          files = await scanNotesInBackground(widget.repoRoot);
          await NoteIndexCache.write(widget.repoRoot, files);
        } on Object {
          files = const [];
        }
      }
    }
    if (!mounted) return;
    final state = _resolve(files, _rootPath);
    BookOutlineReader.cacheRoots(widget.repoRoot, state.roots);
    if (!mounted) return;
    setState(() {
      _files = files;
      _outline = state.outline;
      _roots = state.roots;
      _loading = false;
    });
  }

  ({BookOutline? outline, List<BookRoot> roots}) _resolve(
    List<NoteFile> files,
    String rootPath,
  ) {
    final outline = BookOutlineReader.read(widget.repoRoot, rootPath, files);
    var roots = BookOutlineReader.discover(widget.repoRoot, files);
    if (outline != null &&
        !roots.any((root) => root.path == outline.rootPath)) {
      roots = [
        BookRoot(
          path: outline.rootPath,
          title: outline.title,
          source: outline.source,
          chapterCount: outline.chapters.length,
        ),
        ...roots,
      ];
    }
    return (outline: outline, roots: roots);
  }

  void _switchRoot(String path) {
    final files = _files;
    if (files == null) return;
    final state = _resolve(files, path);
    setState(() {
      _rootPath = path;
      _outline = state.outline;
      _roots = state.roots;
    });
  }

  NoteFile? _noteFor(String path) {
    for (final note in _files ?? const <NoteFile>[]) {
      if (note.relativePath.replaceAll('\\', '/') == path) return note;
    }
    return null;
  }

  Future<void> _openChapter(BookOutline outline, int index) async {
    if (index < 0 || index >= outline.chapters.length) return;
    final chapter = outline.chapters[index];
    final note = _noteFor(chapter.path);
    if (note == null || !File(note.absolutePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('章节文件不存在：${chapter.path}')),
      );
      // 缓存可能过期（pull 删文件等），后台重扫刷新书单来源
      unawaited(_rescanAfterMissingChapter());
      return;
    }
    RepoMeta.saveBookProgress(widget.repoRoot, outline.rootPath, chapter.path);
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MarkdownViewerPage(
          note: note,
          repoRoot: widget.repoRoot,
          book: outline,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _rescanAfterMissingChapter() async {
    try {
      final files = await scanNotesInBackground(widget.repoRoot);
      await NoteIndexCache.write(widget.repoRoot, files);
      if (!mounted) return;
      final state = _resolve(files, _rootPath);
      BookOutlineReader.cacheRoots(widget.repoRoot, state.roots);
      setState(() {
        _files = files;
        _outline = state.outline;
        _roots = state.roots;
      });
    } on Object {
      // 重扫失败保持现状，下一次打开会再触发
    }
  }

  int _continueIndex(BookOutline outline) {
    final saved = RepoMeta.readBookProgress(widget.repoRoot, outline.rootPath);
    final index = saved == null ? -1 : outline.indexOfPath(saved);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final outline = _outline;
    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        foregroundColor: tokens.title,
        scrolledUnderElevation: 3,
        title: Text(
          outline?.title ?? '电子书',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: tokens.title,
          ),
        ),
        actions: [
          if (_roots.length > 1)
            PopupMenuButton<String>(
              tooltip: '切换书根',
              icon: Icon(Icons.library_books_outlined, color: tokens.icon),
              onSelected: _switchRoot,
              itemBuilder: (_) => [
                for (final root in _roots)
                  PopupMenuItem(
                    value: root.path,
                    child: Row(
                      children: [
                        Icon(
                          root.path == _rootPath
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: root.path == _rootPath
                              ? tokens.green
                              : tokens.chevron,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            root.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${root.chapterCount} 章',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.meta,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : outline == null || outline.isEmpty
              ? _emptyState(tokens)
              : _bookView(tokens, outline),
    );
  }

  Widget _bookView(HomeTokens tokens, BookOutline outline) {
    final current = _continueIndex(outline);
    final currentChapter = outline.chapters[current];
    final progressPath = RepoMeta.readBookProgress(
      widget.repoRoot,
      outline.rootPath,
    );
    final hasProgress = progressPath != null &&
        outline.indexOfPath(progressPath) >= 0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tokens.greenTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.menu_book_outlined,
                          color: tokens.green,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outline.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: tokens.title,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_sourceLabel(outline.source)} · '
                              '${outline.chapters.length} 章',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.meta,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    hasProgress
                        ? '上次读到：${currentChapter.title}'
                        : '从第一章开始阅读',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openChapter(outline, current),
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.green,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 19),
                        label: Text(hasProgress ? '继续阅读' : '开始阅读'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _openChapter(outline, 0),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.secondary,
                          side: BorderSide(color: tokens.border),
                        ),
                        child: const Text('从第一章'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                '目录',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: tokens.section,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < outline.chapters.length; i++) ...[
                    _chapterRow(tokens, outline, i, progressPath),
                    if (i != outline.chapters.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: tokens.divider,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chapterRow(
    HomeTokens tokens,
    BookOutline outline,
    int index,
    String? progressPath,
  ) {
    final chapter = outline.chapters[index];
    final current = chapter.path == progressPath;
    return InkWell(
      onTap: () => _openChapter(outline, index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: EdgeInsets.fromLTRB(
          14 + chapter.depth * 16,
          9,
          12,
          9,
        ),
        decoration: current
            ? BoxDecoration(
                color: tokens.greenTint,
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 12,
                  color: current ? tokens.green : tokens.meta,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                chapter.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                  color: current ? tokens.green : tokens.secondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              current ? Icons.play_arrow_rounded : Icons.chevron_right,
              size: 19,
              color: current ? tokens.green : tokens.chevron,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(HomeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tokens.greenTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.menu_book_outlined,
                color: tokens.green,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '当前目录没有可读章节',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.title,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '放入 Markdown 文件，或添加 .pullread-book.json、'
              'SUMMARY.md、_sidebar.md 作为书单。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: tokens.meta,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sourceLabel(BookOutlineSource source) => switch (source) {
        BookOutlineSource.manifest => '显式书单',
        BookOutlineSource.summary => 'SUMMARY.md',
        BookOutlineSource.sidebar => '_sidebar.md',
        BookOutlineSource.inferred => '目录推断',
      };
}
