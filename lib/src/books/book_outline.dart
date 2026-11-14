import 'dart:convert';
import 'dart:io';

import '../git/repo_meta.dart';
import '../notes/note_scanner.dart';
import 'book.dart';

/// 书单发现与解析：显式清单优先，其次 SUMMARY.md / _sidebar.md，
/// 最后按目录里的 Markdown 文件自动推断。
class BookOutlineReader {
  static const manifestFileName = '.pullread-book.json';
  static const summaryFileName = 'SUMMARY.md';
  static const sidebarFileName = '_sidebar.md';

  /// 读取指定书根的大纲；没有任何章节时返回 null。
  ///
  /// [files] 来自 [NoteIndexCache]，避免在 UI 线程递归扫描磁盘。
  static BookOutline? read(
    String repoRoot,
    String rootPath,
    List<NoteFile> files,
  ) {
    final root = normalizeRoot(rootPath);
    final manifest = _readFile(repoRoot, root, manifestFileName);
    if (manifest != null) {
      final outline = parseManifest(
        manifest,
        rootPath: root,
        titleFallback: _fallbackTitle(repoRoot, root),
      );
      if (outline != null) return outline;
    }

    final summary = _readFile(repoRoot, root, summaryFileName);
    if (summary != null) {
      final chapters = parseOutlineMarkdown(summary, rootPath: root);
      if (chapters.isNotEmpty) {
        return BookOutline(
          rootPath: root,
          title: _headingTitle(summary) ?? _fallbackTitle(repoRoot, root),
          chapters: chapters,
          source: BookOutlineSource.summary,
        );
      }
    }

    final sidebar = _readFile(repoRoot, root, sidebarFileName);
    if (sidebar != null) {
      final chapters = parseOutlineMarkdown(sidebar, rootPath: root);
      if (chapters.isNotEmpty) {
        return BookOutline(
          rootPath: root,
          title: _headingTitle(sidebar) ?? _fallbackTitle(repoRoot, root),
          chapters: chapters,
          source: BookOutlineSource.sidebar,
        );
      }
    }

    final inferred = infer(repoRoot, root, files);
    return inferred.isEmpty ? null : inferred;
  }

  /// 解析 `.pullread-book.json`。支持两种结构：
  /// `{"title": "...", "chapters": [...]}` 或直接给出章节数组。
  static BookOutline? parseManifest(
    String text, {
    required String rootPath,
    required String titleFallback,
  }) {
    Object? raw;
    try {
      raw = jsonDecode(text.replaceFirst('\ufeff', ''));
    } on FormatException {
      return null;
    }
    final root = normalizeRoot(rootPath);
    String title = titleFallback;
    Object? chapterList;
    if (raw is List) {
      chapterList = raw;
    } else if (raw is Map) {
      final t = raw['title'];
      if (t is String && t.trim().isNotEmpty) title = t.trim();
      chapterList = raw['chapters'] ?? raw['items'];
    }
    if (chapterList is! List) return null;
    final chapters = <BookChapter>[];
    _flattenManifest(
      chapterList,
      rootPath: root,
      depth: 0,
      out: chapters,
      seen: <String>{},
    );
    if (chapters.isEmpty) return null;
    return BookOutline(
      rootPath: root,
      title: title,
      chapters: chapters,
      source: BookOutlineSource.manifest,
    );
  }

  /// 解析 mdBook `SUMMARY.md` / docsify `_sidebar.md` 的列表链接。
  static List<BookChapter> parseOutlineMarkdown(
    String text, {
    required String rootPath,
  }) {
    final raw = <({int indent, String title, String href})>[];
    final pattern = RegExp(
      r'^(\s*)(?:[-*+]|\d+[.)])\s+\[(.+?)\]\(\s*([^)\s]+)(?:\s+"[^"]*")?\s*\)',
    );
    for (final line in const LineSplitter().convert(text)) {
      final match = pattern.firstMatch(line.replaceFirst('\ufeff', ''));
      if (match == null) continue;
      raw.add((
        indent: _indentWidth(match.group(1) ?? ''),
        title: _cleanTitle(match.group(2) ?? ''),
        href: match.group(3) ?? '',
      ));
    }
    if (raw.isEmpty) return const [];

    final levels = raw.map((e) => e.indent).toSet().toList()..sort();
    final chapters = <BookChapter>[];
    final seen = <String>{};
    for (final entry in raw) {
      final path = normalizeChapterPath(entry.href, basePath: rootPath);
      if (path == null || !seen.add(path)) continue;
      final depth = levels.indexOf(entry.indent);
      chapters.add(
        BookChapter(
          title: entry.title.isEmpty
              ? _fileNameTitle(path.split('/').last)
              : entry.title,
          path: path,
          depth: depth < 0 ? 0 : depth,
        ),
      );
    }
    return chapters;
  }

