import 'dart:io';

import '../git/repo_meta.dart';

/// 首页「收藏 / 最近阅读」聚合。
///
/// 本地文件夹镜像（`<docs>/local/<name>`）与 Git 仓库（`<docs>/repos/<name>`）
/// 共用同一套元数据：收藏记录在各来源目录内，最近阅读按来源根目录
/// （`<root>/.meta/recents.json`）各存一份、带时间戳。这里跨两类来源合并，
/// 收藏保持来源顺序，最近阅读按时间倒序去重后取前 [limit] 条。

/// 跨来源收藏文章（Git 仓库在前，本地镜像在后，各自按收藏先后）。
List<(Directory, String)> collectHomeStarred(
  List<Directory> repos,
  List<Directory> locals,
) {
  final out = <(Directory, String)>[];
  for (final source in [...repos, ...locals]) {
    for (final rel in RepoMeta.starredFiles(source.path)) {
      out.add((source, rel));
    }
  }
  return out;
}

/// 跨来源最近阅读（全局新→旧，最多 [limit] 条）。
///
/// 来源目录按名称映射：`recents.json` 只记录来源目录名，Git 仓库名与
/// 本地镜像名撞车时优先取 Git 仓库（调用方打开前仍会校验文件是否存在）。
List<(Directory, String)> collectHomeRecents(
  List<Directory> repos,
  List<Directory> locals, {
  required int limit,
}) {
  if (repos.isEmpty && locals.isEmpty) return const [];
  final byName = <String, Directory>{};
  for (final dir in [...repos, ...locals]) {
    byName.putIfAbsent(_baseName(dir.path), () => dir);
  }
  final entries = <({String repoName, String relativePath, DateTime? at})>[];
  for (final root in _sourceRoots(repos, locals)) {
    entries.addAll(RepoMeta.readRecentEntries(root.path));
  }
  entries.sort((a, b) {
    final at = a.at;
    final bt = b.at;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });
  final out = <(Directory, String)>[];
  final seen = <String>{};
  for (final entry in entries) {
    final dir = byName[entry.repoName];
    if (dir == null) continue;
    if (!seen.add('${entry.repoName}\t${entry.relativePath}')) continue;
    out.add((dir, entry.relativePath));
    if (out.length >= limit) break;
  }
  return out;
}

/// 各来源的元数据根目录（`repos.first.parent` 与 `locals.first.parent`）。
Iterable<Directory> _sourceRoots(
  List<Directory> repos,
  List<Directory> locals,
) sync* {
  final seen = <String>{};
  for (final first in [
    if (repos.isNotEmpty) repos.first,
    if (locals.isNotEmpty) locals.first,
  ]) {
    final root = first.parent;
    if (seen.add(root.path)) yield root;
  }
}

String _baseName(String path) => path.split(Platform.pathSeparator).last;
