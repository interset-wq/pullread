import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/git/repo_meta.dart';
import 'package:reader/src/ui/home_feed.dart';

/// 首页聚合：Git 仓库与本地文件夹镜像共用收藏 / 最近阅读。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory reposRoot;
  late Directory localRoot;
  late Directory repoA;
  late Directory mirrorB;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('home-feed-');
    reposRoot = Directory('${docs.path}${Platform.pathSeparator}repos')
      ..createSync();
    localRoot = Directory('${docs.path}${Platform.pathSeparator}local')
      ..createSync();
    repoA = Directory('${reposRoot.path}${Platform.pathSeparator}a')
      ..createSync();
    Directory('${repoA.path}${Platform.pathSeparator}.git').createSync();
    mirrorB = Directory('${localRoot.path}${Platform.pathSeparator}b')
      ..createSync();
    File('${mirrorB.path}${Platform.pathSeparator}.pullread_local')
        .writeAsStringSync('');
  });

  tearDown(() {
    try {
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    } on Object {
      // 忽略 Windows 句柄占用
    }
  });

  void writeRecents(Directory root, List<String> entries) {
    final f = File(
      '${root.path}${Platform.pathSeparator}.meta'
      '${Platform.pathSeparator}recents.json',
    );
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode({'recents': entries}));
  }

  File writeFile(Directory source, String relativePath) {
    final f = File(
      '${source.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    f.parent.createSync(recursive: true);
    return f..writeAsStringSync('# $relativePath');
  }

  test('收藏同时收录 Git 仓库与本地镜像', () {
    writeFile(repoA, 'git.md');
    writeFile(mirrorB, 'local.md');
    RepoMeta.toggleStar(repoA.path, 'git.md');
    RepoMeta.toggleStar(mirrorB.path, 'local.md');

    final starred = collectHomeStarred([repoA], [mirrorB]);

    expect(starred, [(repoA, 'git.md'), (mirrorB, 'local.md')]);
  });

  test('最近阅读按时间倒序合并两个来源并去重取前 N 条', () {
    for (final rel in ['old.md', 'legacy.md', 'same.md']) {
      writeFile(repoA, rel);
    }
    for (final rel in ['new.md', 'same.md']) {
      writeFile(mirrorB, rel);
    }
    writeRecents(reposRoot, [
      'a\told.md\t2026-01-01T00:00:00.000',
      'a\tlegacy.md', // 旧版条目没有时间，排在最后
      'a\tsame.md\t2026-01-02T00:00:00.000',
    ]);
    writeRecents(localRoot, [
      'b\tnew.md\t2026-03-01T00:00:00.000',
      'b\tsame.md\t2026-01-01T00:00:00.000',
    ]);

    final all = collectHomeRecents([repoA], [mirrorB], limit: 10);
    expect(all, [
      (mirrorB, 'new.md'),
      (repoA, 'same.md'),
      (repoA, 'old.md'),
      (mirrorB, 'same.md'), // 不同来源的同名文件各自保留
      (repoA, 'legacy.md'),
    ]);

    final limited = collectHomeRecents([repoA], [mirrorB], limit: 2);
    expect(limited, [(mirrorB, 'new.md'), (repoA, 'same.md')]);
  });

  test('只保留仍存在的来源条目', () {
    writeFile(mirrorB, 'local.md');
    writeRecents(reposRoot, ['gone\tx.md\t2026-01-01T00:00:00.000']);
    writeRecents(localRoot, ['b\tlocal.md\t2026-01-02T00:00:00.000']);

    expect(collectHomeRecents([repoA], [mirrorB], limit: 5), [
      (mirrorB, 'local.md'),
    ]);
  });

  test('文件被删除后收藏与最近阅读都不再出现幽灵卡片', () {
    final kept = writeFile(repoA, 'kept.md');
    final removed = writeFile(repoA, 'removed.md');
    RepoMeta.toggleStar(repoA.path, 'kept.md');
    RepoMeta.toggleStar(repoA.path, 'removed.md');
    writeRecents(reposRoot, [
      'a\tremoved.md\t2026-03-01T00:00:00.000',
      'a\tkept.md\t2026-01-01T00:00:00.000',
    ]);

    expect(removed.existsSync(), isTrue);
    removed.deleteSync();
    expect(kept.existsSync(), isTrue);

    expect(collectHomeStarred([repoA], const []), [(repoA, 'kept.md')]);
    // 缺失的条目被跳过，也不会占用 limit 名额
    expect(
      collectHomeRecents([repoA], const [], limit: 1),
      [(repoA, 'kept.md')],
    );
  });

  test('没有任何来源时返回空列表', () {
    expect(collectHomeStarred(const [], const []), isEmpty);
    expect(collectHomeRecents(const [], const [], limit: 5), isEmpty);
  });
}
