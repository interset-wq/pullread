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

/// 章节来源：用户创建 > 显式清单 > SUMMARY.md > _sidebar.md > 自动推断。
enum BookOutlineSource { user, manifest, summary, sidebar, inferred }

/// 按章节 depth 层级计算编号（如 1、1.1、1.1.1），支持任意嵌套。
///
/// 深度回退时深层计数器复位：1.2 之后回到 1.2.1 而不是 1.2.2。
List<String> computeChapterNumbers(List<int> depths) {
  final counters = <int>[];
  final out = <String>[];
  for (final depth in depths) {
    final d = depth < 0 ? 0 : depth;
    while (counters.length <= d) {
      counters.add(0);
    }
    counters[d] += 1;
    counters.removeRange(d + 1, counters.length);
    out.add(counters.take(d + 1).join('.'));
  }
  return out;
}

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
