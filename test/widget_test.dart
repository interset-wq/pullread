import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pullread/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 把 path_provider 指向测试自己的临时目录。
///
/// 不注入的话，Linux 上的 `path_provider_linux` 会真的去解析 `~/Documents`
/// 并在里面建 `repos` 目录；而且这类真实 IO 在 widget test 的 fake async
/// 里不保证能完成，首页会永远停在 [BrandSplash]。
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    docs = Directory.systemTemp.createTempSync('pullread-home-');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });

  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  testWidgets('app builds home page', (tester) async {
    await tester.pumpWidget(const ReaderApp());
    // 首屏仓库列表走 fake path_provider，几帧内就绪；这里仍按固定帧数
    // 推进，避免 pumpAndSettle 撞上图片解码等不确定的异步任务。
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // 头部品牌已由文字改为 logo；设置/标签/更新收进「更多」菜单
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
  });
}
