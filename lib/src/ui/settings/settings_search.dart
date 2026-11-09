import 'package:flutter/material.dart';

import '../../theme/app_prefs.dart';
import 'appearance_settings_page.dart';
import 'data_settings_page.dart';
import 'file_display_settings_page.dart';
import 'reading_settings_page.dart';
import 'repo_settings_page.dart';

/// 设置搜索可跳转的页面。
enum SettingsTarget { reading, appearance, repo, fileDisplay, data }

/// 一条可被搜索的设置项。`anchor` 与子页里的 [SettingsAnchor.id] 对应。
class SettingsEntry {
  const SettingsEntry({
    required this.title,
    required this.section,
    required this.target,
    required this.anchor,
    required this.icon,
    this.aliases = const [],
  });

  final String title;
  final String section;
  final SettingsTarget target;
  final String anchor;
  final IconData icon;

  /// 别名覆盖口语、英文和常见同义词，例如「行距 / 行高 / 紧凑」。
  final List<String> aliases;

  String get pageTitle => switch (target) {
    SettingsTarget.reading => '阅读与显示',
    SettingsTarget.appearance => '外观与图标',
    SettingsTarget.repo => '仓库与同步',
    SettingsTarget.fileDisplay => '文件显示',
    SettingsTarget.data => '存储与数据',
  };

  String get breadcrumb => '$pageTitle · $section';

  Iterable<String> get searchable sync* {
    yield title;
    yield section;
    yield pageTitle;
    yield* aliases;
  }
}

const List<SettingsEntry> kSettingsEntries = [
  SettingsEntry(
    title: '正文行距',
    section: '排版',
    target: SettingsTarget.reading,
    anchor: 'lineHeight',
    icon: Icons.format_line_spacing_outlined,
    aliases: ['行距', '行高', '间距', '紧凑', '宽松', '排版'],
  ),
  SettingsEntry(
    title: '页边距',
    section: '排版',
    target: SettingsTarget.reading,
    anchor: 'pageMargin',
    icon: Icons.padding_outlined,
    aliases: ['边距', '留白', '宽度', '排版'],
  ),
  SettingsEntry(
    title: '屏幕常亮',
    section: '阅读行为',
    target: SettingsTarget.reading,
    anchor: 'keepScreenOn',
    icon: Icons.brightness_high_outlined,
    aliases: ['常亮', '熄屏', '唤醒', '屏幕'],
  ),
  SettingsEntry(
    title: '手势翻页',
    section: '阅读行为',
    target: SettingsTarget.reading,
    anchor: 'swipePaging',
    icon: Icons.swipe_outlined,
    aliases: ['滑动', '翻页', '手势', '左右滑'],
  ),
  SettingsEntry(
    title: '表格不换行',
    section: '阅读行为',
    target: SettingsTarget.reading,
    anchor: 'wideTable',
    icon: Icons.table_chart_outlined,
    aliases: ['表格', '宽表', '横向滚动', '换行'],
  ),
  SettingsEntry(
    title: '折叠块默认展开',
    section: '阅读行为',
    target: SettingsTarget.reading,
    anchor: 'detailsExpanded',
    icon: Icons.expand_more,
    aliases: ['折叠', '展开', 'details', '摘要'],
  ),
  SettingsEntry(
    title: '代码字体',
    section: '代码块',
    target: SettingsTarget.reading,
    anchor: 'codeFont',
    icon: Icons.font_download_outlined,
    aliases: ['字体', '等宽', 'mono', 'jetbrains', '代码'],
  ),
  SettingsEntry(
    title: '代码行号',
    section: '代码块',
    target: SettingsTarget.reading,
    anchor: 'codeLineNumbers',
    icon: Icons.format_list_numbered,
    aliases: ['行号', '代码', '编号'],
  ),
  SettingsEntry(
    title: '长代码块折叠',
    section: '代码块',
    target: SettingsTarget.reading,
    anchor: 'codeFold',
    icon: Icons.unfold_less,
    aliases: ['折叠', '代码', '收起'],
  ),
  SettingsEntry(
    title: '代码折叠阈值',
    section: '代码块',
    target: SettingsTarget.reading,
    anchor: 'codeFoldThreshold',
    icon: Icons.straighten,
    aliases: ['阈值', '行数', '折叠', '代码'],
  ),
  SettingsEntry(
    title: '最近阅读条数',
    section: '首页',
    target: SettingsTarget.reading,
    anchor: 'recentsLimit',
    icon: Icons.history,
    aliases: ['首页', '最近', '条数', '历史'],
  ),
  SettingsEntry(
    title: '主题',
    section: '主题',
    target: SettingsTarget.appearance,
    anchor: 'theme',
    icon: Icons.palette_outlined,
    aliases: ['深色', '浅色', '夜间', '暗色', '跟随系统', '外观'],
  ),
  SettingsEntry(
    title: '桌面图标',
    section: '桌面图标',
    target: SettingsTarget.appearance,
    anchor: 'appIcon',
    icon: Icons.apps,
    aliases: ['图标', '启动图标', 'launcher'],
  ),
  SettingsEntry(
    title: '默认平台',
    section: '默认平台',
    target: SettingsTarget.repo,
    anchor: 'platform',
    icon: Icons.hub_outlined,
    aliases: ['github', 'gitee', 'gitcode', 'gitlab', '平台', '地址'],
  ),
  SettingsEntry(
    title: '默认用户名',
    section: '默认用户名',
    target: SettingsTarget.repo,
    anchor: 'owner',
    icon: Icons.person_outline,
    aliases: ['用户名', 'owner', '作者', '短地址'],
  ),
  SettingsEntry(
    title: '自动拉取同步',
    section: '同步与浏览',
    target: SettingsTarget.repo,
    anchor: 'silentPull',
    icon: Icons.sync_outlined,
    aliases: ['自动', '同步', '拉取', '更新', '启动'],
  ),
  SettingsEntry(
    title: '目录树模式',
    section: '同步与浏览',
    target: SettingsTarget.repo,
    anchor: 'treeMode',
    icon: Icons.account_tree_outlined,
    aliases: ['目录', '树', '展开', '浏览'],
  ),
  SettingsEntry(
    title: '隐藏默认忽略项',
    section: '隐藏项',
    target: SettingsTarget.fileDisplay,
    anchor: 'ignoreDefaults',
    icon: Icons.visibility_off_outlined,
    aliases: ['隐藏', '点文件', '默认忽略', '显示'],
  ),
  SettingsEntry(
    title: '自定义隐藏规则',
    section: '隐藏项',
    target: SettingsTarget.fileDisplay,
    anchor: 'ignoreRules',
    icon: Icons.rule_outlined,
    aliases: ['忽略', '规则', 'dist', 'build', '隐藏'],
  ),
  SettingsEntry(
    title: '存储占用',
    section: '存储',
    target: SettingsTarget.data,
    anchor: 'storage',
    icon: Icons.storage_outlined,
    aliases: ['缓存', '空间', '大小', '清理', '图片缓存'],
  ),
  SettingsEntry(
    title: '未写回的修改',
    section: '存储',
    target: SettingsTarget.data,
    anchor: 'pending',
    icon: Icons.cloud_done_outlined,
    aliases: ['写回', '待写回', '冲突', 'pending', '本地文件夹'],
  ),
  SettingsEntry(
    title: '清空搜索历史',
    section: '存储',
    target: SettingsTarget.data,
    anchor: 'clearSearchHistory',
    icon: Icons.search_off_outlined,
    aliases: ['搜索', '历史', '清空'],
  ),
  SettingsEntry(
    title: '清空阅读历史',
    section: '危险操作',
    target: SettingsTarget.data,
    anchor: 'clearRecents',
    icon: Icons.history_toggle_off,
    aliases: ['阅读', '历史', '清空', '最近'],
  ),
  SettingsEntry(
    title: '清空收藏',
    section: '危险操作',
    target: SettingsTarget.data,
    anchor: 'clearStars',
    icon: Icons.star_outline,
    aliases: ['收藏', '星标', '清空'],
  ),
];

