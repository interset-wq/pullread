import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../git/repo_meta.dart';

/// 首页「最近阅读」聚合与展示组件。
///
/// 本地文件夹镜像（`<docs>/local/<name>`）与 Git 仓库（`<docs>/repos/<name>`）
/// 共用同一套元数据：最近阅读按来源根目录（`<root>/.meta/recents.json`）各存
/// 一份、带时间戳。这里跨两类来源合并，按时间倒序去重后取前 [limit] 条。

/// 首页最近阅读条目：保留来源目录、相对路径与记录时间。
class HomeRecentEntry {
  const HomeRecentEntry({
    required this.source,
    required this.relativePath,
    required this.isLocal,
    this.at,
  });

  final Directory source;
  final String relativePath;
  final bool isLocal;
  final DateTime? at;

  String get repoName => _baseName(source.path);

  String get fileName => relativePath.split('/').last;

  bool sameFile(HomeRecentEntry other) =>
      source.path == other.source.path && relativePath == other.relativePath;
}

/// 跨来源收藏文章（Git 仓库在前，本地镜像在后，各自按收藏先后）。
///
/// 收藏记录在仓库/镜像被删除、改名后仍留在元数据里；这里只保留磁盘上
/// 仍存在的文件，避免出现点了没反应的「幽灵卡片」。
List<(Directory, String)> collectHomeStarred(
  List<Directory> repos,
  List<Directory> locals,
) {
  final out = <(Directory, String)>[];
  for (final source in [...repos, ...locals]) {
    for (final rel in RepoMeta.starredFiles(source.path)) {
      if (!_sourceFileExists(source, rel)) continue;
      out.add((source, rel));
    }
  }
  return out;
}

