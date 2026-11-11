import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:git2dart/git2dart.dart';
import 'package:git2dart_binaries/git2dart_binaries.dart' show AndroidSSLHelper;

import 'src/theme/app_prefs.dart';
import 'src/ui/brand_splash.dart';
import 'src/ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerBundledLicenses();
  // 立刻 runApp：libgit2 / CA 证书初始化要几百毫秒到数秒，放在 runApp 之前
  // 会让 Flutter 的 SurfaceView 先挂上一块黑屏（与深色/浅色模式无关）。
  // 重量级初始化挪到 _bootstrap，期间显示品牌闪屏页。
  runApp(const ReaderApp());
}

/// 把不经过 pub 分发、但会随应用打包的许可证注册到 Flutter 的许可证页。
///
/// pub 包的 LICENSE 由 Flutter 构建时自动收集进 NOTICES；这里的 libgit2
/// （git2dart_binaries 提供）与 JetBrains Mono 字体不在其中，需要手动登记，
/// 否则「关于 → 开源许可证」会漏掉原生库和字体。
void _registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'libgit2',
    ], await rootBundle.loadString('LICENSES/libgit2-COPYING.txt'));
  });
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'JetBrains Mono',
    ], await rootBundle.loadString('LICENSES/JetBrainsMono-OFL.txt'));
  });
}

/// 启动初始化：Android 与 iOS 都必须先初始化 libgit2、再配置 CA 证书路径，
/// 否则 HTTPS 克隆报 "the SSL certificate is invalid"。
///
/// iOS 没有 libgit2 能直接读取的系统证书路径，因此和 Android 一样把
/// `git2dart_binaries` 内置的 `cacert.pem` 解包到应用沙盒。`AndroidSSLHelper`
/// 的命名虽带 Android，实现是纯 Dart（rootBundle + path_provider），iOS 可用。
Future<AppPrefs> _bootstrap() async {
  if (Platform.isAndroid || Platform.isIOS) {
    Libgit2.version;
    final certPath = await AndroidSSLHelper.initialize();
    Libgit2.setSSLCertLocations(file: certPath);
  }
  return AppPrefs.load();
}

class ReaderApp extends StatefulWidget {
  const ReaderApp({super.key});

  @override
  State<ReaderApp> createState() => _ReaderAppState();
}

class _ReaderAppState extends State<ReaderApp> {
  late final Future<AppPrefs> _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    const transitions = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    );
    const snackbar = SnackBarThemeData(behavior: SnackBarBehavior.floating);
    const card = CardThemeData(elevation: 0, clipBehavior: Clip.antiAlias);
    return FutureBuilder<AppPrefs>(
      future: _prefs,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupError(
            error: snapshot.error!,
            onRetry: () => setState(() => _prefs = _bootstrap()),
          );
        }
        if (!snapshot.hasData) {
          // 与首页首屏共用同一张闪屏：初始化完成后切到 HomePage 时
          // logo 不会跳变，用户只看到一次启动画面。
          return const BrandSplash();
        }
        final prefs = snapshot.data!;
        // 主题切换（App 内菜单）即时生效：随 AppPrefs 重建 MaterialApp
        // 品牌松绿（docs/design/settings-redesign.md token），全局种子统一
        const brandPine = Color(0xFF1F6F54);
        return ListenableBuilder(
          listenable: prefs,
          builder: (context, _) => MaterialApp(
            title: 'PullRead 拉读',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: brandPine),
              // 页面底色统一为纯白（手机应用最常见），M3 种子默认的
              // 灰调 surface 不再使用；深色保持种子默认
              scaffoldBackgroundColor: Colors.white,
              useMaterial3: true,
              pageTransitionsTheme: transitions,
              snackBarTheme: snackbar,
              cardTheme: card,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: brandPine,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              pageTransitionsTheme: transitions,
              snackBarTheme: snackbar,
              cardTheme: card,
            ),
            themeMode: prefs.mode,
            home: const HomePage(),
          ),
        );
      },
    );
  }
}

/// 初始化失败（libgit2 / CA 证书 / 偏好加载）时的兜底页：
/// 不再无限停在闪屏，给出可读错误与重试入口。
class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Image(
                  image: AssetImage('assets/icon/app_logo.png'),
                  width: 96,
                ),
                const SizedBox(height: 24),
                const Text(
                  '初始化失败',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF1F2937),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
