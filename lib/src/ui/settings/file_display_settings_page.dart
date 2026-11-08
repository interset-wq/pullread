import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_prefs.dart';
import 'settings_components.dart';

class FileDisplaySettingsPage extends StatelessWidget {
  const FileDisplaySettingsPage({required this.prefs, super.key});

  final AppPrefs prefs;

  Future<void> _reset() => prefs.resetIgnoreRules();

  Future<void> _editRules(BuildContext context) async {
    final controller = TextEditingController(
      text: prefs.ignoreRules.join('\n'),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('自定义隐藏规则'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '每行一条，例如：\ndist\nbuild\nassets',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              unawaited(prefs.resetIgnoreRules());
              Navigator.pop(dialogContext, false);
            },
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) {
      controller.dispose();
      return;
    }
    final rules = controller.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    controller.dispose();
    await prefs.setIgnoreRules(rules);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: prefs,
      builder: (context, _) => SettingsSubpage(
        title: '文件显示',
        onReset: _reset,
        children: [
          SettingsSection(
            title: '隐藏项',
            children: [
              SettingsSwitchTile(
                icon: Icons.visibility_off_outlined,
                title: '隐藏默认忽略项',
                subtitle: '点开头的文件与目录',
                value: prefs.ignoreDefaults,
                onChanged: (v) => unawaited(prefs.setIgnoreDefaults(v)),
                help: '.git 始终忽略；开启后其他以点开头的文件和目录也会从仓库列表隐藏。',
              ),
              SettingsNavTile(
                icon: Icons.rule_outlined,
                title: '自定义隐藏规则',
                subtitle: prefs.ignoreRules.isEmpty
                    ? '按文件/目录名精确匹配，未添加'
                    : '${prefs.ignoreRules.length} 条：${prefs.ignoreRules.join('、')}',
                value: '${prefs.ignoreRules.length} 条',
                onTap: () => _editRules(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
