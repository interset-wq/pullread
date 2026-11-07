import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/git/repo_meta.dart';

/// 「最近阅读」记录：时间戳、来源根目录与去重。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory reposRoot;
  late Directory repoA;
  late Directory localRoot;
  late Directory mirrorB;
  late Directory mirrorC;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('repo-meta-recents-');
    reposRoot = Directory('${docs.path}${Platform.pathSeparator}repos')
      ..createSync();
    repoA = Directory('${reposRoot.path}${Platform.pathSeparator}a')
      ..createSync();
    Directory('${repoA.path}${Platform.pathSeparator}.git').createSync();
    localRoot = Directory('${docs.path}${Platform.pathSeparator}local')
      ..createSync();
    mirrorB = Directory('${localRoot.path}${Platform.pathSeparator}b')
      ..createSync();
    mirrorC = Directory('${localRoot.path}${Platform.pathSeparator}c')
      ..createSync();
  });

  tearDown(() {
    try {
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    } on Object {
      // 忽略 Windows 句柄占用
    }
  });

  File recentsFile(Directory root) => File(
        '${root.path}${Platform.pathSeparator}.meta'
        '${Platform.pathSeparator}recents.json',
      );

  test('Git 仓库记录写到 repos 根的共享文件', () {
    RepoMeta.pushRecent(repoA.path, 'note.md');

    expect(recentsFile(reposRoot).existsSync(), isTrue);
    final entries = RepoMeta.readRecentEntries(reposRoot.path);
    expect(entries.single.repoName, 'a');
    expect(entries.single.relativePath, 'note.md');
    expect(entries.single.at, isNotNull);
  });

  test('本地镜像显式传入 recentsRoot 时共用 <docs>/local 的记录', () {
    RepoMeta.pushRecent(
      mirrorB.path,
      'b.md',
      recentsRoot: localRoot.path,
    );
    RepoMeta.pushRecent(
      mirrorC.path,
      'c.md',
      recentsRoot: localRoot.path,
    );

    expect(recentsFile(localRoot).existsSync(), isTrue);
    expect(recentsFile(mirrorB).existsSync(), isFalse);
    expect(RepoMeta.readRecents(localRoot.path), [
      ('c', 'c.md'),
      ('b', 'b.md'),
    ]);
  });

  test('重复记录去重并排到最前，且受 limit 限制', () {
    RepoMeta.pushRecent(repoA.path, 'one.md', limit: 3);
    RepoMeta.pushRecent(repoA.path, 'two.md', limit: 3);
    RepoMeta.pushRecent(repoA.path, 'one.md', limit: 3);

    expect(RepoMeta.readRecents(reposRoot.path), [
      ('a', 'one.md'),
      ('a', 'two.md'),
    ]);

    RepoMeta.pushRecent(repoA.path, 'three.md', limit: 3);
    RepoMeta.pushRecent(repoA.path, 'four.md', limit: 3);
    expect(RepoMeta.readRecents(reposRoot.path), [
      ('a', 'four.md'),
      ('a', 'three.md'),
      ('a', 'one.md'),
    ]);
  });

  test('兼容旧版没有时间戳的条目', () {
    final f = recentsFile(reposRoot);
    f.parent.createSync(recursive: true);
    f.writeAsStringSync('{"recents":["a\\tlegacy.md"]}');

    final entry = RepoMeta.readRecentEntries(reposRoot.path).single;
    expect(entry.repoName, 'a');
    expect(entry.relativePath, 'legacy.md');
    expect(entry.at, isNull);
  });

  test('clearRecents 只清掉指定来源根目录的记录', () {
    RepoMeta.pushRecent(repoA.path, 'a.md');
    RepoMeta.pushRecent(mirrorB.path, 'b.md', recentsRoot: localRoot.path);

    RepoMeta.clearRecents(reposRoot.path);

    expect(RepoMeta.readRecents(reposRoot.path), isEmpty);
    expect(RepoMeta.readRecents(localRoot.path).length, 1);
  });

  test('清空收藏同时覆盖本地镜像', () {
    RepoMeta.toggleStar(repoA.path, 'a.md');
    RepoMeta.toggleStar(mirrorB.path, 'b.md');
    expect(RepoMeta.starredFiles(repoA.path), ['a.md']);
    expect(RepoMeta.starredFiles(mirrorB.path), ['b.md']);
    expect(RepoMeta.countStars(reposRoot.path), 1);
    expect(RepoMeta.countStars(localRoot.path), 1);

    RepoMeta.clearAllStars(reposRoot.path);
    RepoMeta.clearAllStars(localRoot.path);

    expect(RepoMeta.starredFiles(repoA.path), isEmpty);
    expect(RepoMeta.starredFiles(mirrorB.path), isEmpty);
    expect(RepoMeta.countStars(reposRoot.path), 0);
    expect(RepoMeta.countStars(localRoot.path), 0);
  });
}
