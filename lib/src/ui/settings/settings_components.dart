import 'package:flutter/material.dart';

const double kSettingsContentMaxWidth = 720;

/// 给可选锚点的设置行套上 [SettingsAnchor]。
Widget _anchored(String? id, Widget child) =>
    id == null ? child : SettingsAnchor(id: id, child: child);

/// 图标章色调（docs/design/settings-redesign.md：深浅色成对）
enum SettingsTone { pine, neutral, amber }

class SettingsTilePalette {
  const SettingsTilePalette({required this.bg, required this.fg});
  final Color bg;
  final Color fg;
}

SettingsTilePalette settingsTonePalette(
  SettingsTone tone,
  Brightness brightness,
) {
  const light = <SettingsTone, (Color, Color)>{
    SettingsTone.pine: (Color(0xFFEDF5F0), Color(0xFF1F6F54)),
    SettingsTone.neutral: (Color(0xFFF1EFE7), Color(0xFF5A5850)),
    SettingsTone.amber: (Color(0xFFFDF6E7), Color(0xFFB0762A)),
  };
  const dark = <SettingsTone, (Color, Color)>{
    SettingsTone.pine: (Color(0xFF1A3A2E), Color(0xFF7BC7A5)),
    SettingsTone.neutral: (Color(0xFF2A2924), Color(0xFFB5B2A6)),
    SettingsTone.amber: (Color(0xFF3A2E1C), Color(0xFFD9A05B)),
  };
  final palette = brightness == Brightness.dark ? dark : light;
  final pair = palette[tone]!;
  return SettingsTilePalette(bg: pair.$1, fg: pair.$2);
}

/// 40px 圆角 tint 图标章，与目录树/收件箱等页共用语言
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile({
    required this.icon,
    this.tone = SettingsTone.pine,
    this.size = 40,
    super.key,
  });

  final IconData icon;
  final SettingsTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = settingsTonePalette(tone, Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size * 0.5, color: palette.fg),
    );
  }
}

/// 输入框 token（docs/design/settings-redesign.md：白卡描边、聚焦松绿）
InputDecoration settingsInputDecoration(
  BuildContext context, {
  String? hint,
  Widget? suffix,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final outline = dark ? const Color(0xFF3A382F) : const Color(0xFFE5E2D8);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 14.5,
      color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: outline, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1F6F54), width: 1.5),
    ),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    isDense: true,
  );
}

class SettingsBody extends StatefulWidget {
  const SettingsBody({required this.children, super.key});

  final List<Widget> children;

  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scrollbar 在最外层横跨整个面板宽度，滚动条紧贴屏幕/面板右缘；
    // 内容仍居中限宽。ScrollConfiguration 关闭桌面端自动注入的滚动条，
    // 否则会出现「内置 + 贴边」两条。SingleChildScrollView + 非懒
    // Column：设置项数量很少，全部建出来才能让搜索结果的
    // SettingsAnchor 对屏幕外的行执行 ensureVisible。
    return ScrollbarTheme(
      data: const ScrollbarThemeData(mainAxisMargin: 0),
      child: Scrollbar(
        controller: _scrollController,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: kSettingsContentMaxWidth),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSubpage extends StatelessWidget {
  const SettingsSubpage({
    required this.title,
    required this.children,
    this.onReset,
    this.focus,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function()? onReset;

  /// 从设置搜索进入时要滚动到的锚点 id。
  final String? focus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 标题居中（用户要求）：双栏右栏与手机 push 均生效
        centerTitle: true,
        title: Text(title),
        actions: [
          if (onReset != null)
            TextButton(
              onPressed: () async {
                await onReset!();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已恢复本页默认')));
              },
              child: const Text('恢复默认'),
            ),
        ],
      ),
      body: SettingsFocusScope(
        focus: focus,
        child: SettingsBody(children: children),
      ),
    );
  }
}

/// 把设置搜索选中的锚点传给子页，供 [SettingsAnchor] 首帧后滚动定位。
class SettingsFocusScope extends InheritedWidget {
  const SettingsFocusScope({
    required this.focus,
    required super.child,
    super.key,
  });

  final String? focus;

  static String? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsFocusScope>()?.focus;

  @override
  bool updateShouldNotify(SettingsFocusScope oldWidget) =>
      focus != oldWidget.focus;
}

/// 设置项锚点：命中 [SettingsFocusScope.focus] 时在首帧布局后滚到该项。
class SettingsAnchor extends StatefulWidget {
  const SettingsAnchor({required this.id, required this.child, super.key});

  final String id;
  final Widget child;

  @override
  State<SettingsAnchor> createState() => _SettingsAnchorState();
}

class _SettingsAnchorState extends State<SettingsAnchor> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled || SettingsFocusScope.maybeOf(context) != widget.id) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    this.title,
    this.help,
    super.key,
  });

  final String? title;
  final String? help;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (help != null)
                    SettingsHelpButton(title: title!, message: help!),
                ],
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.tone = SettingsTone.pine,
    this.badgeCount = 0,
    this.destructive = false,
    this.enabled = true,
    this.anchor,
    super.key,
  });

  final IconData icon;
  final SettingsTone tone;
  final String title;
  final String? subtitle;
  final String? value;
  final int badgeCount;
  final bool destructive;
  final bool enabled;
  final VoidCallback onTap;
  final String? anchor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = destructive ? scheme.error : null;
    return _anchored(
      anchor,
      ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: enabled,
        leading: SettingsIconTile(icon: icon, tone: tone),
        title: Text(
          title,
          style: foreground == null ? null : TextStyle(color: foreground),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 128),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.tone = SettingsTone.pine,
    this.help,
    this.anchor,
    super.key,
  });

  final IconData icon;
  final SettingsTone tone;
  final String title;
  final String subtitle;
  final String? help;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? anchor;

  @override
  Widget build(BuildContext context) {
    return _anchored(
      anchor,
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: SettingsIconTile(icon: icon, tone: tone),
        title: help == null
            ? Text(title)
            : Row(
                children: [
                  Expanded(child: Text(title)),
                  SettingsHelpButton(title: title, message: help!),
                ],
              ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
    this.subtitle,
    this.tone = SettingsTone.pine,
    this.help,
    this.enabled = true,
    this.anchor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final SettingsTone tone;
  final String valueLabel;
  final String? help;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final bool enabled;
  final String? anchor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _anchored(
      anchor,
      Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SettingsIconTile(icon: icon, tone: tone),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(title)),
                            if (help != null)
                              SettingsHelpButton(title: title, message: help!),
                            const SizedBox(width: 4),
                            Text(
                              valueLabel,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: valueLabel,
                semanticFormatterCallback: (_) => valueLabel,
                onChanged: enabled ? onChanged : null,
                onChangeEnd: enabled ? onChangeEnd : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsHelpButton extends StatelessWidget {
  const SettingsHelpButton({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '说明',
      icon: const Icon(Icons.help_outline, size: 18),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () =>
          showSettingsHelp(context, title: title, message: message),
    );
  }
}

Future<void> showSettingsHelp(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '清空',
}) async {
  final theme = Theme.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