  /// 从文件列表推断书单：按相对路径自然排序，目录层级映射为缩进。
  static BookOutline infer(
    String repoRoot,
    String rootPath,
    List<NoteFile> files,
  ) {
    final root = normalizeRoot(rootPath);
    final prefix = root.isEmpty ? '' : '$root/';
    final docs = <NoteFile>[];
    for (final file in files) {
      final path = file.relativePath.replaceAll('\\', '/');
      if (!path.startsWith(prefix)) continue;
      if (!isBookDocument(path)) continue;
      final name = path.split('/').last;
      if (name == manifestFileName ||
          name == summaryFileName ||
          name == sidebarFileName) {
        continue;
      }
      docs.add(file);
    }
    docs.sort((a, b) => compareNatural(a.relativePath, b.relativePath));
    final chapters = <BookChapter>[];
    for (final file in docs) {
      final path = file.relativePath.replaceAll('\\', '/');
      final inside = root.isEmpty ? path : path.substring(prefix.length);
      final depth = inside.split('/').length - 1;
      chapters.add(
        BookChapter(
          title: _fileNameTitle(inside.split('/').last),
          path: path,
          depth: depth,
        ),
      );
    }
    return BookOutline(
      rootPath: root,
      title: _fallbackTitle(repoRoot, root),
      chapters: chapters,
      source: BookOutlineSource.inferred,
    );
  }

  /// 发现所有可切换的书根（含仓库根）。
  static List<BookRoot> discover(
    String repoRoot,
    List<NoteFile> files,
  ) {
    final candidates = <String>{''};
    for (final file in files) {
      final path = file.relativePath.replaceAll('\\', '/');
      final name = path.split('/').last;
      if (name != manifestFileName &&
          name != summaryFileName &&
          name != sidebarFileName) {
        continue;
      }
      final slash = path.lastIndexOf('/');
      candidates.add(slash <= 0 ? '' : path.substring(0, slash));
    }
    final roots = <BookRoot>[];
    for (final root in candidates) {
      final outline = read(repoRoot, root, files);
      if (outline == null || outline.isEmpty) continue;
      roots.add(
        BookRoot(
          path: outline.rootPath,
          title: outline.title,
          source: outline.source,
          chapterCount: outline.chapters.length,
        ),
      );
    }
    roots.sort((a, b) {
      final bySource = a.source.index.compareTo(b.source.index);
      if (bySource != 0) return bySource;
      final byDepth = a.path.split('/').length.compareTo(
            b.path.split('/').length,
          );
      if (byDepth != 0) return byDepth;
      return compareNatural(a.path, b.path);
    });
    return roots;
  }

  /// 读取 `.meta` 里缓存的书根列表；无缓存返回空列表。
  /// 仅作打开电子书页时的即时初值，真实发现结果随后重算覆盖。
  static List<BookRoot> readCachedRoots(String repoRoot) {
    final cached = RepoMeta.readBookRootsCache(repoRoot);
    if (cached == null) return const [];
    final roots = <BookRoot>[];
    for (final entry in cached) {
      final path = entry['path'];
      final sourceIndex = entry['source'];
      if (path is! String || sourceIndex is! int) continue;
      if (sourceIndex < 0 || sourceIndex >= BookOutlineSource.values.length) {
        continue;
      }
      roots.add(
        BookRoot(
          path: path,
          title: entry['title'] is String ? entry['title'] as String : path,
          source: BookOutlineSource.values[sourceIndex],
          chapterCount:
              entry['chapterCount'] is int ? entry['chapterCount'] as int : 0,
        ),
      );
    }
    return roots;
  }

  /// 把发现结果写回 `.meta` 书单缓存；写失败不影响功能。
  static void cacheRoots(String repoRoot, List<BookRoot> roots) {
    try {
      RepoMeta.saveBookRootsCache(
        repoRoot,
        [
          for (final root in roots)
            {
              'path': root.path,
              'title': root.title,
              'source': root.source.index,
              'chapterCount': root.chapterCount,
            },
        ],
      );
    } on Object {
      // 缓存仅用于展示加速
    }
  }

