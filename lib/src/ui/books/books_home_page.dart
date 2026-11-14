import 'dart:io';

import 'package:flutter/material.dart';

import '../../books/user_books.dart';
import '../reader/book_reader_page.dart';
import 'book_editor_page.dart';

/// 电子书 tab：列出各来源的用户书单，进入阅读或编辑，并可新建。
class BooksHomePage extends StatefulWidget {
  const BooksHomePage({required this.sources, super.key});

  final List<Directory> sources;

  @override
  State<BooksHomePage> createState() => _BooksHomePageState();
}

class _BooksHomePageState extends State<BooksHomePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final books = <(Directory, UserBook)>[
      for (final source in widget.sources)
        for (final book in UserBookStore.read(source.path)) (source, book),
    ];
    if (widget.sources.isEmpty) {
      return const Center(child: Text('还没有可用的仓库或本地文件夹'));
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(),
        tooltip: '创建电子书',
        child: const Icon(Icons.add),
      ),
      body: books.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 44,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('还没有电子书'),
                  const SizedBox(height: 4),
                  Text(
                    '手动创建，或扫描 docs/doc 目录生成章节后调整顺序',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: books.length,
              itemBuilder: (context, i) {
                final (source, book) = books[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${book.chapters.length} 章 · '
                      '${source.path.split(RegExp(r'[\\/]')).last}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: '编辑',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(source, book),
                    ),
                    onTap: () => _open(source, book),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _create() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookEditorPage(sources: widget.sources),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _open(Directory source, UserBook book) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookReaderPage(
          repoRoot: source.path,
          rootPath: book.rootPath,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(Directory source, UserBook book) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookEditorPage(
          sources: widget.sources,
          initialSource: source,
          book: book,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}
