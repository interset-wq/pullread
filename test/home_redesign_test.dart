import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reader/main.dart';
import 'package:reader/src/notes/note_index.dart';
import 'package:reader/src/notes/note_scanner.dart';
import 'package:reader/src/ui/home_feed.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 首页改版验收：区块顺序、互斥切换、去重/截断、平板横屏少内容态。
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
  late Directory reposRoot;
  late Directory repo;
  late Directory localMirror;

  const continueFile = '02-组件与生命周期.md';

  void writeFile(Directory root, String relativePath) {
    final file = File(
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('# $relativePath\n\n正文内容。');
  }

  void writeJson(File file, Map<String, Object?> data) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(data));
  }

  setUp(() {
    docs = Directory.systemTemp.createTempSync('home-redesign-');
    reposRoot = Directory('${docs.path}${Platform.pathSeparator}repos')
      ..createSync(recursive: true);
    repo = Directory('${reposRoot.path}${Platform.pathSeparator}math')
      ..createSync(recursive: true);
    Directory('${repo.path}${Platform.pathSeparator}.git').createSync();
    localMirror = Directory(
      '${docs.path}${Platform.pathSeparator}local'
      '${Platform.pathSeparator}本地笔记',
    )..createSync(recursive: true);
    File(
      '${localMirror.path}${Platform.pathSeparator}.pullread_local',
    ).writeAsStringSync('');

    final files = <String>[
      continueFile,
      for (var i = 1; i <= 8; i++)
        '${i.toString().padLeft(2, '0')}-笔记$i.md',
    ];
    for (final name in files) {
      writeFile(repo, name);
    }

    final now = DateTime(2026, 11, 10, 9);
    final recents = <String>[
      'math\t$continueFile\t${now.toIso8601String()}',
      for (var i = 1; i <= 8; i++)
        'math\t${i.toString().padLeft(2, '0')}-笔记$i.md\t'
            '${now.subtract(Duration(hours: i)).toIso8601String()}',
    ];
    writeJson(
      File('${reposRoot.path}${Platform.pathSeparator}.meta'
          '${Platform.pathSeparator}recents.json'),
      {'recents': recents},
    );
    writeJson(
      File('${reposRoot.path}${Platform.pathSeparator}.meta'
          '${Platform.pathSeparator}math.json'),
      {
        'url': 'https://atomgit.com/interset/math.git',
        'pinned': true,
        'syncedAt': now.toIso8601String(),
        'lastOpened': continueFile,
        'progress': {
          continueFile: {'f': 0.5, 'h': 2},
        },
      },
    );

    SharedPreferences.setMockInitialValues({
      'localFolders': ['file:///tmp/local||本地笔记'],
    });
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });

  tearDown(() {
    try {
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    } on Object {
      // 忽略 Windows 句柄占用
    }
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const ReaderApp());
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('手机：区块顺序、去重截断、仓库/本地互斥', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(tester);

    // 区块顺序：继续阅读 → 最近阅读 → 切换器。
    final continueY =
        tester.getTopLeft(find.textContaining('继续阅读').first).dy;
    final recentsY = tester.getTopLeft(find.text('最近阅读')).dy;
    final tabsY = tester.getTopLeft(find.text('仓库 · 1')).dy;
    expect(continueY, lessThan(recentsY));
    expect(recentsY, lessThan(tabsY));

    // 继续阅读与最近阅读去重，最近阅读最多 5 条。
    expect(find.text(continueFile), findsOneWidget);
    expect(find.byType(HomeRecentRow), findsNWidgets(5));

    // 仓库 Tab 只显示仓库，本地文件夹不出现；FAB 是仓库专用入口。
    expect(find.text('math'), findsOneWidget);
    expect(find.text('本地笔记'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    // 置顶只在标题旁出现一次，行内没有垃圾桶/图钉按钮常驻。
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    // 切到本地 Tab：仓库卡消失，出现虚线添加入口，FAB 隐藏。
    await tester.tap(find.text('本地文件夹 · 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('本地笔记'), findsOneWidget);
    expect(find.text('math'), findsNothing);
    expect(find.text('添加本地文件夹'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('平板横屏：双栏 + 单仓库热门目录', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final indexed = <NoteFile>[
      for (var i = 1; i <= 3; i++)
        NoteFile(
          relativePath: '01-入门/0$i-intro.md',
          absolutePath: '${repo.path}${Platform.pathSeparator}01-入门'
              '${Platform.pathSeparator}0$i-intro.md',
          modified: DateTime(2026, 11, i),
          sizeBytes: 100,
        ),
      for (var i = 1; i <= 2; i++)
        NoteFile(
          relativePath: '02-进阶/0$i-advanced.md',
          absolutePath: '${repo.path}${Platform.pathSeparator}02-进阶'
              '${Platform.pathSeparator}0$i-advanced.md',
          modified: DateTime(2026, 11, i),
          sizeBytes: 100,
        ),
    ];
    writeJson(
      File('${reposRoot.path}${Platform.pathSeparator}.meta'
          '${Platform.pathSeparator}index'
          '${Platform.pathSeparator}math.json'),
      jsonDecode(NoteIndexCache.encode(indexed)) as Map<String, dynamic>,
    );

    await pumpHome(tester);

    // 横屏使用自绘左栏头部，不再有整宽的 AppBar。
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('仓库内热门目录'), findsOneWidget);
    expect(find.text('01-入门'), findsOneWidget);
    expect(find.text('02-进阶'), findsOneWidget);
    // 单仓库是大卡 + 热门目录 + 轻引导卡，右栏不空。
    expect(find.byType(HomeRepoCard), findsOneWidget);
    expect(find.textContaining('添加一个仓库'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