/// 跨来源最近阅读（全局新→旧，最多 [limit] 条）。
///
/// 来源目录按名称映射：`recents.json` 只记录来源目录名，Git 仓库名与
/// 本地镜像名撞车时优先取 Git 仓库（调用方打开前仍会校验文件是否存在）。
List<HomeRecentEntry> collectHomeRecentEntries(
  List<Directory> repos,
  List<Directory> locals, {
  required int limit,
}) {
  if (repos.isEmpty && locals.isEmpty) return const [];
  final byName = <String, ({Directory dir, bool isLocal})>{};
  for (final dir in repos) {
    byName.putIfAbsent(_baseName(dir.path), () => (dir: dir, isLocal: false));
  }
  for (final dir in locals) {
    byName.putIfAbsent(_baseName(dir.path), () => (dir: dir, isLocal: true));
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
  final out = <HomeRecentEntry>[];
  final seen = <String>{};
  for (final entry in entries) {
    final hit = byName[entry.repoName];
    if (hit == null) continue;
    if (!seen.add('${entry.repoName}\t${entry.relativePath}')) continue;
    // 文件已删除或改名时跳过，不占用 limit 名额
    if (!_sourceFileExists(hit.dir, entry.relativePath)) continue;
    out.add(
      HomeRecentEntry(
        source: hit.dir,
        relativePath: entry.relativePath,
        isLocal: hit.isLocal,
        at: entry.at,
      ),
    );
    if (out.length >= limit) break;
  }
  return out;
}

/// 兼容旧调用：只取 (来源目录, 相对路径)。
List<(Directory, String)> collectHomeRecents(
  List<Directory> repos,
  List<Directory> locals, {
  required int limit,
}) {
  final entries = collectHomeRecentEntries(repos, locals, limit: limit);
  return [for (final e in entries) (e.source, e.relativePath)];
}

/// 首页最近阅读展示列表：与「继续阅读」当前文件去重，最多 [limit] 条。
List<HomeRecentEntry> homeRecentsForDisplay({
  required List<HomeRecentEntry> all,
  HomeRecentEntry? skip,
  int limit = 5,
}) {
  final out = <HomeRecentEntry>[];
  for (final entry in all) {
    if (skip != null && entry.sameFile(skip)) continue;
    out.add(entry);
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

/// [relativePath] 在来源目录里是否仍有对应文件。
///
/// 只做单个 stat（首页一次最多几十条），不是递归扫描，可以留在 UI 线程。
bool _sourceFileExists(Directory source, String relativePath) {
  final file = File(
    '${source.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
  return file.existsSync();
}

// ── 展示辅助 ────────────────────────────────────────────────────────────────

String homeFileBase(String relativePath) => relativePath.split('/').last;

String homeMonogram(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

/// 缩略章：优先取文件名开头的编号（01/02…），否则取首字母。
String homeChapterLabel(String relativePath) {
  final base = homeFileBase(relativePath);
  final match = RegExp(r'^(\d{1,3})').firstMatch(base);
  if (match != null) return match.group(1)!;
  return homeMonogram(base);
}

String homeRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';
}

String homeRecentTimeLabel(DateTime? at) =>
    at == null ? '' : homeRelativeTime(at);

/// 用文件体积粗估剩余阅读时间（按每 1600 字节约 1 分钟），仅作氛围数据。
int? estimateRemainingMinutes(int sizeBytes, double fraction) {
  if (sizeBytes <= 0) return null;
  final remaining = sizeBytes * (1 - fraction.clamp(0.0, 1.0));
  final minutes = (remaining / 1600).ceil();
  return minutes.clamp(1, 240);
}

// ── 视觉 token（全页只有一套，深浅色成对） ─────────────────────────────────

@immutable
class HomeTokens {
  const HomeTokens({
    required this.paper,
    required this.card,
    required this.border,
    required this.divider,
    required this.heroDivider,
    required this.green,
    required this.greenTint,
    required this.title,
    required this.secondary,
    required this.meta,
    required this.section,
    required this.pin,
    required this.red,
    required this.segment,
    required this.icon,
    required this.chevron,
  });

  final Color paper;
  final Color card;
  final Color border;
  final Color divider;
  final Color heroDivider;
  final Color green;
  final Color greenTint;
  final Color title;
  final Color secondary;
  final Color meta;
  final Color section;
  final Color pin;
  final Color red;
  final Color segment;
  final Color icon;
  final Color chevron;

  static const light = HomeTokens(
    paper: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE5E2D8),
    divider: Color(0xFFF2F0E8),
    heroDivider: Color(0xFFEFEDE5),
    green: Color(0xFF1F6F54),
    greenTint: Color(0xFFEDF5F0),
    title: Color(0xFF26241E),
    secondary: Color(0xFF3A382F),
    meta: Color(0xFFA5A296),
    section: Color(0xFF8A887E),
    pin: Color(0xFFC99A2E),
    red: Color(0xFFE5443B),
    segment: Color(0xFFECEAE2),
    icon: Color(0xFF4A4840),
    chevron: Color(0xFFB8B5AA),
  );

  static const dark = HomeTokens(
    paper: Color(0xFF141512),
    card: Color(0xFF1D1F1B),
    border: Color(0xFF34362F),
    divider: Color(0xFF2A2C26),
    heroDivider: Color(0xFF2A2C26),
    green: Color(0xFF74C7A4),
    greenTint: Color(0xFF22352C),
    title: Color(0xFFF2F0E8),
    secondary: Color(0xFFD8D5C9),
    meta: Color(0xFF8F8C82),
    section: Color(0xFF9A978C),
    pin: Color(0xFFD8AD4E),
    red: Color(0xFFF06B62),
    segment: Color(0xFF24261F),
    icon: Color(0xFFD8D5C9),
    chevron: Color(0xFF6E6B62),
  );

  static HomeTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ── 展示组件 ────────────────────────────────────────────────────────────────

/// 小节头：标题 + 右侧「全部 ›」。
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel = '全部 ›',
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: tokens.section,
                letterSpacing: 0.02,
              ),
            ),
          ),
          if (onAction != null)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.green,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 手机「继续阅读」细分隔线行（无卡片）。
class HomeContinueRow extends StatelessWidget {
  const HomeContinueRow({
    super.key,
    required this.title,
    required this.repo,
    required this.fraction,
    required this.onTap,
  });

  final String title;
  final String repo;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final percent = (fraction * 100).round();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.heroDivider)),
          ),
          child: Row(
            children: [
              Icon(Icons.play_circle_outline, size: 38, color: tokens.green),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '继续阅读 · $repo · 已读 $percent%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.06,
                        color: tokens.section,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.title,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _ProgressBar(
                      fraction: fraction,
                      height: 3,
                      track: tokens.heroDivider,
                      fill: tokens.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right, size: 18, color: tokens.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

/// 平板「继续阅读」大 hero 卡（少内容态的视觉主体）。
class HomeContinueHero extends StatelessWidget {
  const HomeContinueHero({
    super.key,
    required this.title,
    required this.repo,
    required this.fraction,
    required this.onTap,
    this.headingIndex,
    this.remainingMinutes,
    this.compact = false,
  });

  final String title;
  final String repo;
  final double fraction;
  final VoidCallback onTap;
  final int? headingIndex;
  final int? remainingMinutes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final percent = (fraction * 100).round();
    final position = headingIndex == null
        ? '已读 $percent%'
        : '上次读到 第 ${headingIndex! + 1} 节 · 已读 $percent%';
    final playSize = compact ? 54.0 : 64.0;
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 20, vertical: 18)
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Container(
                width: playSize,
                height: playSize,
                decoration: BoxDecoration(
                  color: tokens.greenTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: compact ? 28 : 32,
                  color: tokens.green,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '继续阅读 · $repo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11.5 : 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.06,
                        color: tokens.green,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 17 : 21,
                        fontWeight: FontWeight.w700,
                        color: tokens.title,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProgressBar(
                      fraction: fraction,
                      height: 5,
                      track: tokens.heroDivider,
                      fill: tokens.green,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            position,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: tokens.meta),
                          ),
                        ),
                        if (!compact)
                          Text(
                            '已读 $percent%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.green,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!compact && remainingMinutes != null) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '剩余约',
                        style: TextStyle(fontSize: 13, color: tokens.section),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$remainingMinutes',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: tokens.green,
                            ),
                          ),
                          Text(
                            ' 分钟',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 手机「最近阅读」细分隔线行。
class HomeRecentRow extends StatelessWidget {
  const HomeRecentRow({
    super.key,
    required this.title,
    required this.repo,
    required this.onTap,
  });

  final String title;
  final String repo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.divider)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 19, color: tokens.section),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: tokens.secondary,
                        ),
                      ),
                      TextSpan(
                        text: ' · $repo',
                        style: TextStyle(fontSize: 14.5, color: tokens.meta),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 平板「最近阅读」双列缩略卡。
class HomeRecentCard extends StatelessWidget {
  const HomeRecentCard({
    super.key,
    required this.title,
    required this.repo,
    required this.chapter,
    required this.timeLabel,
    required this.onTap,
  });

  final String title;
  final String repo;
  final String chapter;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.greenTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  chapter,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: tokens.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.title,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeLabel.isEmpty ? repo : '$repo · $timeLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: tokens.meta),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 仓库白卡：monogram + 标题（置顶角标）+ 元信息 + ⋮ + 箭头。
class HomeRepoCard extends StatelessWidget {
  const HomeRepoCard({
    super.key,
    required this.name,
    required this.pinned,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    this.source,
    this.lastOpened,
    this.syncedAt,
    this.fileCount,
    this.large = false,
  });

  final String name;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final String? source;
  final String? lastOpened;
  final DateTime? syncedAt;
  final int? fileCount;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final last = lastOpened;
    final fileName = last == null ? null : homeFileBase(last);
    final subtitleParts = <String>[
      if (syncedAt != null) '同步于 ${homeRelativeTime(syncedAt!)}',
      if (fileName != null) '最近 $fileName',
    ];
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(large ? 20 : 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(large ? 20 : 16),
        onTap: onTap,
        child: Container(
          padding: large
              ? const EdgeInsets.symmetric(horizontal: 22, vertical: 20)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(large ? 20 : 16),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              HomeMonogram(label: homeMonogram(name), size: large ? 56 : 40),
              SizedBox(width: large ? 18 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: large ? 19 : 15.5,
                              fontWeight: large
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: tokens.title,
                            ),
                          ),
                        ),
                        if (pinned) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.push_pin,
                            size: large ? 14 : 12,
                            color: tokens.pin,
                          ),
                        ],
                      ],
                    ),
                    if (large) ...[
                      if ((source ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            source!,
                            if (fileCount != null) '$fileCount 个文件',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: tokens.meta),
                        ),
                      ],
                      if (syncedAt != null || fileName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (syncedAt != null) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: tokens.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '已同步 · ${homeRelativeTime(syncedAt!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.green,
                                ),
                              ),
                            ],
                            if (syncedAt != null && fileName != null)
                              const SizedBox(width: 16),
                            if (fileName != null)
                              Flexible(
                                child: Text(
                                  '最近读 $fileName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.section,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ] else if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitleParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: tokens.meta),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                icon: Icon(Icons.more_vert, size: 20, color: tokens.section),
                onSelected: (value) {
                  switch (value) {
                    case 'pin':
                      onTogglePin();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(Icons.push_pin_outlined, size: 20),
                        SizedBox(width: 12),
                        Text(pinned ? '取消置顶' : '置顶仓库'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: tokens.red),
                        SizedBox(width: 12),
                        Text('删除仓库', style: TextStyle(color: tokens.red)),
                      ],
                    ),
                  ),
                ],
              ),
              Icon(Icons.chevron_right, size: 17, color: tokens.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

/// 本地文件夹白卡：绿 tint 图标章 + ⋮（刷新/移除）+ 箭头。
class HomeLocalCard extends StatelessWidget {
  const HomeLocalCard({
    super.key,
    required this.name,
    required this.onTap,
    required this.onRefresh,
    required this.onRemove,
    this.fileCount,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onRefresh;
  final VoidCallback onRemove;
  final int? fileCount;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.greenTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder_open, size: 22, color: tokens.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.title,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fileCount == null ? '本地文件夹' : '本地文件夹 · $fileCount 篇',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tokens.meta),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                icon: Icon(Icons.more_vert, size: 20, color: tokens.section),
                onSelected: (value) {
                  switch (value) {
                    case 'refresh':
                      onRefresh();
                    case 'remove':
                      onRemove();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.sync, size: 20),
                        SizedBox(width: 12),
                        Text('刷新镜像'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: tokens.red),
                        SizedBox(width: 12),
                        Text('移除文件夹', style: TextStyle(color: tokens.red)),
                      ],
                    ),
                  ),
                ],
              ),
              Icon(Icons.chevron_right, size: 17, color: tokens.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

/// 本地 Tab 的虚线「添加本地文件夹」卡（唯一添加入口）。
class HomeAddLocalCard extends StatelessWidget {
  const HomeAddLocalCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(color: tokens.border),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tokens.greenTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.create_new_folder_outlined,
                    size: 21,
                    color: tokens.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '添加本地文件夹',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tokens.secondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Markdown / Notebook',
                        style: TextStyle(fontSize: 12, color: tokens.meta),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.add, size: 20, color: tokens.green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 仓库 / 本地互斥切换器。
class HomeSegmentedTabs extends StatelessWidget {
  const HomeSegmentedTabs({
    super.key,
    required this.repoCount,
    required this.localCount,
    required this.localSelected,
    required this.onChanged,
  });

  final int repoCount;
  final int localCount;
  final bool localSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final repoLabel = repoCount > 0 ? '仓库 · $repoCount' : '仓库';
    final localLabel = localCount > 0 ? '本地文件夹 · $localCount' : '本地文件夹';
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.segment,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _SegmentItem(
            label: repoLabel,
            selected: !localSelected,
            onTap: () => onChanged(false),
          ),
          _SegmentItem(
            label: localLabel,
            selected: localSelected,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? tokens.card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected ? tokens.green : tokens.section,
            ),
          ),
        ),
      ),
    );
  }
}

