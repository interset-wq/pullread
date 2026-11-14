import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../git/repo_meta.dart';
import '../git/sync_service.dart';
import '../local/local_folder_service.dart';
import '../notes/note_index.dart';
import '../notes/note_scanner.dart';
import '../platforms/git_platform.dart';
import '../platforms/repo_info.dart';
import '../platforms/repo_url.dart';
import '../theme/app_prefs.dart';
import '../utils/dir_size.dart' show formatBytes;
import 'bookmarks_page.dart';
import 'brand_splash.dart';
import 'desktop_shortcuts.dart';
import 'global_search_page.dart';
import 'home_feed.dart';
import 'books/books_home_page.dart';
import 'open_note.dart';
import 'pull_progress.dart';
import 'reader/split_reader_page.dart';
import 'repo_page.dart';
import 'settings/settings_page.dart';
import 'settings/theme_mode_selector.dart';
import 'tag_page.dart';
import 'updates_page.dart';

/// 首页：已克隆仓库卡片 + 添加仓库（克隆）。
/// 移动端优先：大卡片、下拉刷新、底部导航结构。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _sync = GitSyncService();
  List<Directory>? _repos;
  List<LocalFolder>? _localFolders;

  /// 本地文件夹的镜像根目录（与 [_localFolders] 同步刷新）。首页聚合、
  /// 全局搜索和续读卡都需要真实目录，提前解析好避免每帧 await。
  List<Directory> _localMirrors = const [];
  bool _cloning = false;
  bool _updatingAll = false;

  /// 各仓库/镜像里尚未读的「新增/更新」条目总数（更新收件箱的角标）。
  int _updateCount = 0;

  /// 仓库 / 本地文件夹互斥切换（默认仓库）。
  _HomeTab _tab = _HomeTab.repos;

  /// 底部导航：0 = 阅读（原有首页），1 = 电子书（用户书单）。
  int _footerTab = 0;

  Future<Directory> get _reposRoot async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}repos');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  @override
  void initState() {
    super.initState();
    _loadRepos();
    _loadLocals();
    _silentPullAll();
  }

  Future<void> _loadLocals() async {
    final folders = await LocalFolderService.listFolders();
    final mirrors = <Directory>[];
    for (final folder in folders) {
      try {
        mirrors.add(await LocalFolderService.mirrorDir(folder.name));
      } on Object {
        // 单个镜像目录不可用不影响其他来源
      }
    }
    if (!mounted) return;
    setState(() {
      _localFolders = folders;
      _localMirrors = mirrors;
    });
    unawaited(_refreshUpdateCount());
  }

  /// 重新统计更新收件箱的未读数（仓库 + 本地镜像的 recentChanges）。
  Future<void> _refreshUpdateCount() async {
    var total = 0;
    for (final dir in _repos ?? const <Directory>[]) {
      total += RepoMeta.readRecentChanges(dir.path).length;
    }
    for (final folder in _localFolders ?? const <LocalFolder>[]) {
      final dir = await LocalFolderService.mirrorDir(folder.name);
      total += RepoMeta.readRecentChanges(dir.path).length;
    }
    if (!mounted || total == _updateCount) return;
    setState(() => _updateCount = total);
  }

  /// 打开更新收件箱：一次性汇总所有来源的未读更新。
  Future<void> _openUpdates() async {
    final sources = <({String name, Directory root})>[];
    for (final dir in _repos ?? const <Directory>[]) {
      sources.add((
        name: dir.path.split(Platform.pathSeparator).last,
        root: dir,
      ));
    }
    for (final folder in _localFolders ?? const <LocalFolder>[]) {
      sources.add((
        name: folder.name,
        root: await LocalFolderService.mirrorDir(folder.name),
      ));
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => UpdatesPage(sources: sources)),
    );
    if (!mounted) return;
    await _refreshUpdateCount();
  }

  /// 添加本地文件夹（系统选择器授权 + 首次镜像）。
  Future<void> _addLocalFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final folder = await LocalFolderService.addFolder();
      if (folder != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('已添加「${folder.name}」')),
        );
      }
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('添加失败: $e')));
    }
    await _loadLocals();
  }

  /// 打开本地文件夹：先重镜像拿到最新内容，再进仓库页（复用）。
  Future<void> _openLocal(LocalFolder folder) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LocalFolderService.syncFolder(folder);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('刷新失败: $e')));
      // 镜像失败仍打开旧内容
    }
    final dir = await LocalFolderService.mirrorDir(folder.name);
    if (!mounted) return;
    // 增量同步会跳过「编辑器保存过但没写回源文件夹」的文件；这里明确
    // 提示，避免用户以为源文件夹已经是最新
    final pending = LocalFolderService.pendingCount(dir.path);
    if (pending > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$pending 个修改尚未写回原文件夹（设置 → 存储与数据 → 未写回的修改）',
          ),
        ),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RepoPage(repoDir: dir),
        settings: const RouteSettings(name: 'repo-root'),
      ),
    );
  }

  /// 仅重镜像（本地卡片上的刷新按钮）。
  Future<void> _syncLocal(LocalFolder folder) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LocalFolderService.syncFolder(folder);
      final dir = await LocalFolderService.mirrorDir(folder.name);
      final pending = LocalFolderService.pendingCount(dir.path);
      messenger.showSnackBar(
        SnackBar(
          content: Text(pending > 0 ? '已刷新；$pending 个修改尚未写回' : '已刷新'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('刷新失败: $e')));
    }
  }

  Future<void> _confirmRemoveLocal(LocalFolder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除本地文件夹'),
        content: Text(
          '将移除「${folder.name}」的访问授权与镜像，原文件夹不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LocalFolderService.removeFolder(folder);
    await _loadLocals();
  }

  /// 启动时后台静默更新所有仓库：不转圈、不弹提示，完成后仅刷新列表。
  /// 受设置「自动拉取同步」开关控制（默认关闭——下拉刷新即可手动同步）。
  Future<void> _silentPullAll() async {
    if (!(AppPrefs.instance?.silentPull ?? false)) return;
    // 等首轮仓库列表就绪再更新，避免与克隆/手动更新并发
    await _loadRepos();
    final repos = _repos;
    if (repos == null || repos.isEmpty) return;
    final sync = GitSyncService();
    for (final repo in repos) {
      try {
        final outcome = await sync.pull(repoDir: repo);
        RepoMeta.touchSynced(repo.path);
        if (outcome.result != PullResult.upToDate) {
          RepoMeta.setRecentChanges(repo.path, outcome.changes);
        }
      } on Exception {
        // 静默失败：离线时保持本地内容可用
      }
    }
    await _loadRepos();
  }

  /// 打开标签页：仓库 + 本地文件夹镜像一起聚合（跨来源）。
  Future<void> _openTags(List<Directory> repos) async {
    final roots = <Directory>[...repos];
    for (final folder in _localFolders ?? const <LocalFolder>[]) {
      roots.add(await LocalFolderService.mirrorDir(folder.name));
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => TagPage(roots: roots)),
    );
  }

  /// 全部收藏页（首页不再放横滑条，入口收进 ⋮ 菜单）。
  Future<void> _openStarred() async {
    final repos = _repos ?? const <Directory>[];
    final locals = _localMirrors;
    final entries = <HomeRecentEntry>[
      for (final (source, rel) in collectHomeStarred(repos, locals))
        HomeRecentEntry(
          source: source,
          relativePath: rel,
          isLocal: locals.any((dir) => dir.path == source.path),
        ),
    ];
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FileListPage(
          title: '收藏',
          emptyText: '还没有收藏',
          entries: entries,
          onOpen: _openRecentEntry,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// 全部书签页（跨仓库/本地文件夹）。
  Future<void> _openBookmarks() async {
    final sources = <BookmarkSource>[];
    for (final dir in _repos ?? const <Directory>[]) {
      sources.add(
        BookmarkSource(
          name: dir.path.split(Platform.pathSeparator).last,
          root: dir,
        ),
      );
    }
    for (final folder in _localFolders ?? const <LocalFolder>[]) {
      sources.add(
        BookmarkSource(
          name: folder.name,
          root: await LocalFolderService.mirrorDir(folder.name),
        ),
      );
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => BookmarksPage(sources: sources)),
    );
  }

  Future<void> _loadRepos() async {
    List<Directory> dirs;
    try {
      final root = await _reposRoot;
      dirs = root
          .listSync(followLinks: false)
          .whereType<Directory>()
          .where((d) => Directory('${d.path}${Platform.pathSeparator}.git')
              .existsSync())
          .toList();
    } on Object {
      // 取不到文档目录（权限异常/测试环境）时不要永远转圈，按空列表展示
      dirs = const [];
    }
    if (!mounted) return;
    // 置顶（仓库置顶）固定在最前，其余保持原顺序
    dirs.sort((a, b) {
      final pa = RepoMeta.isPinned(a.path) ? 0 : 1;
      final pb = RepoMeta.isPinned(b.path) ? 0 : 1;
      return pa.compareTo(pb);
    });
    setState(() => _repos = dirs);
    unawaited(_refreshUpdateCount());
  }

  void _showThemeSheet(AppPrefs prefs) {
    showThemeModeSheet(context, prefs);
  }

  @override
  Widget build(BuildContext context) {
    // 首屏仓库列表由 _loadRepos 直接读目录，通常一两帧内就绪。这里继续显示
    // 品牌闪屏（与 main.dart 的初始化页同一实现），而不是转圈。
    if (_repos == null) return const BrandSplash();
    final tokens = HomeTokens.of(context);
    final repos = _repos ?? const <Directory>[];
    final locals = _localFolders ?? const <LocalFolder>[];
    final recentsAll =
        collectHomeRecentEntries(repos, _localMirrors, limit: 50);
    final resume = _continueEntry(recentsAll);
    final recents = homeRecentsForDisplay(
      all: recentsAll,
      skip: resume?.entry,
      limit: 5,
    );
    final isLandscape = MediaQuery.sizeOf(context).width >= 1000;
    return DesktopShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _openGlobalSearch(repos, locals),
      },
      child: Scaffold(
        backgroundColor: tokens.paper,
        appBar: _footerTab != 0 || isLandscape
            ? null
            : _buildAppBar(tokens, repos, locals),
        floatingActionButton:
            _footerTab == 0 && _tab == _HomeTab.repos
                ? FloatingActionButton(
                    backgroundColor: tokens.green,
                    foregroundColor: tokens.paper,
                    onPressed: _cloning ? null : _showCloneDialog,
                    child: _cloning
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: tokens.paper,
                            ),
                          )
                        : const Icon(Icons.add),
                  )
                : null,
        body: _footerTab == 2
            ? AppPrefs.instance != null
                  ? SettingsPage(prefs: AppPrefs.instance!)
                  : const SizedBox.shrink()
            : _footerTab == 1
            ? BooksHomePage(
                sources: [...repos, ..._localMirrors],
              )
            : isLandscape
            ? _buildLandscape(
                context,
                tokens,
                repos,
                locals,
                resume,
                recents,
                recentsAll,
              )
            : _buildPortrait(
                context,
                tokens,
                repos,
                locals,
                resume,
                recents,
                recentsAll,
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _footerTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: '阅读',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories),
              label: '电子书',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
          onDestinationSelected: (index) =>
              setState(() => _footerTab = index),
        ),
      ),
    );
  }

  Future<void> _openSplitReader() async {
    final entries = collectHomeRecentEntries(
      _repos ?? const <Directory>[],
      _localMirrors,
      limit: 50,
    );
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有可多开的阅读记录')),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SplitReaderPage(candidates: entries),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openGlobalSearch(List<Directory> repos, List<LocalFolder> locals) {
    if (repos.isEmpty && locals.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            GlobalSearchPage(repos: repos, locals: _localMirrors),
      ),
    );
  }

  AppBar _buildAppBar(
    HomeTokens tokens,
    List<Directory> repos,
    List<LocalFolder> locals,
  ) {
    return AppBar(
      backgroundColor: tokens.paper,
      surfaceTintColor: Colors.transparent,
      // 滚动后 header 与内容同色无边界，缺少区分度（用户反馈）：
      // 3dp scrolled 阴影明确「header 浮在内容之上」，静止时保持无边界
      scrolledUnderElevation: 3,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: tokens.icon),
      title: Image.asset('assets/icon/app_logo.png', width: 34, height: 34),
      actions: _headerActions(tokens, repos, locals, includeOverflow: true),
    );
  }

  List<Widget> _headerActions(
    HomeTokens tokens,
    List<Directory> repos,
    List<LocalFolder> locals, {
    required bool includeOverflow,
  }) {
    return [
      IconButton(
        tooltip: '多开阅读',
        icon: const Icon(Icons.vertical_split_outlined),
        onPressed: (repos.isEmpty && locals.isEmpty) ? null : _openSplitReader,
      ),
      IconButton(
        tooltip: '搜索全部仓库和本地文件夹',
        icon: const Icon(Icons.search),
        onPressed: repos.isEmpty && locals.isEmpty
            ? null
            : () => _openGlobalSearch(repos, locals),
      ),
      IconButton(
        tooltip: '更新收件箱',
        icon: Badge(
          isLabelVisible: _updateCount > 0,
          backgroundColor: tokens.red,
          textColor: Colors.white,
          label: Text(_updateCount > 99 ? '99+' : '$_updateCount'),
          child: const Icon(Icons.inbox_outlined),
        ),
        onPressed: (repos.isEmpty && locals.isEmpty) ? null : _openUpdates,
      ),
      if (_updatingAll)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      if (includeOverflow) _buildOverflow(tokens, repos, locals),
    ];
  }

  Widget _buildOverflow(
    HomeTokens tokens,
    List<Directory> repos,
    List<LocalFolder> locals,
  ) {
    return PopupMenuButton<String>(
      tooltip: '更多',
      icon: Icon(Icons.more_vert, color: tokens.icon),
      onSelected: (value) {
        final prefs = AppPrefs.instance;
        switch (value) {
          case 'tags':
            _openTags(repos);
          case 'starred':
            _openStarred();
          case 'bookmarks':
            _openBookmarks();
          case 'sync':
            _pullAll();
          case 'theme':
            if (prefs != null) _showThemeSheet(prefs);
          case 'settings':
            if (prefs != null) {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SettingsPage(prefs: prefs),
                ),
              );
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'tags',
          enabled: !(repos.isEmpty && locals.isEmpty),
          child: const Row(
            children: [
              Icon(Icons.sell_outlined, size: 20),
              SizedBox(width: 12),
              Text('标签'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'starred',
          enabled: !(repos.isEmpty && locals.isEmpty),
          child: const Row(
            children: [
              Icon(Icons.star_outline_rounded, size: 20),
              SizedBox(width: 12),
              Text('收藏'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'bookmarks',
          enabled: !(repos.isEmpty && locals.isEmpty),
          child: const Row(
            children: [
              Icon(Icons.bookmark_outline, size: 20),
              SizedBox(width: 12),
              Text('书签'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sync',
          enabled: !(_cloning || _updatingAll || _repos == null),
          child: Row(
            children: [
              const Icon(Icons.cloud_sync_outlined, size: 20),
              const SizedBox(width: 12),
              Text(_updatingAll ? '正在更新…' : '全部更新'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'theme',
          enabled: AppPrefs.instance != null,
          child: const Row(
            children: [
              Icon(Icons.brightness_auto, size: 20),
              SizedBox(width: 12),
              Text('主题'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          enabled: AppPrefs.instance != null,
          child: const Row(
            children: [
              Icon(Icons.settings_outlined, size: 20),
              SizedBox(width: 12),
              Text('设置'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortrait(
    BuildContext context,
    HomeTokens tokens,
    List<Directory> repos,
    List<LocalFolder> locals,
    _ContinueTarget? resume,
    List<HomeRecentEntry> recents,
    List<HomeRecentEntry> recentsAll,
  ) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = isTablet
            ? math.min(constraints.maxWidth, 720.0)
            : constraints.maxWidth;
        final horizontal = isTablet ? 24.0 : 20.0;
        final innerWidth = contentWidth - horizontal * 2;
        // 内容列限宽但滚动条贴边：ListView 铺满全宽，内容用 padding 缩进，
        // 否则桌面滚动条贴着限宽列的内缘而不是窗口边缘
        final sideInset = math.max(
          horizontal,
          (constraints.maxWidth - contentWidth) / 2 + horizontal,
        );
        return RefreshIndicator(
          onRefresh: _loadRepos,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(sideInset, 6, sideInset, 96),
            children: [
              if (resume != null)
                isTablet
                    ? HomeContinueHero(
                        title: resume.entry.fileName,
                        repo: _sourceLabel(resume.entry),
                        fraction: resume.fraction,
                        headingIndex: resume.headingIndex,
                        remainingMinutes: resume.remainingMinutes,
                        onTap: () => _openRecentEntry(resume.entry),
                      )
                    : HomeContinueRow(
                        title: resume.entry.fileName,
                        repo: _sourceLabel(resume.entry),
                        fraction: resume.fraction,
                        onTap: () => _openRecentEntry(resume.entry),
                      ),
              if (recents.isNotEmpty) ...[
                if (resume != null) const SizedBox(height: 6),
                HomeSectionHeader(
                  title: '最近阅读',
                  onAction: recentsAll.isEmpty
                      ? null
                      : () => _openAllRecents(recentsAll),
                ),
                if (isTablet)
                  ..._recentGrid(recents, innerWidth)
                else
                  for (final entry in recents)
                    HomeRecentRow(
                      title: entry.fileName,
                      repo: _sourceLabel(entry),
                      onTap: () => _openRecentEntry(entry),
                    ),
              ],
              const SizedBox(height: 16),
              HomeSegmentedTabs(
                repoCount: repos.length,
                localCount: locals.length,
                localSelected: _tab == _HomeTab.locals,
                onChanged: (local) => setState(
                  () => _tab = local ? _HomeTab.locals : _HomeTab.repos,
                ),
              ),
              const SizedBox(height: 12),
              ..._tabContent(
                repos,
                locals,
                isTablet: isTablet,
                contentWidth: innerWidth,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLandscape(
    BuildContext context,
    HomeTokens tokens,
    List<Directory> repos,
    List<LocalFolder> locals,
    _ContinueTarget? resume,
    List<HomeRecentEntry> recents,
    List<HomeRecentEntry> recentsAll,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final leftWidth =
            (constraints.maxWidth * 0.36).clamp(340.0, 440.0);
        final rightWidth = constraints.maxWidth - leftWidth - 1;
        return SafeArea(
          top: true,
          child: Row(
            children: [
              SizedBox(
                width: leftWidth,
                child: _buildLeftPane(
                  tokens,
                  repos,
                  locals,
                  resume,
                  recents,
                  recentsAll,
                ),
              ),
              Container(width: 1, color: tokens.heroDivider),
              Expanded(
                child: _buildRightPane(
                  tokens,
                  repos,
                  locals,
                  rightWidth - 56,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeftPane(
    HomeTokens tokens,
    List<Directory> repos,
    List<LocalFolder> locals,
    _ContinueTarget? resume,
    List<HomeRecentEntry> recents,
    List<HomeRecentEntry> recentsAll,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 16, 10),
          child: Row(
            children: [
              Image.asset(
                'assets/icon/app_logo.png',
                width: 34,
                height: 34,
              ),
              const Spacer(),
              ..._headerActions(
                tokens,
                repos,
                locals,
                includeOverflow: false,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRepos,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 96),
              children: [
                if (resume != null) ...[
                  HomeContinueHero(
                    title: resume.entry.fileName,
                    repo: _sourceLabel(resume.entry),
                    fraction: resume.fraction,
                    headingIndex: resume.headingIndex,
                    compact: true,
                    onTap: () => _openRecentEntry(resume.entry),
                  ),
                  const SizedBox(height: 16),
                ],
                if (recents.isNotEmpty) ...[
                  HomeSectionHeader(
                    title: '最近阅读',
                    onAction: recentsAll.isEmpty
                        ? null
                        : () => _openAllRecents(recentsAll),
                  ),
                  for (final entry in recents)
                    HomeRecentRow(
                      title: entry.fileName,
                      repo: _sourceLabel(entry),
                      onTap: () => _openRecentEntry(entry),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPane(
    HomeTokens tokens,
    List<Directory> repos,
    List<LocalFolder> locals,
    double contentWidth,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: math.min(contentWidth, 380),
                child: HomeSegmentedTabs(
                  repoCount: repos.length,
                  localCount: locals.length,
                  localSelected: _tab == _HomeTab.locals,
                  onChanged: (local) => setState(
                    () => _tab = local ? _HomeTab.locals : _HomeTab.repos,
                  ),
                ),
              ),
              const Spacer(),
              _buildOverflow(tokens, repos, locals),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: _tabContent(
                repos,
                locals,
                isTablet: true,
                contentWidth: contentWidth,
                landscape: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _tabContent(
    List<Directory> repos,
    List<LocalFolder> locals, {
    required bool isTablet,
    required double contentWidth,
    bool landscape = false,
  }) {
    if (_tab == _HomeTab.repos) {
      if (repos.isEmpty) {
        return [
          HomeEmptyCard(
            title: '还没有仓库',
            body: landscape
                ? '右上角 + 添加一个仓库，开始离线阅读。'
                : '点右下角 + 添加一个仓库，开始离线阅读。',
            icon: Icons.folder_special_outlined,
            actionLabel: '添加仓库',
            onAction: _showCloneDialog,
          ),
        ];
      }
      final single = repos.length == 1;
      if (isTablet && single) {
        final repo = repos.first;
        final children = <Widget>[
          _repoCard(repo, large: true),
        ];
        if (landscape) {
          final hot = _hotDirectories(repo);
          if (hot.isNotEmpty) {
            children.add(const SizedBox(height: 20));
            children.add(const HomeSectionHeader(title: '仓库内热门目录'));
            children.add(const SizedBox(height: 10));
            children.add(
              _twoColumn(
                width: contentWidth,
                gap: 12,
                children: [
                  for (final dir in hot)
                    HomeHotDirectoryCard(
                      name: dir.name,
                      subtitle: '${dir.count} 篇 · 最近 ${dir.recentFile}',
                      onTap: () => _openHotDirectory(repo, dir.name),
                    ),
                ],
              ),
            );
          }
          children.add(const SizedBox(height: 16));
          children.add(
            HomeEmptyCard(
              title: '想读点新的？',
              body: '右上角 + 添加一个仓库，或切到「本地文件夹」打开本地笔记。',
              icon: Icons.auto_stories_outlined,
              actionLabel: '添加仓库',
              onAction: _showCloneDialog,
            ),
          );
        }
        return children;
      }
      if (isTablet) {
        return [
          _twoColumn(
            width: contentWidth,
            gap: 10,
            children: [
              for (final repo in repos) _repoCard(repo, large: false),
            ],
          ),
        ];
      }
      return [
        for (final repo in repos) ...[
          _repoCard(repo, large: false),
          const SizedBox(height: 10),
        ],
      ];
    }

    final children = <Widget>[];
    if (locals.isEmpty) {
      children.add(
        HomeEmptyCard(
          title: '还没有本地文件夹',
          body: '选择手机或电脑上的 Markdown 文件夹，授权后即可离线阅读。',
          icon: Icons.folder_open,
        ),
      );
      children.add(const SizedBox(height: 10));
    }
    if (isTablet && locals.isNotEmpty) {
      children.add(
        _twoColumn(
          width: contentWidth,
          gap: 10,
          children: [
            for (final folder in locals) _localCard(folder),
          ],
        ),
      );
      children.add(const SizedBox(height: 10));
    } else {
      for (final folder in locals) {
        children.add(_localCard(folder));
        children.add(const SizedBox(height: 10));
      }
    }
    children.add(HomeAddLocalCard(onTap: _addLocalFolder));
    return children;
  }

  Widget _twoColumn({
    required double width,
    required double gap,
    required List<Widget> children,
  }) {
    final itemWidth = math.max(0.0, (width - gap) / 2);
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      alignment: WrapAlignment.start,
      children: [
        for (final child in children) SizedBox(width: itemWidth, child: child),
      ],
    );
  }

  List<Widget> _recentGrid(List<HomeRecentEntry> recents, double width) {
    const gap = 12.0;
    return [
      const SizedBox(height: 10),
      _twoColumn(
        width: width,
        gap: gap,
        children: [
          for (final entry in recents)
            HomeRecentCard(
              title: entry.fileName,
              repo: _sourceLabel(entry),
              chapter: homeChapterLabel(entry.relativePath),
              timeLabel: homeRecentTimeLabel(entry.at),
              onTap: () => _openRecentEntry(entry),
            ),
        ],
      ),
    ];
  }

  HomeRepoCard _repoCard(Directory repo, {required bool large}) {
    final name = repo.path.split(Platform.pathSeparator).last;
    final meta = RepoMeta.read(repo.path);
    return HomeRepoCard(
      name: name,
      source: meta?.source,
      lastOpened: meta?.lastOpened,
      syncedAt: meta?.syncedAt,
      pinned: RepoMeta.isPinned(repo.path),
      fileCount: large ? NoteIndexCache.read(repo.path)?.length : null,
      large: large,
      onTap: () => _openRepo(repo),
      onTogglePin: () {
        RepoMeta.togglePin(repo.path);
        _loadRepos();
      },
      onDelete: () => _confirmDelete(repo),
    );
  }

  HomeLocalCard _localCard(LocalFolder folder) {
    final mirror = _mirrorFor(folder.name);
    return HomeLocalCard(
      name: folder.name,
      fileCount:
          mirror == null ? null : NoteIndexCache.read(mirror.path)?.length,
      onTap: () => _openLocal(folder),
      onRefresh: () => _syncLocal(folder),
      onRemove: () => _confirmRemoveLocal(folder),
    );
  }

  Directory? _mirrorFor(String name) {
    for (final dir in _localMirrors) {
      if (dir.path.split(Platform.pathSeparator).last == name) return dir;
    }
    return null;
  }

  String _sourceLabel(HomeRecentEntry entry) =>
      entry.isLocal ? '本地 · ${entry.repoName}' : entry.repoName;

  /// 「继续阅读」候选：最近阅读里第一篇文章，且进度在 (2%, 98%) 之间
  /// （刚开始读的 0% 和已读完的不值得单独占一栏）。
  _ContinueTarget? _continueEntry(List<HomeRecentEntry> recents) {
    for (final entry in recents) {
      final (fraction, heading) = RepoMeta.readProgressInfo(
        entry.source.path,
        entry.relativePath,
      );
      if (fraction <= 0.02 || fraction >= 0.98) continue;
      final file = File(
        '${entry.source.path}${Platform.pathSeparator}'
        '${entry.relativePath.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!file.existsSync()) continue;
      return _ContinueTarget(
        entry: entry,
        fraction: fraction,
        headingIndex: heading,
        remainingMinutes: estimateRemainingMinutes(
          file.statSync().size,
          fraction,
        ),
      );
    }
    return null;
  }

  List<_HotDirectory> _hotDirectories(Directory repo) {
    final files = NoteIndexCache.read(repo.path);
    if (files == null || files.isEmpty) return const [];
    final counts =
        <String, ({int count, String recent, DateTime modified})>{};
    for (final file in files) {
      final parts = file.relativePath.split('/');
      if (parts.length < 2 || parts.first.isEmpty) continue;
      final dir = parts.first;
      final base = parts.last;
      final prev = counts[dir];
      if (prev == null) {
        counts[dir] = (
          count: 1,
          recent: base,
          modified: file.modified,
        );
      } else if (file.modified.isAfter(prev.modified)) {
        counts[dir] = (
          count: prev.count + 1,
          recent: base,
          modified: file.modified,
        );
      } else {
        counts[dir] = (
          count: prev.count + 1,
          recent: prev.recent,
          modified: prev.modified,
        );
      }
    }
    final dirs = [
      for (final entry in counts.entries)
        _HotDirectory(
          name: entry.key,
          count: entry.value.count,
          recentFile: entry.value.recent,
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return dirs.take(4).toList();
  }

  Future<void> _openAllRecents(List<HomeRecentEntry> entries) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FileListPage(
          title: '最近阅读',
          emptyText: '还没有阅读记录',
          entries: entries,
          onOpen: _openRecentEntry,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openHotDirectory(Directory repo, String subPath) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RepoPage(repoDir: repo, subPath: subPath),
        settings: const RouteSettings(name: 'repo-root'),
      ),
    );
    if (!mounted) return;
    await _refreshUpdateCount();
  }

  void _openRecentEntry(HomeRecentEntry entry) {
    _openRecentFile(entry.source, entry.relativePath);
  }
  /// 打开最近阅读的文章（统一走 [openNoteFile]：清除更新标记、记录最近打开；
  /// 文件已删除时忽略）。
  Future<void> _openRecentFile(Directory repo, String relPath) async {
    final file = File(
      '${repo.path}${Platform.pathSeparator}'
      '${relPath.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!file.existsSync()) return;
    final stat = file.statSync();
    await openNoteFile(
      context,
      repoRoot: repo.path,
      note: NoteFile(
        relativePath: relPath,
        absolutePath: file.path,
        modified: stat.modified,
        sizeBytes: stat.size,
      ),
    );
    // 阅读页会更新进度：回到首页刷新「继续阅读」与「最近阅读」
    if (mounted) setState(() {});
  }

  Future<void> _openRepo(Directory repoDir) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RepoPage(repoDir: repoDir),
        settings: const RouteSettings(name: 'repo-root'),
      ),
    );
    if (!mounted) return;
    // 仓库页里打开文件会清掉更新标记、拉取会新增标记
    await _refreshUpdateCount();
  }

  Future<void> _confirmDelete(Directory repo) async {
    final name = repo.path.split(Platform.pathSeparator).last;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除仓库'),
        content: Text('将从本地删除 $name 及其全部内容，远端仓库不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final root = await _reposRoot;
      await _sync.deleteRepo(repo.path, reposRoot: root.path);
      RepoMeta.remove(repo.path);
      NoteIndexCache.remove(repo.path);
      await _loadRepos();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  /// 顺序 pull 所有本地仓库，汇总结果提示。
  Future<void> _pullAll() async {
    final repos = _repos;
    if (repos == null || repos.isEmpty) return;
    setState(() => _updatingAll = true);
    var updated = 0;
    var failed = 0;
    final sync = GitSyncService();
    try {
      await runWithPullProgress<void>(
        context,
        title: '正在更新全部仓库',
        action: (onProgress) async {
          for (var i = 0; i < repos.length; i++) {
            final repo = repos[i];
            final name = repo.path.split(Platform.pathSeparator).last;
            final label = '(${i + 1}/${repos.length}) $name';
            onProgress(label, null);
            try {
              final outcome = await sync.pull(
                repoDir: repo,
                onProgress: (p) => onProgress(label, p),
              );
              RepoMeta.touchSynced(repo.path);
              if (outcome.result != PullResult.upToDate) {
                RepoMeta.setRecentChanges(repo.path, outcome.changes);
                updated++;
              }
            } on Exception {
              failed++;
            }
          }
        },
      );
      await _loadRepos();
    } finally {
      if (mounted) {
        setState(() => _updatingAll = false);
        final msg = failed > 0
            ? '更新完成：$updated 个有更新，$failed 个失败'
            : updated > 0
                ? '已更新 $updated 个仓库'
                : '所有仓库均已是最新';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  /// 解析克隆输入：完整 URL 原样返回；
  /// `owner/repo` / `repo` 按设置的默认平台与用户名拼接完整地址。
  String? _resolveCloneUrl(String input, AppPrefs prefs) {
    final v = input.trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    final parts = v.split('/').where((e) => e.isNotEmpty).toList();
    final owner = switch (parts.length) {
      2 => parts[0],
      1 => prefs.defaultOwner,
      _ => null,
    };
    final repo = parts.last;
    if (owner == null || owner.isEmpty || repo.isEmpty) return null;
    // 「其他」平台没有可拼接的域名（自建 Gitea 等必须给完整 URL）
    if (prefs.platform.webBase.isEmpty) return null;
    return '${prefs.platform.webBase}/$owner/$repo.git';
  }

  /// 仓库地址匹配（剪贴板快速导入）：任意域名下的 `host/owner/repo`，
  /// 不限于内置平台——自建 Gitea / GitLab 的完整 URL 也能直接导入。
  static final RegExp _repoUrlRegExp = RegExp(
    r'https?://(?:www\.)?[^\s/]+/[\w.\-]+/[\w.\-]+',
    caseSensitive: false,
  );

  /// 剪贴板快速导入（剪贴板导入）：克隆页打开时读取剪贴板，
  /// 内容是仓库地址（完整 URL 或 `owner/repo` 短格式）则自动填充；
  /// 识别失败静默不打扰。
  Future<void> _prefillFromClipboard(TextEditingController ctrl) async {
    try {
      final text = (await Clipboard.getData('text/plain'))?.text?.trim();
      if (text == null || text.isEmpty || text.length > 500) return;
      final isUrl = text.startsWith('http://') || text.startsWith('https://');
      final ok = isUrl
          ? _repoUrlRegExp.hasMatch(text)
          : RegExp(r'^[\w.\-]+/[\w.\-]+$').hasMatch(text);
      if (!ok) return;
      ctrl.text = text;
    } catch (_) {
      // 剪贴板不可用（部分设备权限受限）时静默跳过
    }
  }

  Future<void> _showCloneDialog() async {
    final urlCtrl = TextEditingController();
    final prefs = AppPrefs.instance;
    unawaited(_prefillFromClipboard(urlCtrl));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加仓库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: '仓库地址',
                hintText: 'notes · owner/notes · https://…',
                helperText: prefs == null
                    ? null
                    : '仅输仓库名时按 ${prefs.platform.displayName} / '
                        '${prefs.defaultOwner.isEmpty ? '<默认用户名>' : prefs.defaultOwner} 拼接'
                        '（可在设置中修改）',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('克隆'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    final url = prefs == null
        ? urlCtrl.text.trim()
        : _resolveCloneUrl(urlCtrl.text, prefs);
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法解析地址：可输入完整 URL、用户名/仓库名，'
              '或在设置中先填写默认用户名'),
        ),
      );
      return;
    }
    final parsed = parseRepoUrl(url);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法识别仓库地址：仓库名不能为空、不能以点开头，'
              '也不能包含路径分隔符等非法字符'),
        ),
      );
      return;
    }
    final info = RepoInfo(
      platform: guessPlatform(url),
      owner: parsed.owner,
      name: parsed.name,
      cloneUrl: url,
    );
    setState(() => _cloning = true);
    final rootNav = Navigator.of(context, rootNavigator: true);
    var busyClosed = false;
    void closeBusy() {
      if (busyClosed) return;
      busyClosed = true;
      rootNav.pop();
    }

    // 进度对话框：对象传输阶段显示百分比与已下载体积，可取消
    final cancelToken = CloneCancelToken();
    final progress = ValueNotifier<CloneProgress?>(null);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: ValueListenableBuilder<CloneProgress?>(
            valueListenable: progress,
            builder: (dialogContext, p, _) {
              final fraction = p?.fraction;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('正在克隆仓库…'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: fraction),
                  const SizedBox(height: 8),
                  Text(
                    p == null
                        ? '连接中…'
                        : fraction == null
                            ? formatBytes(p.receivedBytes)
                            : '${p.receivedObjects} / ${p.totalObjects} 个对象 · '
                                '${formatBytes(p.receivedBytes)}',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: cancelToken.cancel,
                      child: const Text('取消'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    try {
      await _sync.clone(
        repo: info,
        parentDir: await _reposRoot,
        onProgress: (p) {
          if (!busyClosed) progress.value = p;
        },
        cancelToken: cancelToken,
      );
      final root = await _reposRoot;
      final clonePath = '${root.path}${Platform.pathSeparator}${info.name}';
      RepoMeta.writeClone(
        clonePath,
        url: url,
        branch: GitSyncService.readHeadBranch(clonePath),
      );
      await _loadRepos();
      closeBusy();
    } on TimeoutException {
      closeBusy();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('克隆超时：请检查手机网络（Wi-Fi DNS / 移动数据）后重试'),
            duration: Duration(seconds: 6),
          ),
        );
      }
    } on SyncException catch (e) {
      closeBusy();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message == '已取消克隆' ? '已取消克隆' : '克隆失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      if (e.message == '已取消克隆') {
        // 孤儿 isolate 会在原生克隆自然返回后退出；在后台等它清理完
        // 半成品目录再刷新列表，不阻塞 UI（加号按钮由 finally 立即复位，
        // 重试克隆前 clone() 也会隐式等待清理完成）
        unawaited(
          () async {
            final root = await _reposRoot;
            await GitSyncService.waitForCleanup(
              '${root.path}${Platform.pathSeparator}${info.name}',
            );
            if (mounted) await _loadRepos();
          }(),
        );
      }
    } on Exception catch (e) {
      closeBusy();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('克隆失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _cloning = false);
    }
  }
}

enum _HomeTab { repos, locals }

/// 「继续阅读」候选：最近阅读条目 + 进度信息。
class _ContinueTarget {
  const _ContinueTarget({
    required this.entry,
    required this.fraction,
    this.headingIndex,
    this.remainingMinutes,
  });

  final HomeRecentEntry entry;
  final double fraction;
  final int? headingIndex;
  final int? remainingMinutes;
}

/// 仓库内热门目录（来自 note_index 的真实扫描计数）。
class _HotDirectory {
  const _HotDirectory({
    required this.name,
    required this.count,
    required this.recentFile,
  });

  final String name;
  final int count;
  final String recentFile;
}

/// 跨来源文件列表页（最近阅读 / 收藏共用）。
class _FileListPage extends StatelessWidget {
  const _FileListPage({
    required this.title,
    required this.emptyText,
    required this.entries,
    required this.onOpen,
  });

  final String title;
  final String emptyText;
  final List<HomeRecentEntry> entries;
  final void Function(HomeRecentEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        surfaceTintColor: Colors.transparent,
        // 与主 header 一致：滚动后 3dp 阴影，明确浮在内容之上
        scrolledUnderElevation: 3,
        elevation: 0,
        iconTheme: IconThemeData(color: tokens.icon),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: tokens.title,
          ),
        ),
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                emptyText,
                style: TextStyle(fontSize: 13.5, color: tokens.meta),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return HomeRecentRow(
                  title: entry.fileName,
                  repo: entry.isLocal
                      ? '本地 · ${entry.repoName}'
                      : entry.repoName,
                  onTap: () => onOpen(entry),
                );
              },
            ),
    );
  }
}
