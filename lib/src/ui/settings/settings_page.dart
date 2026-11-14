import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../local/local_folder_service.dart';
import '../../theme/app_prefs.dart';
import 'about_page.dart';
import 'appearance_settings_page.dart';
import 'data_settings_page.dart';
import 'file_display_settings_page.dart';
import 'reading_settings_page.dart';
import 'repo_settings_page.dart';
import 'settings_components.dart';
import 'settings_search.dart';
import 'theme_mode_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.prefs, super.key});

  final AppPrefs prefs;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const double _twoPaneMinWidth = 1000;
  static const double _categoryPaneWidth = 340;

  int _pendingCount = 0;
  String? _version;
  int _selectedCategory = 0;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    var pendingCount = 0;
    try {
      pendingCount = (await LocalFolderService.allPending()).length;
    } on Object {
      pendingCount = 0;
    }
    String? version;
    try {
      final info = await const MethodChannel('app_icon')
          .invokeMethod<Map<Object?, Object?>>('getInfo')
          .timeout(const Duration(seconds: 3));
      version = info?['versionName']?.toString();
    } on Object {
      version = null;
    }
    if (!mounted) return;
    setState(() {
      _pendingCount = pendingCount;
      _version = version;
    });
  }

  Future<void> _refreshPending() async {
    var pendingCount = 0;
    try {
      pendingCount = (await LocalFolderService.allPending()).length;
    } on Object {
      pendingCount = 0;
    }
    if (!mounted) return;
    setState(() => _pendingCount = pendingCount);
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = Platform.isAndroid;
    final prefs = widget.prefs;
    final categories = <_SettingsCategory>[
      _SettingsCategory(
        icon: Icons.menu_book_outlined,
        title: '阅读与显示',
        subtitle: '行距、边距与代码块',
        tone: SettingsTone.pine,
        value: '${prefs.lineHeight.toStringAsFixed(2)} / ${prefs.pageMargin.round()} dp',
        page: ReadingSettingsPage(prefs: prefs),
      ),
      _SettingsCategory(
        icon: Icons.palette_outlined,
        title: '外观与图标',
        subtitle: isAndroid ? '主题与桌面图标' : '主题',
        tone: SettingsTone.pine,
        value: themeModeLabel(prefs.mode),
        page: AppearanceSettingsPage(prefs: prefs),
      ),
      _SettingsCategory(
        icon: Icons.cloud_sync_outlined,
        title: '仓库与同步',
        subtitle: '平台、用户名与同步',
        tone: SettingsTone.pine,
        value: prefs.platform.displayName,
        page: RepoSettingsPage(prefs: prefs),
      ),
      _SettingsCategory(
        icon: Icons.visibility_off_outlined,
        title: '文件显示',
        subtitle: '隐藏默认项与自定义规则',
        tone: SettingsTone.pine,
        value: '${prefs.ignoreRules.length} 条规则',
        page: FileDisplaySettingsPage(prefs: prefs),
      ),
      _SettingsCategory(
        icon: Icons.storage_outlined,
        title: '存储与数据',
        subtitle: '占用、待写回、历史与收藏',
        tone: SettingsTone.pine,
        badgeCount: _pendingCount,
        page: DataSettingsPage(prefs: prefs),
      ),
      _SettingsCategory(
        icon: Icons.info_outline,
        title: '关于 PullRead',
        subtitle: '版本、许可证与项目主页',
        tone: SettingsTone.pine,
        value: _version == null ? null : 'v$_version',
        page: const AboutPage(),
      ),
    ];
    return AnimatedBuilder(
      animation: widget.prefs,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final twoPane = constraints.maxWidth >= _twoPaneMinWidth;
            if (twoPane) {
              return Scaffold(
                body: SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _categoryPaneWidth,
                        child: _CategoryPane(
                          categories: categories,
                          selectedIndex: _selectedCategory,
                          onSelect: (index) {
                            setState(() => _selectedCategory = index);
                            if (categories[index].badgeCount != null) {
                              _refreshPending();
                            }
                          },
                          onSearch: () =>
                              _push(SettingsSearchPage(prefs: widget.prefs)),
                          footer: Text(
                            'PullRead · 克隆一次，常读常新',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: KeyedSubtree(
                          key: ValueKey(_selectedCategory),
                          // 独立 Navigator：嵌入页无返回箭头，子页推进留在右栏内
                          child: Navigator(
                            onGenerateRoute: (settings) => MaterialPageRoute<
                                void>(
                              builder: (_) => categories[_selectedCategory].page,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: const Text('设置'),
                actions: [
                  IconButton(
                    tooltip: '搜索设置',
                    icon: const Icon(Icons.search),
                    onPressed: () =>
                        _push(SettingsSearchPage(prefs: widget.prefs)),
                  ),
                ],
              ),
              body: SettingsBody(
                children: [
                  SettingsSection(
                    children: [
                      for (final (index, category) in categories.indexed)
                        SettingsNavTile(
                          icon: category.icon,
                          title: category.title,
                          subtitle: category.subtitle,
                          value: category.value,
                          tone: category.tone,
                          badgeCount: category.badgeCount ?? 0,
                          onTap: () {
                            _selectedCategory = index;
                            if (category.badgeCount != null) {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          DataSettingsPage(prefs: prefs),
                                    ),
                                  )
                                  .then((_) => _refreshPending());
                              return;
                            }
                            _push(category.page);
                          },
                        ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Text(
                      'PullRead · 克隆一次，常读常新',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SettingsCategory {
  const _SettingsCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.page,
    this.value,
    this.badgeCount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final SettingsTone tone;
  final String? value;
  final int? badgeCount;
  final Widget page;
}

/// 横屏（≥1000dp）左侧类别栏：当前项松绿实底白字（docs/ui/settings-redesign.md）
class _CategoryPane extends StatelessWidget {
  const _CategoryPane({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSearch,
    required this.footer,
  });

  final List<_SettingsCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paneColor = theme.brightness == Brightness.dark
        ? const Color(0xFF23211C)
        : const Color(0xFFF4F2EB);
    return ColoredBox(
      color: paneColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 20, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '设置',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '搜索设置',
                  icon: const Icon(Icons.search),
                  onPressed: onSearch,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final (index, category) in categories.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Material(
                      // 规范 token：当前类别实底松绿 + 白字（两种明暗一致）
                      color: index == selectedIndex
                          ? const Color(0xFF1F6F54)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelect(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              index == selectedIndex
                                  ? Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(41),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        category.icon,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    )
                                  : SettingsIconTile(
                                      icon: category.icon,
                                      tone: category.tone,
                                    ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: index == selectedIndex
                                            ? Colors.white
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      category.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: index == selectedIndex
                                            ? Colors.white.withAlpha(191)
                                            : theme
                                                .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if ((category.badgeCount ?? 0) > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.error,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${category.badgeCount}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onError,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 26),
            child: Center(child: footer),
          ),
        ],
      ),
    );
  }
}
