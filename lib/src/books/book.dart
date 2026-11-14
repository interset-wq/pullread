/// 电子书章节：路径相对仓库根，统一使用 `/`。
class BookChapter {
  const BookChapter({
    required this.title,
    required this.path,
    this.depth = 0,
  });

  final String title;
  final String path;
  final int depth;

  @override
  bool operator ==(Object other) =>
      other is BookChapter &&
      other.title == title &&
      other.path == path &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(title, path, depth);

  @override
  String toString() => 'BookChapter($path, depth: $depth)';
}

/// 章节来源：显式清单 > SUMMARY.md > _sidebar.md > 自动推断。
enum BookOutlineSource { manifest, summary, sidebar, inferred }

/// 一本书的章节大纲。
class BookOutline {
  const BookOutline({
    required this.rootPath,
    required this.title,
    required this.chapters,
    required this.source,
  });

  /// 书根相对仓库根的目录；根目录为 `''`。
  final String rootPath;
  final String title;
  final List<BookChapter> chapters;
  final BookOutlineSource source;

  bool get isEmpty => chapters.isEmpty;

  int indexOfPath(String path) =>
      chapters.indexWhere((chapter) => chapter.path == path);
}

/// 可切换的书根候选。
class BookRoot {
  const BookRoot({
    required this.path,
    required this.title,
    required this.source,
    required this.chapterCount,
  });

  final String path;
  final String title;
  final BookOutlineSource source;
  final int chapterCount;
}
