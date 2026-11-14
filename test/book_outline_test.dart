import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/books/book.dart';
import 'package:pullread/src/books/book_outline.dart';
import 'package:pullread/src/notes/note_scanner.dart';

NoteFile _note(String relativePath) => NoteFile(
      relativePath: relativePath,
      absolutePath: relativePath,
      modified: DateTime(2026),
      sizeBytes: 1,
    );

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pullread-book-test-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  void write(String relative, String content) {
    final file = File('${temp.path}${Platform.pathSeparator}'
        '${relative.replaceAll('/', Platform.pathSeparator)}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  group('manifest', () {
    test('解析嵌套章节并规范相对路径', () {
      final outline = BookOutlineReader.parseManifest(
        '''
{
  "title": "我的书",
  "chapters": [
    {"title": "开始", "path": "intro.md"},
    {"title": "第一部分", "children": [
      {"title": "第一章", "path": "./part1/ch1.md"},
      {"title": "第二章", "file": "part1/ch2.md"}
    ]}
  ]
}
''',
        rootPath: 'docs/book',
        titleFallback: 'fallback',
      );

      expect(outline, isNotNull);
      expect(outline!.title, '我的书');
      expect(outline.source, BookOutlineSource.manifest);
      expect(outline.chapters.map((c) => c.path), [
        'docs/book/intro.md',
        'docs/book/part1/ch1.md',
        'docs/book/part1/ch2.md',
      ]);
      expect(outline.chapters[0].depth, 0);
      expect(outline.chapters[1].depth, 1);
      expect(outline.chapters[2].depth, 1);
    });

    test('无效 JSON 返回 null', () {
      final outline = BookOutlineReader.parseManifest(
        '{not json',
        rootPath: '',
        titleFallback: '书',
      );
      expect(outline, isNull);
    });
  });

  group('SUMMARY / sidebar', () {
    test('解析列表层级并过滤外链、锚点与重复章节', () {
      final chapters = BookOutlineReader.parseOutlineMarkdown(
        '''
# 目录

- [第一章](ch1.md)
  - [1.1 小节](ch1/sub.md#part)
  - [外部](https://example.com/a.md)
- [第二章](ch2.md)
- [锚点](#top)
- [重复](ch1.md)
''',
        rootPath: 'book',
      );

      expect(chapters.map((c) => c.path), [
        'book/ch1.md',
        'book/ch1/sub.md',
        'book/ch2.md',
      ]);
      expect(chapters[0].depth, 0);
      expect(chapters[1].depth, 1);
      expect(chapters[2].depth, 0);
    });

    test('四空格缩进同样映射为一级', () {
      final chapters = BookOutlineReader.parseOutlineMarkdown(
        '- [A](a.md)\n    - [B](b.md)\n',
        rootPath: '',
      );
      expect(chapters.map((c) => c.depth), [0, 1]);
    });
  });

  group('读取优先级', () {
    test('manifest 优先于 SUMMARY', () {
      write('.pullread-book.json',
          '{"title":"显式","chapters":[{"title":"A","path":"a.md"}]}');
      write('SUMMARY.md', '- [B](b.md)\n');
      final outline = BookOutlineReader.read(
        temp.path,
        '',
        [_note('a.md'), _note('b.md'), _note('.pullread-book.json')],
      );
      expect(outline!.source, BookOutlineSource.manifest);
      expect(outline.title, '显式');
      expect(outline.chapters.single.path, 'a.md');
    });

    test('没有清单时回退 _sidebar.md', () {
      write('_sidebar.md', '# 侧栏\n\n* [起步](start.md)\n');
      final outline = BookOutlineReader.read(temp.path, '', [_note('start.md')]);
      expect(outline!.source, BookOutlineSource.sidebar);
      expect(outline.title, '侧栏');
      expect(outline.chapters.single.path, 'start.md');
    });

    test('都没有时自动推断并按自然顺序', () {
      final files = [
        _note('book/chapter10.md'),
        _note('book/chapter2.md'),
        _note('book/sub/deep.md'),
        _note('book/picture.png'),
      ];
      final outline = BookOutlineReader.infer(temp.path, 'book', files);
      expect(outline.source, BookOutlineSource.inferred);
      expect(outline.chapters.map((c) => c.path), [
        'book/chapter2.md',
        'book/chapter10.md',
        'book/sub/deep.md',
      ]);
      expect(outline.chapters.last.depth, 1);
      expect(outline.chapters.first.title, 'chapter2');
    });
  });

  group('路径安全', () {
    test('拒绝越出仓库根', () {
      expect(
        BookOutlineReader.normalizeChapterPath('../../secret.md',
            basePath: 'book'),
        isNull,
      );
    });

    test('允许引用同仓库其他目录', () {
      expect(
        BookOutlineReader.normalizeChapterPath('../shared/a.md',
            basePath: 'book'),
        'shared/a.md',
      );
    });

    test('拒绝外部链接与非文档', () {
      expect(
        BookOutlineReader.normalizeChapterPath('mailto:a@b.com', basePath: ''),
        isNull,
      );
      expect(
        BookOutlineReader.normalizeChapterPath('image.png', basePath: ''),
        isNull,
      );
    });
  });

  group('书根发现', () {
    test('清单目录与仓库根都可切换，显式来源优先', () {
      write('SUMMARY.md', '- [A](a.md)\n');
      write('books/one/SUMMARY.md', '- [B](b.md)\n');
      write('books/two/.pullread-book.json',
          '{"title":"二","chapters":[{"path":"c.md"}]}');
      final files = [
        _note('a.md'),
        _note('books/one/b.md'),
        _note('books/two/c.md'),
        _note('books/one/SUMMARY.md'),
        _note('books/two/.pullread-book.json'),
      ];

      final roots = BookOutlineReader.discover(temp.path, files);
      expect(roots.map((r) => r.path), ['books/two', '', 'books/one']);
      expect(roots.first.source, BookOutlineSource.manifest);
    });
  });
}
