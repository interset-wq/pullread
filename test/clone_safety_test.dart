import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/git/sync_service.dart';
import 'package:pullread/src/platforms/git_platform.dart';
import 'package:pullread/src/platforms/repo_info.dart';
import 'package:pullread/src/platforms/repo_url.dart';

/// Regression cover for the clone-path data-loss bug:
/// a trailing-slash URL used to produce an empty repo name, making the clone
/// target equal to the repos root, which `_prepareTarget` then recursively
/// deleted (including `.meta` with progress/bookmarks).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseRepoUrl', () {
    test('ignores trailing slashes, query and fragment', () {
      expect(parseRepoUrl('https://github.com/owner/notes/'), (
        owner: 'owner',
        name: 'notes',
      ));
      expect(parseRepoUrl('https://github.com/owner/notes.git/'), (
        owner: 'owner',
        name: 'notes',
      ));
      expect(parseRepoUrl('https://github.com/owner/notes?tab=readme#top'), (
        owner: 'owner',
        name: 'notes',
      ));
    });

    test('strips only a trailing .git suffix', () {
      expect(parseRepoUrl('https://host/o/my.git.repo')?.name, 'my.git.repo');
      expect(parseRepoUrl('https://host/o/notes.GIT')?.name, 'notes');
    });

    test('accepts short owner/repo input', () {
      expect(parseRepoUrl('owner/notes'), (owner: 'owner', name: 'notes'));
    });

    test('rejects empty, owner-only, dot-prefixed and path-like names', () {
      for (final url in [
        '',
        '   ',
        'notes',
        'https://github.com/',
        'https://github.com/owner/',
        'https://github.com/owner/.',
        'https://github.com/owner/%2E%2E',
        'https://github.com/owner/.meta',
        'https://github.com/owner/.git',
        'https://github.com/owner/notes%2Fevil',
        'https://github.com/owner/na:me',
        'https://github.com/owner/CON',
      ]) {
        expect(parseRepoUrl(url), isNull, reason: url);
      }
    });
  });

  group('isSafeRepoName', () {
    test('accepts ordinary names', () {
      for (final name in ['notes', 'my-notes', 'my.git.repo', '中文笔记']) {
        expect(isSafeRepoName(name), isTrue, reason: name);
      }
    });

    test('rejects names that could escape or hit metadata', () {
      for (final name in ['', '.', '..', '.meta', 'a/b', r'a\b', 'a:b']) {
        expect(isSafeRepoName(name), isFalse, reason: name);
      }
    });
  });

  group('isDirectChildPath', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('pullread-path-');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('accepts exactly one level below', () {
      expect(isDirectChildPath(root.path, '${root.path}/repo'), isTrue);
      expect(isDirectChildPath(root.path, '${root.path}/repo/'), isTrue);
    });

    test('rejects the root itself, deeper paths and escapes', () {
      expect(isDirectChildPath(root.path, root.path), isFalse);
      expect(isDirectChildPath(root.path, '${root.path}/repo/file'), isFalse);
      expect(isDirectChildPath(root.path, '${root.path}/../outside'), isFalse);
    });
  });

  group('destructive operations are guarded', () {
    late Directory root;
    late File sentinel;

    setUp(() {
      root = Directory.systemTemp.createTempSync('pullread-clone-');
      sentinel = File('${root.path}/keep.txt')..writeAsStringSync('keep');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('clone rejects unsafe names before touching the repos root', () async {
      for (final name in ['', '.', '..', '.meta', 'a/b', r'a\b', 'na:me']) {
        final repo = RepoInfo(
          platform: GitPlatform.other,
          owner: 'owner',
          name: name,
          cloneUrl: 'https://example.com/owner/$name',
        );
        await expectLater(
          GitSyncService().clone(repo: repo, parentDir: root),
          throwsA(isA<SyncException>()),
          reason: 'name="$name" must be rejected',
        );
        expect(sentinel.existsSync(), isTrue, reason: 'name="$name"');
      }
      expect(root.listSync().length, 1);
    });

    test('deleteRepo refuses the root and the metadata directory', () async {
      final meta = Directory('${root.path}/.meta')..createSync(recursive: true);

      await expectLater(
        GitSyncService().deleteRepo(root.path, reposRoot: root.path),
        throwsA(isA<SyncException>()),
      );
      await expectLater(
        GitSyncService().deleteRepo(meta.path, reposRoot: root.path),
        throwsA(isA<SyncException>()),
      );

      expect(sentinel.existsSync(), isTrue);
      expect(meta.existsSync(), isTrue);
    });

    test('deleteRepo still removes an ordinary repository directory', () async {
      final repo = Directory('${root.path}/notes')..createSync(recursive: true);
      File('${repo.path}/index.md').writeAsStringSync('# hi');

      await GitSyncService().deleteRepo(repo.path, reposRoot: root.path);

      expect(repo.existsSync(), isFalse);
      expect(sentinel.existsSync(), isTrue);
    });
  });
}
