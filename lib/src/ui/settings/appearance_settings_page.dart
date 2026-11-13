import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/app_prefs.dart';
import 'settings_components.dart';
import 'theme_mode_selector.dart';

const Map<String, String> kAppIconLabels = {
  'book': '摊开书',
  'page': '页即箭',
  'arrow': '抽页成箭',
  'converge': '汇页箭',
  'tray': '页堆箭',
};

const Map<String, String> kPaperLightLabels = {
  'white': '白纸',
  'sepia': '暖色（sepia）',
};

const Map<String, String> kPaperDarkLabels = {
  'soft': '柔和暗',
  'black': '纯黑（OLED）',
};

class PaperColorSelector extends StatelessWidget {
  const PaperColorSelector({required this.prefs, super.key});

  final AppPrefs prefs;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: prefs,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<String>(
            groupValue: prefs.paperLight,
            onChanged: (v) {
              if (v != null) unawaited(prefs.setPaperLight(v));
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in kPaperLightLabels.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    contentPadding: EdgeInsets.zero,
                    title: Text('浅色 · ${entry.value}'),
                  ),
              ],
            ),
          ),
          RadioGroup<String>(
            groupValue: prefs.paperDark,
            onChanged: (v) {
              if (v != null) unawaited(prefs.setPaperDark(v));
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in kPaperDarkLabels.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    contentPadding: EdgeInsets.zero,
                    title: Text('深色 · ${entry.value}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({required this.prefs, this.focus, super.key});

  final AppPrefs prefs;

  /// 从设置搜索进入时要滚动到的锚点 id。
  final String? focus;

  Future<void> _reset() async {
    await prefs.setMode(ThemeMode.system);
    await prefs.setAppIcon('book');
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    return AnimatedBuilder(
      animation: prefs,
      builder: (context, _) => SettingsSubpage(
        title: '外观与图标',
        onReset: _reset,
        focus: focus,
        children: [
          SettingsSection(
            title: '主题',
            children: [
              SettingsAnchor(
                id: 'theme',
                child: ThemeModeSelector(prefs: prefs),
              ),
            ],
          ),
          SettingsSection(
            title: '阅读纸色',
            help: '仅作用于阅读页、代码页和编辑器；首页与设置保持现有外观。',
            children: [
              SettingsAnchor(
                id: 'readingPaper',
                child: PaperColorSelector(prefs: prefs),
              ),
            ],
          ),
          if (isAndroid)
            SettingsSection(
              title: '桌面图标',
              help: '切换后桌面图标在 launcher 刷新后生效，部分机型需要重新启动桌面。',
              children: [
                SettingsAnchor(
                  id: 'appIcon',
                  child: _IconGrid(prefs: prefs),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.prefs});

  final AppPrefs prefs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 560 ? 5 : 3;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
            children: [
              for (final entry in kAppIconLabels.entries)
                _IconOption(
                  label: entry.value,
                  asset: 'assets/icons/icon_${entry.key}.png',
                  selected: prefs.appIcon == entry.key,
                  onTap: () => unawaited(prefs.setAppIcon(entry.key)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(asset, width: 64, height: 64),
                ),
              ),
              if (selected)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
