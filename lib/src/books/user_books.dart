import 'dart:convert';
import 'dart:io';

/// 用户创建的电子书章节：仓库根相对路径 + 手动确认的标题。
///
/// [depth] 保留扫描时的目录层级（相对扫描根的目录层数），
/// 同一子目录的章节在同一缩进层级，如 `chapter1/` 下的文件同组。
class UserChapter {
  const UserChapter({
    required this.path,
    required this.title,
    this.depth = 0,
  });

  final String path;
  final String title;
  final int depth;

  Map<String, dynamic> toJson() => {'p': path, 't': title, 'd': depth};

  static UserChapter? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final p = raw['p'];
    final t = raw['t'];
    if (p is! String || p.isEmpty) return null;
    var path = p.replaceAll('\\', '/');
    // 兼容历史数据：链接里的空格可能被存成 %20 等转义，真实文件名不含
    if (path.contains('%')) {
      try {
        final decoded = Uri.decodeFull(path);
        if (decoded != path) path = decoded;
      } on ArgumentError {
        // 保持原文
      }
    }
    final d = raw['d'];
    return UserChapter(
      path: path,
      title: t is String && t.isNotEmpty ? t : path.split('/').last,
      depth: d is int && d >= 0 ? d : 0,
    );
  }
}

/// 用户创建的电子书：章节顺序由用户确定，存放在 `.meta`（不写回仓库）。
class UserBook {
  UserBook({
    required this.id,
    required this.title,
    this.rootPath = '',
    required this.chapters,
  });

  final String id;
  final String title;

  /// 书根相对来源根的目录；根目录为 `''`。
  final String rootPath;
  final List<UserChapter> chapters;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'root': rootPath,
        'chapters': [for (final c in chapters) c.toJson()],
      };

  static UserBook? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final root = raw['root'];
    final chapters = raw['chapters'];
    if (id is! String || id.isEmpty) return null;
    if (chapters is! List) return null;
    final parsed = <UserChapter>[
      for (final c in chapters) ?UserChapter.fromJson(c),
    ];
    if (parsed.isEmpty) return null;
    return UserBook(
      id: id,
      title: title is String && title.isNotEmpty ? title : id,
      rootPath: root is String ? root.replaceAll('\\', '/') : '',
      chapters: parsed,
    );
  }
}

/// 用户书单的磁盘存储：`<来源父目录>/.meta/user_books/<来源名>.json`。
///
/// 与 NoteIndexCache 同级，不污染仓库内容；本地镜像来源也共用同一份。
/// 读失败/结构不符返回空列表；写失败静默（书单可重建，不丢仓库数据）。
class UserBookStore {
  static List<UserBook> read(String sourceRoot) {
    try {
      final file = _file(sourceRoot);
      if (!file.existsSync()) return const [];
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map) return const [];
      final books = raw['books'];
      if (books is! List) return const [];
      return <UserBook>[
        for (final book in books) ?UserBook.fromJson(book),
      ];
    } on Object {
      return const [];
    }
  }

  static void save(String sourceRoot, List<UserBook> books) {
    try {
      final file = _file(sourceRoot);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode({
          'version': 1,
          'books': [for (final book in books) book.toJson()],
        }),
        flush: true,
      );
    } on Object {
      // 书单写失败不影响仓库功能
    }
  }

  static File _file(String sourceRoot) {
    final name = sourceRoot.split(Platform.pathSeparator).last;
    final parent = Directory(sourceRoot).parent.path;
    return File(
      '$parent${Platform.pathSeparator}.meta'
      '${Platform.pathSeparator}user_books'
      '${Platform.pathSeparator}$name.json',
    );
  }
}
