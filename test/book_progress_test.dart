import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/git/repo_meta.dart';

void main() {
  late Directory parent;
  late String repoRoot;

  setUp(() {
    parent = Directory.systemTemp.createTempSync('pullread-book-progress-');
    repoRoot = '${parent.path}${Platform.pathSeparator}notes';
    Directory(repoRoot).createSync();
  });

  tearDown(() {
    if (parent.existsSync()) parent.deleteSync(recursive: true);
  });

  File metaFile() => File(
        '${parent.path}${Platform.pathSeparator}.meta'
        '${Platform.pathSeparator}notes.json',
      );

  test('按书根分别保存与读取章节', () {
    RepoMeta.saveBookProgress(repoRoot, '', 'intro.md');
    RepoMeta.saveBookProgress(repoRoot, 'books/a', 'books/a/ch1.md');

    expect(RepoMeta.readBookProgress(repoRoot, ''), 'intro.md');
    expect(RepoMeta.readBookProgress(repoRoot, 'books/a'), 'books/a/ch1.md');
    expect(RepoMeta.readBookProgress(repoRoot, 'books/b'), isNull);
  });

  test('书根路径统一斜杠并忽略空段', () {
    RepoMeta.saveBookProgress(repoRoot, r'books\a\\', r'books\a\ch2.md');
    expect(RepoMeta.readBookProgress(repoRoot, 'books/a'), 'books/a/ch2.md');
  });

  test('兼容直接存字符串的旧格式', () {
    metaFile().parent.createSync(recursive: true);
    metaFile().writeAsStringSync(
      jsonEncode({
        'bookProgress': {'legacy': 'legacy/ch1.md'},
      }),
    );
    expect(
      RepoMeta.readBookProgress(repoRoot, 'legacy'),
      'legacy/ch1.md',
    );
  });
}
