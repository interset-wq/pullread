// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/reader.dart';

// 针对真实仓库的功能验证：克隆 + pull（只读，不 push）。
void main() {
  const repo = RepoInfo(
    platform: GitPlatform.gitcode,
    owner: 'interset-wq',
    name: 'notes',
    cloneUrl: 'https://gitcode.com/interset-wq/notes.git',
  );

  final sync = GitSyncService();
  late Directory parent;

  setUpAll(() {
    parent = Directory('temp/sync-verify');
    if (parent.existsSync()) parent.deleteSync(recursive: true);
    parent.createSync(recursive: true);
  });
  tearDownAll(() {
    if (parent.existsSync()) parent.deleteSync(recursive: true);
  });

  test('clone + pull notes repo', () async {
    final path = await _cloneWithRetry(sync, repo, parent);
    print('cloned to $path');
    expect(Directory(path).existsSync(), isTrue);

    final outcome = await sync.pull(
      repoDir: Directory(path),
    );
    print('pull result: ${outcome.result}');
    expect(
      outcome.result,
      anyOf(equals(PullResult.upToDate), equals(PullResult.fastForwarded)),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

/// 真实网络的克隆偶尔会被对端断开（gitcode 上见过 SSL broken pipe）。
/// 仅对网络类错误重试一次，其他错误（凭证/路径/回调）立即抛出。
Future<String> _cloneWithRetry(
  GitSyncService sync,
  RepoInfo repo,
  Directory parent,
) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await sync.clone(repo: repo, parentDir: parent);
    } catch (error) {
      final text = error.toString();
      final transient = text.contains('GIT_ERROR_NET') ||
          text.contains('SSL') ||
          text.contains('Broken pipe') ||
          text.contains('timed out');
      if (attempt >= 2 || !transient) rethrow;
      print('clone failed on attempt $attempt (network), retrying: $text');
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}