  static bool isBookDocument(String path) {
    final lower = path.toLowerCase();
    for (final ext in NoteScanner.mdExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  /// 把大纲里的链接规范成仓库根相对路径；外部链接/越界/非文档返回 null。
  static String? normalizeChapterPath(
    String href, {
    required String basePath,
  }) {
    var raw = href.trim();
    if (raw.isEmpty || raw.startsWith('#')) return null;
    if (raw.startsWith('<') && raw.endsWith('>')) {
      raw = raw.substring(1, raw.length - 1).trim();
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.hasScheme) return null;
    raw = raw.split('#').first.split('?').first;
    if (raw.isEmpty) return null;
    try {
      raw = Uri.decodeFull(raw);
    } on ArgumentError {
      // 保持原文
    }
    raw = raw.replaceAll('\\', '/');
    final segments = <String>[];
    if (raw.startsWith('/')) {
      // 以仓库根为基准
    } else {
      final base = normalizeRoot(basePath);
      if (base.isNotEmpty) segments.addAll(base.split('/'));
    }
    for (final part in raw.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (segments.isEmpty) return null;
        segments.removeLast();
        continue;
      }
      segments.add(part);
    }
    if (segments.isEmpty) return null;
    final path = segments.join('/');
    return isBookDocument(path) ? path : null;
  }

  static String normalizeRoot(String path) {
    final parts = path
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty && part != '.');
    return parts.join('/');
  }

  static void _flattenManifest(
    List<dynamic> items, {
    required String rootPath,
    required int depth,
    required List<BookChapter> out,
    required Set<String> seen,
  }) {
    for (final item in items) {
      if (item is String) {
        final path = normalizeChapterPath(item, basePath: rootPath);
        if (path == null || !seen.add(path)) continue;
        out.add(
          BookChapter(
            title: _fileNameTitle(path.split('/').last),
            path: path,
            depth: depth,
          ),
        );
        continue;
      }
      if (item is! Map) continue;
      final rawPath = item['path'] ?? item['file'] ?? item['href'];
      final rawTitle = item['title'] ?? item['name'];
      final children = item['children'] ?? item['items'];
      if (rawPath is String) {
        final path = normalizeChapterPath(rawPath, basePath: rootPath);
        if (path != null && seen.add(path)) {
          final title = rawTitle is String ? _cleanTitle(rawTitle) : '';
          out.add(
            BookChapter(
              title: title.isEmpty
                  ? _fileNameTitle(path.split('/').last)
                  : title,
              path: path,
              depth: depth,
            ),
          );
        }
      }
      if (children is List) {
        _flattenManifest(
          children,
          rootPath: rootPath,
          depth: depth + 1,
          out: out,
          seen: seen,
        );
      }
    }
  }

  static String? _readFile(String repoRoot, String rootPath, String name) {
    try {
      final file = File(_absolute(repoRoot, rootPath, name));
      if (!file.existsSync()) return null;
      return file.readAsStringSync(encoding: utf8);
    } on Object {
      return null;
    }
  }

  static String _absolute(String repoRoot, String rootPath, String name) {
    final sep = Platform.pathSeparator;
    final dir = rootPath.isEmpty
        ? repoRoot
        : '$repoRoot$sep${rootPath.replaceAll('/', sep)}';
    return '$dir$sep$name';
  }

  static String _fallbackTitle(String repoRoot, String rootPath) {
    if (rootPath.isEmpty) {
      final name = repoRoot.split(RegExp(r'[\\/]')).last;
      return name.isEmpty ? '书单' : name;
    }
    final name = rootPath.split('/').last;
    return name.isEmpty ? '书单' : name;
  }

  static String? _headingTitle(String text) {
    for (final line in const LineSplitter().convert(text)) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        final title = trimmed.substring(2).trim();
        if (title.isNotEmpty) return title;
      }
    }
    return null;
  }

  static int _indentWidth(String leading) {
    var width = 0;
    for (final rune in leading.runes) {
      width += rune == 0x09 ? 4 : 1;
    }
    return width;
  }

  static String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _fileNameTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    var name = dot > 0 ? fileName.substring(0, dot) : fileName;
    name = name.replaceFirst(RegExp(r'^\d+[._\-\s]+'), '');
    name = name.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (name.isEmpty) {
      name = dot > 0 ? fileName.substring(0, dot) : fileName;
    }
    return name;
  }
}
