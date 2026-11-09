import 'dart:async';

import 'package:flutter/material.dart';

import '../../platforms/git_platform.dart';
import '../../theme/app_prefs.dart';
import 'settings_components.dart';

class RepoSettingsPage extends StatefulWidget {
  const RepoSettingsPage({required this.prefs, super.key});

  final AppPrefs prefs;

  @override
  State<RepoSettingsPage> createState() => _RepoSettingsPageState();
}

class _RepoSettingsPageState extends State<RepoSettingsPage> {
  late final TextEditingController _ownerController;
  late final FocusNode _ownerFocus;

  AppPrefs get _prefs => widget.prefs;

  @override
  void initState() {
    super.initState();
    _ownerController = TextEditingController(text: _prefs.defaultOwner);
    _ownerFocus = FocusNode()..addListener(_onOwnerFocusChanged);
  }

  void _onOwnerFocusChanged() {
    if (!_ownerFocus.hasFocus) _saveOwner();
  }

  void _saveOwner() {
    unawaited(_prefs.setDefaultOwner(_ownerController.text));
  }

  Future<void> _reset() async {
    await _prefs.setPlatform(GitPlatform.gitcode);
    await _prefs.setDefaultOwner('');
    await _prefs.setSilentPull(false);
    await _prefs.setTreeMode(false);
    if (!mounted) return;
    _ownerController.clear();
  }

  @override
  void dispose() {
    _saveOwner();
    _ownerFocus
      ..removeListener(_onOwnerFocusChanged)
      ..dispose();
    _ownerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _prefs,
      builder: (context, _) => SettingsSubpage(
        title: '仓库与同步',
        onReset: _reset,
        children: [
          SettingsSection(
            title: '默认平台',
            help: '只影响短输入自动拼接完整地址，不会限制你粘贴任意仓库 URL。',
            children: [
              RadioGroup<GitPlatform>(
                groupValue: _prefs.platform,
                onChanged: (platform) {
                  if (platform != null) {
                    unawaited(_prefs.setPlatform(platform));
                  }
                },
                child: Column(
                  children: [
                    for (final platform in GitPlatform.values)
                      if (platform.webBase.isNotEmpty)
                        RadioListTile<GitPlatform>(
                          value: platform,
                          contentPadding: EdgeInsets.zero,
                          title: Text(platform.displayName),
                          subtitle: Text(platform.webBase),
                        ),
                  ],
                ),
              ),
            ],
          ),
          SettingsSection(
            title: '默认用户名',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextField(
                  controller: _ownerController,
                  focusNode: _ownerFocus,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    hintText: '例如 interset-wq',
                    helperText: '留空则只能粘贴完整 URL',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    _saveOwner();
                    _ownerFocus.unfocus();
                  },
                  onTapOutside: (_) => _ownerFocus.unfocus(),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: '同步与浏览',
            children: [
              SettingsSwitchTile(
                icon: Icons.sync_outlined,
                title: '自动拉取同步',
                subtitle: '启动时后台更新所有仓库',
                value: _prefs.silentPull,
                onChanged: (v) => unawaited(_prefs.setSilentPull(v)),
                help: '开启后应用启动时会在后台静默 pull 所有仓库；默认关闭，可随时下拉刷新或点仓库页刷新按钮手动同步。',
              ),
              SettingsSwitchTile(
                icon: Icons.account_tree_outlined,
                title: '目录树模式',
                subtitle: '目录就地展开，不进入下一级',
                value: _prefs.treeMode,
                onChanged: (v) => unawaited(_prefs.setTreeMode(v)),
                help: '开启后仓库页目录就地展开/折叠，一页看全整个仓库；关闭后点目录逐级进入，类似文件资源管理器。',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
