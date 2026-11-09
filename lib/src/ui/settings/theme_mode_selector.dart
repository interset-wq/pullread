import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_prefs.dart';

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统',
  ThemeMode.light => '浅色',
  ThemeMode.dark => '深色',
};

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({
    required this.prefs,
    this.onSelected,
    this.tilePadding = EdgeInsets.zero,
    super.key,
  });

  final AppPrefs prefs;
  final ValueChanged<ThemeMode>? onSelected;

  /// 页面内与正文共用 16 dp 外边距时为 0；底部弹窗里需要自带左右留白。
  final EdgeInsetsGeometry tilePadding;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: prefs,
      builder: (context, _) => RadioGroup<ThemeMode>(
        groupValue: prefs.mode,
        onChanged: (mode) {
          if (mode == null) return;
          unawaited(prefs.setMode(mode));
          onSelected?.call(mode);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              (ThemeMode.system, '跟随系统', Icons.brightness_auto),
              (ThemeMode.light, '浅色', Icons.light_mode),
              (ThemeMode.dark, '深色', Icons.dark_mode),
            ])
              RadioListTile<ThemeMode>(
                value: entry.$1,
                contentPadding: tilePadding,
                title: Row(
                  children: [
                    Icon(entry.$3, size: 20),
                    const SizedBox(width: 12),
                    Text(entry.$2),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showThemeModeSheet(BuildContext context, AppPrefs prefs) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('主题')),
          ThemeModeSelector(
            prefs: prefs,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            onSelected: (_) => Navigator.pop(sheetContext),
          ),
        ],
      ),
    ),
  );
}