/// 空态引导卡。 [dashed] 用于本地 Tab（与虚线添加入口一致）。
class HomeEmptyCard extends StatelessWidget {
  const HomeEmptyCard({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.auto_stories_outlined,
    this.actionLabel,
    this.onAction,
    this.dashed = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tokens.greenTint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 26, color: tokens.green),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.7, color: tokens.meta),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: TextStyle(color: tokens.green)),
            ),
          ],
        ],
      ),
    );
    return dashed
        ? CustomPaint(
            painter: _DashedBorderPainter(color: tokens.border),
            child: content,
          )
        : Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.border),
            ),
            child: content,
          );
  }
}

/// 平板横屏右栏「仓库内热门目录」卡。
class HomeHotDirectoryCard extends StatelessWidget {
  const HomeHotDirectoryCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.title,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tokens.meta),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: tokens.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeMonogram extends StatelessWidget {
  const HomeMonogram({super.key, required this.label, this.size = 40});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.green,
        borderRadius: BorderRadius.circular(size >= 50 ? 16 : 12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: size >= 50 ? 23 : 17,
          fontWeight: FontWeight.w700,
          color: tokens.paper,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.fraction,
    required this.height,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final double height;
  final Color track;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: track,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.clamp(0.0, 1.0),
          child: ColoredBox(color: fill),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  static const double _radius = 16;
  static const double _strokeWidth = 1.4;
  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + _dash, metric.length),
          ),
          paint,
        );
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
