import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/books/user_books.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('user_books_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  // 来源根 = tempDir/<name>，书单文件写到 tempDir/.meta/user_books/<name>.json
  String sourceRoot(String name) =>
      '${tempDir.path}${Platform.pathSeparator}$name';

  UserBook sampleBook(String id) => UserBook(
        id: id,
        title: '示例书',
        chapters: [
          const UserChapter(path: 'docs/a.md', title: 'A'),
          const UserChapter(path: 'docs/b.md', title: 'B'),
        ],
      );

  test('save then read round-trips books and chapter order', () {
    final root = sourceRoot('repo');
    final book = sampleBook('1');
    UserBookStore.save(root, [book]);

    final books = UserBookStore.read(root);
    expect(books, hasLength(1));
    expect(books.first.title, '示例书');
    expect(books.first.chapters.map((c) => c.path).toList(),
        ['docs/a.md', 'docs/b.md']);
    expect(books.first.chapters.map((c) => c.title).toList(), ['A', 'B']);
  });

  test('save replaces the previous book with the same content', () {
    final root = sourceRoot('repo');
    UserBookStore.save(root, [sampleBook('1')]);
    UserBookStore.save(root, [sampleBook('2')]);

    final books = UserBookStore.read(root);
    expect(books, hasLength(1));
    expect(books.first.id, '2');
  });

  test('read returns empty for missing store', () {
    expect(UserBookStore.read(sourceRoot('nothing')), isEmpty);
  });

  test('read survives a corrupted store file', () {
    final root = sourceRoot('broken');
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}.meta'
      '${Platform.pathSeparator}user_books'
      '${Platform.pathSeparator}broken.json',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('{not json');

    expect(UserBookStore.read(root), isEmpty);
  });

  test('read drops entries without chapters but keeps valid ones', () {
    final root = sourceRoot('mixed');
    UserBookStore.save(root, [sampleBook('1')]);
    final file = UserBookStore.read(root); // 触发文件存在
    expect(file, isNotEmpty);

    // 直接写一个含空章节书单的文件
    final store = File(
      '${tempDir.path}${Platform.pathSeparator}.meta'
      '${Platform.pathSeparator}user_books'
      '${Platform.pathSeparator}mixed.json',
    );
    store.writeAsStringSync(
      '{"version":1,"books":['
      '{"id":"1","title":"ok","root":"","chapters":[{"p":"docs/a.md","t":"A"}]},'
      '{"id":"2","title":"empty","root":"","chapters":[]}'
      ']}',
    );

    final books = UserBookStore.read(root);
    expect(books, hasLength(1));
    expect(books.first.id, '1');
  });

  test('chapter without path is dropped, title falls back to file name', () {
    final chapter = UserChapter.fromJson({'t': 'only title'});
    expect(chapter, isNull);

    final fallback = UserChapter.fromJson({'p': 'docs/readme.md'});
    expect(fallback, isNotNull);
    expect(fallback!.title, 'readme.md');
  });

  test('URL-escaped chapter paths (%20) are decoded on read', () {
    final chapter = UserChapter.fromJson({
      'p': 'docs/my%20file.md',
      't': 'my file',
    });
    expect(chapter, isNotNull);
    expect(chapter!.path, 'docs/my file.md');
  });

  test('chapter depth survives the JSON round-trip', () {
    final root = sourceRoot('repo');
    final book = UserBook(id: '1', title: '书', chapters: [
      const UserChapter(path: 'docs/a.md', title: 'A', depth: 1),
      const UserChapter(path: 'docs/b/c.md', title: 'C', depth: 2),
    ]);
    UserBookStore.save(root, [book]);

    final chapters = UserBookStore.read(root).first.chapters;
    expect(chapters[0].depth, 1);
    expect(chapters[1].depth, 2);
  });

  test('legacy chapters without depth read as depth 0', () {
    final chapter = UserChapter.fromJson({'p': 'docs/a.md', 't': 'A'});
    expect(chapter!.depth, 0);
  });
}
