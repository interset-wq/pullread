import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings_components.dart';

const String kReleaseUrl = 'https://github.com/interset-wq/pullread/releases';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const _channel = MethodChannel('app_icon');
  static const _repoUrl = 'https://github.com/interset-wq/pullread';
  static const _licenseUrl = '$_repoUrl/blob/main/LICENSE';

  Map<Object?, Object?>? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await _channel
          .invokeMethod<Map<Object?, Object?>>('getInfo')
          .timeout(const Duration(seconds: 3));
      if (mounted && info != null) setState(() => _info = info);
    } on Object {
      // 通道不可用时仅显示静态信息
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // 无浏览器等情况下静默忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = _info == null
        ? null
        : '${_info!['versionName']}+${_info!['versionCode']}';
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('关于 PullRead')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kSettingsContentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 40),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/icon/app_logo.png',
                    width: 96,
                    height: 96,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'PullRead 拉读',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (version != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'v$version',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              if (_info != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tag_outlined),
                  title: const Text('包名'),
                  subtitle: Text('${_info!['packageName']}'),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_edu_outlined),
                title: const Text('开源许可证'),
                subtitle: const Text('第三方依赖、libgit2 与字体'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // 内置 LicensePage 不走 showLicensePage（其路由吃不到局部
                  // 主题），改自建路由 + Theme 包装，让 AppBar/背景对齐品牌配色
                  final licenseTheme = theme.copyWith(
                    appBarTheme: theme.appBarTheme.copyWith(
                      backgroundColor: theme.scaffoldBackgroundColor,
                      foregroundColor: theme.colorScheme.onSurface,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      centerTitle: true,
                      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Theme(
                        data: licenseTheme,
                        child: LicensePage(
                          applicationName: 'PullRead 拉读',
                          applicationVersion: version == null
                              ? null
                              : 'v$version',
                          applicationLegalese:
                              '© 2026 interset-wq · MIT License',
                          applicationIcon: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/icon/app_logo.png',
                              width: 48,
                              height: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('项目许可证'),
                subtitle: const Text('MIT License'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _open(Uri.parse(_licenseUrl)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.code_outlined),
                title: const Text('项目主页'),
                subtitle: const Text('GitHub · interset-wq/pullread'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _open(Uri.parse(_repoUrl)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.system_update_outlined),
                title: const Text('获取最新版本'),
                subtitle: const Text('前往 GitHub Releases 获取最新安装包'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _open(Uri.parse(kReleaseUrl)),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '克隆一次，常读常新。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
