import 'dart:async';

import 'package:flutter/material.dart';

import '../../platforms/git_platform.dart';
import '../../theme/app_prefs.dart';
import 'settings_components.dart';

class RepoSettingsPage extends StatefulWidget {
  const RepoSettingsPage({required this.prefs, this.focus, super.key});

  final AppPrefs prefs;

  /// 从设置搜索进入时要滚动到的锚点 id。
  final String? focus;

  @override
  State<RepoSettingsPage> createState() => _RepoSettingsPageState();
}

class _RepoSettingsPageState extends State<RepoSettingsPage> {
  late final TextEditingController _ownerController;
  late final FocusNode _ownerFocus;
  late String _savedOwner;
  bool _savedFlash = false;
  Timer? _flashTimer;

  AppPrefs get _prefs => widget.prefs;

  bool get _ownerDirty => _ownerController.text != _savedOwner;

  @override
  void initState() {
    super.initState();
    _savedOwner = _prefs.defaultOwner;
    _ownerController = TextEditingController(text: _savedOwner)
      ..addListener(_onOwnerChanged);
    _ownerFocus = FocusNode()..addListener(_onOwnerFocusChanged);
  }

  void _onOwnerChanged() {
    if (mounted) setState(() {});
  }

  void _onOwnerFocusChanged() {
    // 失焦兜底保存；显式保存时已更新 _savedOwner，这里不会重复触发反馈
    if (!_ownerFocus.hasFocus && _ownerController.text != _savedOwner) {
      _saveOwner();
    }
  }

  void _saveOwner() {
    final wasFocused = _ownerFocus.hasFocus;
    unawaited(_prefs.setDefaultOwner(_ownerController.text));
    _savedOwner = _ownerController.text;
    if (wasFocused) _ownerFocus.unfocus();
    _flashTimer?.cancel();
    setState(() => _savedFlash = true);
    _flashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _savedFlash = false);
    });
  }

  Future<void> _reset() async {
    await _prefs.setPlatform(GitPlatform.gitcode);
    await _prefs.setDefaultOwner('');
    await _prefs.setSilentPull(false);
    await _prefs.setTreeMode(false);
    if (!mounted) return;
    _savedOwner = '';
    _ownerController.clear();
  }

  @override
  void dispose() {
    unawaited(_prefs.setDefaultOwner(_ownerController.text));
    _flashTimer?.cancel();
    _ownerController.removeListener(_onOwnerChanged);
    _ownerFocus
      ..removeListener(_onOwnerFocusChanged)
      ..dispose();
    _ownerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _prefs,
      builder: (context, _) => SettingsSubpage(
        title: '仓库与同步',
        focus: widget.focus,
        onReset: _reset,
        children: [
          SettingsSection(
            title: '默认平台',
            help: '只影响短输入自动拼接完整地址，不会限制你粘贴任意仓库 URL。',
            children: [
              SettingsAnchor(
                id: 'platform',
                child: RadioGroup<GitPlatform>(
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
              ),
            ],
          ),
          SettingsSection(
            title: '默认用户名',
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const SettingsIconTile(
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        '用户名',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SettingsHelpButton(
                      title: '默认用户名',
                      message: '留空则只能粘贴完整仓库 URL；'
                          '短输入（owner/repo）会自动拼上用户名。',
                    ),
                  ],
                ),
              ),
              SettingsAnchor(
                id: 'owner',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: TextField(
                  controller: _ownerController,
                  focusNode: _ownerFocus,
                  textInputAction: TextInputAction.done,
                  decoration: settingsInputDecoration(
                    context,
                    hint: '例如 interset-wq',
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: _ownerDirty ? _saveOwner : null,
                        style: TextButton.styleFrom(
                          backgroundColor: _ownerDirty
                              ? const Color(0xFF1F6F54)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(20),
                          foregroundColor: _ownerDirty
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text('保存'),
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    _saveOwner();
                    _ownerFocus.unfocus();
                  },
                  onTapOutside: (_) => _ownerFocus.unfocus(),
                ),
              ),
            ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 7, 18, 0),
                child: Text(
                  '点「保存」或键盘回车生效；内容未变时按钮置灰',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _savedFlash
                    ? Padding(
                        key: const ValueKey('saved'),
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 15,
                              color: Color(0xFF1F6F54),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '已保存',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF1F6F54),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
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
