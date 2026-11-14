import 'dart:io';

import 'package:flutter/material.dart';

import '../../books/user_books.dart';
import '../../notes/note_index.dart';
import '../../notes/note_scanner.dart';

/// 创建 / 编辑用户电子书：章节顺序由用户确定，保存在 `.meta`，不写回仓库。
///
/// 章节来源两种：
/// - 手动添加：从来源的全部 Markdown 文件里多选；
/// - 自动扫描：一键收集 `docs/`、`doc/` 等文档目录下的 Markdown（自然排序），
///   之后仍由用户拖动调整顺序、增删章节。
class BookEditorPage extends StatefulWidget {
  const BookEditorPage({
    required this.sources,
    this.initialSource,
    this.book,
    super.key,
  });

  /// 可选来源根目录（Git 仓库 + 本地镜像）。
  final List<Directory> sources;

  /// 编辑已有书单时固定的来源。
  final Directory? initialSource;

  /// 传入则为编辑模式；null 为新建。
  final UserBook? book;

  @override
  State<BookEditorPage> createState() => _BookEditorPageState();
}

class _BookEditorPageState extends State<BookEditorPage> {
  late Directory? _source = widget.initialSource ?? _firstSource();
  late final TextEditingController _titleController = TextEditingController(
    text: widget.book?.title ?? '',
  );

  /// 用户是否手动改过书名：未改过则跟随来源名自动填充
  late bool _titleTouched = widget.book != null;
  late String? _editId = widget.book?.id;
  late final List<UserChapter> _chapters = [...?widget.book?.chapters];
  List<NoteFile> _files = const [];
  bool _loadingFiles = false;

  Directory? _firstSource() =>
      widget.sources.isEmpty ? null : widget.sources.first;

  static String _sourceName(Directory source) =>
      source.path.split(RegExp(r'[\\/]')).last;

  bool get _canSave =>
      _source != null &&
      _titleController.text.trim().isNotEmpty &&
      _chapters.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.book == null && _source != null) {
      _titleController.text = _sourceName(_source!);
    }
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final source = _source;
    if (source == null) return;
    setState(() => _loadingFiles = true);
    final cached = NoteIndexCache.read(source.path);
    List<NoteFile> files;
    if (cached != null) {
      files = cached;
    } else {
      try {
        files = await scanNotesInBackground(source.path);
        await NoteIndexCache.write(source.path, files);
      } on Object {
        files = const [];
      }
    }
    if (!mounted) return;
    setState(() {
      _files = files;
      _loadingFiles = false;
    });
    // 自动扫描为主：新建书单且未添加章节时，直接填充 docs/doc 目录章节，
    // 用户只需按需调整（自动书名已同步填好）
    if (widget.book == null && _chapters.isEmpty) {
      final scanned = _scanDocDirs();
      if (scanned.isNotEmpty && mounted) {
        setState(() => _chapters.addAll(scanned));
      }
    }
  }

  /// 自动扫描文档目录：docs/、doc/ 下的 Markdown，自然排序。
  List<UserChapter> _scanDocDirs() {
    final chapters = <UserChapter>[];
    for (final file in _files) {
      final path = file.relativePath.replaceAll('\\', '/');
      final lower = path.toLowerCase();
      if (!(lower.startsWith('docs/') || lower.startsWith('doc/'))) continue;
      chapters.add(
        UserChapter(path: path, title: _titleFromFileName(file.fileName)),
      );
    }
    chapters.sort(
      (a, b) => compareNatural(a.path.toLowerCase(), b.path.toLowerCase()),
    );
    return chapters;
  }

  static String _titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    var name = dot > 0 ? fileName.substring(0, dot) : fileName;
    name = name.replaceFirst(RegExp(r'^\d+[._\-\s]+'), '');
    name = name.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return name.isEmpty ? fileName : name;
  }

  Future<void> _addChaptersManually() async {
    if (_files.isEmpty) return;
    final existing = _chapters.map((c) => c.path).toSet();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        final picked = <String>{};
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('添加章节'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, i) {
                  final file = _files[i];
                  final path = file.relativePath.replaceAll('\\', '/');
                  final value = !existing.contains(path);
                  return CheckboxListTile(
                    value: picked.contains(path),
                    onChanged: value
                        ? (checked) => setDialogState(() {
                              checked == true
                                  ? picked.add(path)
                                  : picked.remove(path);
                            })
                        : null,
                    dense: true,
                    title: Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, picked),
                child: const Text('添加'),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      for (final path in selected) {
        _chapters.add(
          UserChapter(path: path, title: _titleFromFileName(path)),
        );
      }
    });
  }

  /// 删除整本电子书：确认后从 `.meta` 移除并返回列表页。
  Future<void> _deleteBook() async {
    final source = _source;
    final id = _editId;
    if (source == null || id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除电子书'),
        content: const Text('只删除书单，不删除仓库里的任何文件。确定删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final books = [...UserBookStore.read(source.path)];
    books.removeWhere((book) => book.id == id);
    UserBookStore.save(source.path, books);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final source = _source;
    if (source == null || !_canSave) return;
    final books = [...UserBookStore.read(source.path)];
    final book = UserBook(
      id: _editId ??= DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      chapters: List.of(_chapters),
    );
    books.removeWhere((b) => b.id == book.id);
    books.add(book);
    UserBookStore.save(source.path, books);
    if (mounted) Navigator.pop(context, book);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.book != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? '编辑电子书' : '创建电子书'),
        actions: [
          if (editing)
            IconButton(
              tooltip: '删除电子书',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteBook,
            ),
          IconButton(
            tooltip: '保存',
            icon: const Icon(Icons.check),
            onPressed: _canSave ? _save : null,
          ),
        ],
      ),
      body: widget.sources.isEmpty
          ? const Center(child: Text('还没有可用的仓库或本地文件夹'))
          : _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '书名（默认取来源名，可修改）',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              _titleTouched = true;
              setState(() {});
            },
          ),
        ),
        if (widget.book == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<Directory>(
              initialValue: _source,
              decoration: const InputDecoration(
                labelText: '来源',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final source in widget.sources)
                  DropdownMenuItem(
                    value: source,
                    child: Text(
                      source.path.split(RegExp(r'[\\/]')).last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _source = value;
                  _files = const [];
                });
                // 未手动改过书名时跟随来源名，减少一次输入
                if (value != null && !_titleTouched) {
                  _titleController.text = _sourceName(value);
                }
                _loadFiles();
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loadingFiles || _files.isEmpty
                    ? null
                    : () => setState(() {
                          _chapters
                            ..clear()
                            ..addAll(_scanDocDirs());
                        }),
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('扫描 docs/doc 目录'),
              ),
              OutlinedButton.icon(
                onPressed: _loadingFiles || _files.isEmpty
                    ? null
                    : _addChaptersManually,
                icon: const Icon(Icons.playlist_add),
                label: const Text('手动添加章节'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _loadingFiles
                ? '正在读取文件列表…'
                : _files.isEmpty
                    ? '来源里没有 Markdown 文件'
                    : '共 ${_chapters.length} 章，长按拖动调整顺序',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            // 只通过默认拖拽柄拖动，列表本身保留滚动（整行拖拽会吃掉滑动）
            buildDefaultDragHandles: true,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _chapters.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final chapter = _chapters.removeAt(oldIndex);
                _chapters.insert(newIndex, chapter);
              });
            },
            itemBuilder: (context, i) {
              final chapter = _chapters[i];
              return ListTile(
                key: ValueKey('chapter-${chapter.path}-$i'),
                dense: true,
                title: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  chapter.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: '移除',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _chapters.removeAt(i)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
