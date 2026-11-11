import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/git/repo_meta.dart';
import 'package:pullread/src/git/sync_service.dart';
import 'package:pullread/src/platforms/git_platform.dart';
import 'package:pullread/src/platforms/repo_info.dart';

/// 分支切换：只用临时目录里的本地 bare 仓库，不访问网络。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late Directory work;
  late String remotePath;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('switch-branch');
    work = Directory('${temp.path}${Platform.pathSeparator}work')
      ..createSync();
    remotePath = '${temp.path}${Platform.pathSeparator}remote.git';
    await _git(['init', '-b', 'main'], work);
    await _git(['config', 'user.email', 't@example.com'], work);
    await _git(['config', 'user.name', 'tester'], work);
    _write(work, 'shared.md', '# shared');
    _write(work, 'main-only.md', '# main');
    await _git(['add', '.'], work);
    await _git(['commit', '-m', 'first'], work);
    await _git(['checkout', '-b', 'feature'], work);
    // feature 分支刻意不含 main-only.md，才能验证切换时旧文件被清理
    _file(work.path, 'main-only.md').deleteSync();
    _write(work, 'feature-only.md', '# feature');
    await _git(['add', '-A'], work);
    await _git(['commit', '-m', 'feature'], work);
    await _git(['checkout', 'main'], work);
    await _git(['init', '--bare', remotePath], temp);
    await _git(['remote', 'add', 'origin', remotePath], work);
    await _git(['push', '--all', 'origin'], work);
    // bare 仓库的 HEAD 默认是 master，必须指向真正存在的 main，
    // 否则 libgit2 克隆会检出未出生的 master 分支。
    await _git(
      ['symbolic-ref', 'HEAD', 'refs/heads/main'],
      Directory(remotePath),
    );
  });

  tearDown(() {
    try {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    } on Object {
      // Windows 句柄未释放时忽略
    }
  });

  test('lists remote branches and marks the current one', () async {
    final path = await _clone(temp, remotePath);
    final info = await GitSyncService().listBranches(
      repoDir: Directory(path),
    );
    expect(info.current, 'main');
    expect(info.branches, containsAll(<String>['main', 'feature']));
    expect(info.branches, isNot(contains('HEAD')));
  });

  test('switching checks out the branch content and updates meta', () async {
    final path = await _clone(temp, remotePath);
    await GitSyncService().switchBranch(
      repoDir: Directory(path),
      branch: 'feature',
    );

    expect(GitSyncService.readHeadBranch(path), 'feature');
    expect(_file(path, 'feature-only.md').existsSync(), isTrue);
    expect(_file(path, 'main-only.md').existsSync(), isFalse);
    expect(_file(path, 'shared.md').existsSync(), isTrue);

    // 切回默认分支，工作区恢复
    final service = GitSyncService();
    await service.switchBranch(repoDir: Directory(path), branch: 'main');
    expect(GitSyncService.readHeadBranch(path), 'main');
    expect(_file(path, 'main-only.md').existsSync(), isTrue);
    expect(_file(path, 'feature-only.md').existsSync(), isFalse);

    RepoMeta.setBranch(path, 'feature');
    expect(RepoMeta.read(path)?.branch, 'feature');
  });

  test('switching to the current branch is a no-op', () async {
    final path = await _clone(temp, remotePath);
    await GitSyncService().switchBranch(
      repoDir: Directory(path),
      branch: 'main',
    );
    expect(GitSyncService.readHeadBranch(path), 'main');
    expect(_file(path, 'main-only.md').existsSync(), isTrue);
  });

  test('unknown branch fails without touching the working tree', () async {
    final path = await _clone(temp, remotePath);
    await expectLater(
      GitSyncService().switchBranch(
        repoDir: Directory(path),
        branch: 'missing',
      ),
      throwsA(isA<SyncException>()),
    );
    expect(GitSyncService.readHeadBranch(path), 'main');
    expect(_file(path, 'main-only.md').existsSync(), isTrue);
  });

  test('rejects unsafe branch names before touching the repo', () async {
    final path = await _clone(temp, remotePath);
    for (final name in ['', '..', 'a..b', '/abs', 'a//b', 'a b', 'x.lock']) {
      expect(
        GitSyncService.isSafeBranchName(name),
        isFalse,
        reason: '应拒绝 $name',
      );
    }
    expect(GitSyncService.isSafeBranchName('feature/login'), isTrue);
    await expectLater(
      GitSyncService().switchBranch(
        repoDir: Directory(path),
        branch: '../escape',
      ),
      throwsA(isA<SyncException>()),
    );
    expect(GitSyncService.readHeadBranch(path), 'main');
  });

}

Future<String> _clone(Directory temp, String remotePath) {
  final reposRoot = Directory('${temp.path}${Platform.pathSeparator}repos')
    ..createSync();
  return GitSyncService().clone(
    repo: RepoInfo(
      platform: GitPlatform.github,
      owner: 'me',
      name: 'notes',
      cloneUrl: remotePath,
    ),
    parentDir: reposRoot,
  );
}

File _file(String repoPath, String name) =>
    File('$repoPath${Platform.pathSeparator}$name');

void _write(Directory dir, String name, String content) {
  File('${dir.path}${Platform.pathSeparator}$name').writeAsStringSync(content);
}

Future<void> _git(List<String> args, Directory cwd) async {
  final result = await Process.run(
    'git',
    args,
    workingDirectory: cwd.path,
    stdoutEncoding: const SystemEncoding(),
    stderrEncoding: const SystemEncoding(),
  );
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}