/// 按设置名、页面名和别名做 AND 子串匹配。
List<SettingsEntry> searchSettings(String query) {
  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (terms.isEmpty) return const [];
  return kSettingsEntries.where((entry) {
    final haystack = entry.searchable.join('\n').toLowerCase();
    return terms.every(haystack.contains);
  }).toList();
}

/// 设置搜索页：输入关键字，点结果跳到对应子页并滚动到该项。
class SettingsSearchPage extends StatefulWidget {
  const SettingsSearchPage({required this.prefs, super.key});

  final AppPrefs prefs;

  @override
  State<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState extends State<SettingsSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open(SettingsEntry entry) {
    Widget page = switch (entry.target) {
      SettingsTarget.reading => ReadingSettingsPage(
        prefs: widget.prefs,
        focus: entry.anchor,
      ),
      SettingsTarget.appearance => AppearanceSettingsPage(
        prefs: widget.prefs,
        focus: entry.anchor,
      ),
      SettingsTarget.repo => RepoSettingsPage(
        prefs: widget.prefs,
        focus: entry.anchor,
      ),
      SettingsTarget.fileDisplay => FileDisplaySettingsPage(
        prefs: widget.prefs,
        focus: entry.anchor,
      ),
      SettingsTarget.data => DataSettingsPage(
        prefs: widget.prefs,
        focus: entry.anchor,
      ),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _query.trim().isEmpty
        ? const <SettingsEntry>[]
        : searchSettings(_query);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索设置，例如 行距、缓存、忽略',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: '清除',
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
                _focus.requestFocus();
              },
            ),
        ],
      ),
      body: _query.trim().isEmpty
          ? _Hint(
              theme: theme,
              onSelected: (word) {
                _controller.text = word;
                setState(() => _query = word);
                _focus.requestFocus();
              },
            )
          : results.isEmpty
          ? Center(
              child: Text(
                '没有匹配的设置',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = results[index];
                return ListTile(
                  leading: Icon(
                    entry.icon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(entry.title),
                  subtitle: Text(
                    entry.breadcrumb,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _open(entry),
                );
              },
            ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.theme, required this.onSelected});

  final ThemeData theme;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Text(
          '可直接搜索设置名或别名，例如：',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final word in const ['行距', '边距', '深色', '缓存', '忽略', '历史'])
              ActionChip(label: Text(word), onPressed: () => onSelected(word)),
          ],
        ),
      ],
    );
  }
}
