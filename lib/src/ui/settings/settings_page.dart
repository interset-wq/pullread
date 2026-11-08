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
import 'theme_mode_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.prefs, super.key});

  final AppPrefs prefs;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _pendingCount = 0;
  String? _version;

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

  Future<void> _openData() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DataSettingsPage(prefs: widget.prefs),
      ),
    );
    await _refreshPending();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = Platform.isAndroid;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: AnimatedBuilder(
        animation: widget.prefs,
        builder: (context, _) {
          final prefs = widget.prefs;
          return SettingsBody(
            children: [
              SettingsSection(
                children: [
                  SettingsNavTile(
                    icon: Icons.menu_book_outlined,
                    title: '阅读与显示',
                    subtitle: '行距、边距、阅读行为与代码块',
                    value:
                        '${prefs.lineHeight.toStringAsFixed(2)} / ${prefs.pageMargin.round()} dp',
                    onTap: () => _push(ReadingSettingsPage(prefs: prefs)),
                  ),
                  SettingsNavTile(
                    icon: Icons.palette_outlined,
                    title: '外观与图标',
                    subtitle: isAndroid ? '主题与桌面图标' : '主题',
                    value: themeModeLabel(prefs.mode),
                    onTap: () => _push(AppearanceSettingsPage(prefs: prefs)),
                  ),
                  SettingsNavTile(
                    icon: Icons.cloud_sync_outlined,
                    title: '仓库与同步',
                    subtitle: '默认平台、用户名、自动同步与目录树',
                    value: prefs.platform.displayName,
                    onTap: () => _push(RepoSettingsPage(prefs: prefs)),
                  ),
                  SettingsNavTile(
                    icon: Icons.visibility_off_outlined,
                    title: '文件显示',
                    subtitle: '隐藏默认项与自定义规则',
                    value: '${prefs.ignoreRules.length} 条规则',
                    onTap: () => _push(FileDisplaySettingsPage(prefs: prefs)),
                  ),
                  SettingsNavTile(
                    icon: Icons.storage_outlined,
                    title: '存储与数据',
                    subtitle: '占用、待写回、历史与收藏',
                    badgeCount: _pendingCount,
                    onTap: _openData,
                  ),
                  SettingsNavTile(
                    icon: Icons.info_outline,
                    title: '关于 PullRead',
                    subtitle: '版本、许可证与项目主页',
                    value: _version == null ? null : 'v$_version',
                    onTap: () => _push(const AboutPage()),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'PullRead · 把笔记仓库装进口袋',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
