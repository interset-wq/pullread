import 'package:flutter/material.dart';

import 'app_prefs.dart';

/// 阅读纸色：阅读页/代码页/编辑器等「长时间阅读」页面使用的背景体系。
///
/// 只覆盖阅读面：首页、设置等页面保持品牌视觉（白纸 + 松绿）不变。
/// 浅色可选白纸（默认）或 sepia 暖色；深色可选柔和暗（默认，M3 种子
/// surface）或 OLED 纯黑。正文文字、代码块、表格等现有明暗配色不动——
/// sepia 下白色代码块形成卡片层次，OLED 下深色卡片略浅于纯黑背景，
/// 都符合「背景深一层、内容块浮起」的常规阅读器做法。
class ReadingPaper {
  const ReadingPaper({
    required this.background,
    required this.appBar,
    required this.onAppBar,
    required this.divider,
  });

  /// 页面 / Scaffold 背景。
  final Color background;

  /// 阅读页 AppBar 与侧栏背景（与页面同色，保持「纸」的连续感）。
  final Color appBar;

  /// AppBar 前景（标题 / 图标）。
  final Color onAppBar;

  /// 阅读面分隔线（阅读进度条、find bar 边框等）。
  final Color divider;

  /// 按当前亮度 + 用户偏好解析纸色（偏好未就绪时回退默认纸色）。
  static ReadingPaper resolve(BuildContext context, AppPrefs? prefs) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      if ((prefs?.paperDark ?? 'soft') == 'black') {
        return const ReadingPaper(
          background: Colors.black,
          appBar: Colors.black,
          onAppBar: Color(0xFFE8E6E1),
          divider: Color(0xFF2C2A26),
        );
      }
      // 柔和暗：跟随主题（M3 种子暗色 surface），不额外覆盖
      final scheme = Theme.of(context).colorScheme;
      return ReadingPaper(
        background: scheme.surface,
        appBar: scheme.surface,
        onAppBar: scheme.onSurface,
        divider: scheme.outlineVariant,
      );
    }
    if ((prefs?.paperLight ?? 'white') == 'sepia') {
      return const ReadingPaper(
        background: Color(0xFFF6EFE0),
        appBar: Color(0xFFF6EFE0),
        onAppBar: Color(0xFF3A3225),
        divider: Color(0xFFDDD2BC),
      );
    }
    // 白纸：跟随主题（与全站一致的纯白）
    final scheme = Theme.of(context).colorScheme;
    return ReadingPaper(
      background: scheme.surface,
      appBar: scheme.surface,
      onAppBar: scheme.onSurface,
      divider: scheme.outlineVariant,
    );
  }
}
