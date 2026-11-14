import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/ui/home_feed.dart';
import 'package:pullread/src/ui/reader/split_reader_page.dart';

void main() {
  late Directory firstSource;
  late Directory secondSource;
  late List<HomeRecentEntry> candidates;

  setUp(() {
    firstSource = Directory.systemTemp.createTempSync('pullread-split-a-');
    secondSource = Directory.systemTemp.createTempSync('pullread-split-b-');
    File('${firstSource.path}${Platform.pathSeparator}a.md')
        .writeAsStringSync('# 甲\n\n正文 A');
    File('${secondSource.path}${Platform.pathSeparator}b.md')
        .writeAsStringSync('# 乙\n\n正文 B');
    candidates = [
      HomeRecentEntry(
        source: firstSource,
        relativePath: 'a.md',
        isLocal: false,
      ),
      HomeRecentEntry(
        source: secondSource,
        relativePath: 'b.md',
        isLocal: true,
      ),
    ];
  });

  tearDown(() async {
    for (final dir in [firstSource, secondSource]) {
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  });

  testWidgets('宽屏左右栏各自打开文档', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: SplitReaderPage(candidates: candidates)),
    );
    expect(find.text('选择文档'), findsNWidgets(2));

    await tester.tap(find.text('选择文档').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('a.md'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('关闭此栏'), findsOneWidget);

    await tester.tap(find.text('选择文档').hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('b.md'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('关闭此栏'), findsNWidgets(2));
    expect(find.byType(AppBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
  });

  testWidgets('窄屏用底部切换器在左右栏之间切换', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: SplitReaderPage(candidates: candidates)),
    );
    expect(find.text('左栏'), findsOneWidget);
    expect(find.text('右栏'), findsOneWidget);
    expect(find.text('选择文档').hitTestable(), findsOneWidget);

    await tester.tap(find.text('右栏'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('选择文档').hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('b.md'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('关闭此栏').hitTestable(), findsOneWidget);

    await tester.tap(find.text('左栏'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('关闭此栏').hitTestable(), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
  });
}
