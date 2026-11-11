import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_prefs.dart';
import 'settings_components.dart';

class FileDisplaySettingsPage extends StatefulWidget {
  const FileDisplaySettingsPage({required this.prefs, this.focus, super.key});

  final AppPrefs prefs;

  /// 从设置搜索进入时要滚动到的锚点 id。
  final String? focus;

  @override
  State<FileDisplaySettingsPage> createState() =>
      _FileDisplaySettingsPageState();
}

class _FileDisplaySettingsPageState extends State<FileDisplaySettingsPage> {
  bool _expanded = false;
  final _addController = TextEditingController();
  final _addFocus = FocusNode();

  AppPrefs get _prefs => widget.prefs;

  @override
  void initState() {
    super.initState();
    _addController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _addRule(String raw) async {
    final rule = raw.trim();
    if (rule.isEmpty) return;
    final rules = widget.prefs.ignoreRules;
    if (rules.contains(rule)) {
      _addController.clear();
      return;
    }
    _addController.clear();
    await _prefs.setIgnoreRules([...rules, rule]);
  }

  Future<void> _removeRule(String rule) async {
    final rules = widget.prefs.ignoreRules;
    await _prefs.setIgnoreRules(
      rules.where((r) => r != rule).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _prefs,
      builder: (context, _) => SettingsSubpage(
        title: '文件显示',
        focus: widget.focus,
        onReset: () => _prefs.resetIgnoreRules(),
        children: [
          SettingsSection(
            title: '隐藏项',
            children: [
              SettingsAnchor(
                id: 'ignoreDefaults',
                child: SettingsSwitchTile(
                  icon: Icons.visibility_off_outlined,
                  title: '隐藏默认忽略项',
                  subtitle: '点开头的文件与目录',
                  value: _prefs.ignoreDefaults,
                  onChanged: (v) => unawaited(_prefs.setIgnoreDefaults(v)),
                  help:
                      '.git 始终忽略；开启后其他以点开头的文件和目录也会从仓库列表隐藏。',
                ),
              ),
              // 规则行：点按就地展开 chips 增删 + 单行添加，不再弹 dialog
              SettingsAnchor(
                id: 'ignoreRules',
                child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() {
                  _expanded = !_expanded;
                  if (!_expanded) _addFocus.unfocus();
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const SettingsIconTile(icon: Icons.rule_outlined),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          '自定义隐藏规则',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        _prefs.ignoreRules.isEmpty
                            ? '未添加'
                            : '${_prefs.ignoreRules.length} 条',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: !_expanded
                    ? const SizedBox.shrink()
                    : Padding(
                        key: const ValueKey('rules-editor'),
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_prefs.ignoreRules.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final rule in _prefs.ignoreRules)
                                      Chip(
                                        label: Text(rule),
                                        labelStyle: TextStyle(
                                          fontSize: 12.5,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        backgroundColor:
                                            theme.colorScheme.onSurface
                                                .withAlpha(14),
                                        side: BorderSide.none,
                                        visualDensity: VisualDensity.compact,
                                        deleteIcon: const Icon(
                                          Icons.close,
                                          size: 15,
                                        ),
                                        onDeleted: () =>
                                            unawaited(_removeRule(rule)),
                                      ),
                                  ],
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: _addController,
                                focusNode: _addFocus,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (v) =>
                                    unawaited(_addRule(v)),
                                decoration: settingsInputDecoration(
                                  context,
                                  hint: '输入文件或目录名，如 dist',
                                  suffix: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: TextButton(
                                      onPressed: _addController.text.trim()
                                              .isEmpty
                                          ? null
                                          : () =>
                                              unawaited(_addRule(
                                                  _addController.text)),
                                      style: TextButton.styleFrom(
                                        backgroundColor: _addController
                                                .text.trim()
                                                .isEmpty
                                            ? theme.colorScheme.onSurface
                                                .withAlpha(20)
                                            : const Color(0xFF1F6F54),
                                        foregroundColor: _addController
                                                .text.trim()
                                                .isEmpty
                                            ? theme
                                                .colorScheme.onSurfaceVariant
                                            : Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        minimumSize: const Size(0, 32),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(9),
                                        ),
                                      ),
                                      child: const Text('添加'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 7, 18, 0),
                              child: Text(
                                '每条精确匹配一个文件或目录名；键盘回车也可添加，'
                                '点 chip 上的 × 删除，自动去重',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
