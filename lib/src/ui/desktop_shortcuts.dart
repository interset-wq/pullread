import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 当前平台是否具备桌面键鼠能力（Windows / Linux / macOS）。
bool get isDesktopPlatform =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// 桌面快捷键外壳：在桌面平台上挂 [CallbackShortcuts]，并让页面拿到焦点。
///
/// 移动端直接返回 [child]，不改变既有交互；桌面端用 [Focus] 承接快捷键，
/// 页面内 TextField 聚焦时仍可输入（按键先由输入框处理）。
class DesktopShortcuts extends StatelessWidget {
  const DesktopShortcuts({
    required this.bindings,
    required this.child,
    super.key,
  });

  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform) return child;
    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(autofocus: true, child: child),
    );
  }
}

/// 焦点是否落在可编辑文本上；是则不应把 PageUp/Home 等键当成翻页。
bool get isTextInputFocused {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}
