import 'package:flutter/material.dart';

const double kSettingsContentMaxWidth = 720;

class SettingsBody extends StatelessWidget {
  const SettingsBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kSettingsContentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: children,
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
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function()? onReset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      body: SettingsBody(children: children),
    );
  }
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
    this.badgeCount = 0,
    this.destructive = false,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final int badgeCount;
  final bool destructive;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = destructive ? scheme.error : null;
    final iconColor = destructive ? scheme.error : scheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: Icon(icon, size: 20, color: enabled ? iconColor : null),
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
    this.help,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? help;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, size: 20, color: theme.colorScheme.primary),
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
    this.help,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String valueLabel;
  final String? help;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
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
