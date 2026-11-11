import 'dart:io';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/ui/code_viewer.dart';

/// 代码查看器：大纲跳转 / 文内查找 / 自动换行。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late File file;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('code-viewer');
    final buffer = StringBuffer()
      ..writeln('class Alpha {}')
      ..writeln()
      ..writeln('// 占位注释')
      ..writeln()
      ..writeln('class Beta {');
    for (var i = 0; i < 30; i++) {
      buffer.writeln('  void method$i() {}');
    }
    buffer
      ..writeln('}')
      ..writeln()
      ..writeln('void tailFunction() {}');
    file = File('${temp.path}${Platform.pathSeparator}sample.dart')
      ..writeAsStringSync(buffer.toString());
  });

  tearDown(() {
    try {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    } on Object {
      // Windows 句柄占用时忽略
    }
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodeViewerPage(path: file.path, fileName: 'sample.dart'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('outline jumps to a symbol near the end', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('大纲'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    // Beta 在第 5 行：跳过去后滚动位置应约等于 (5-1) × 行高
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    // 面包屑行是横向 Scrollable，这里要的是代码区的纵向滚动
    final scrollable = tester.state<ScrollableState>(
      find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          )
          .first,
    );
    final expected = 16.0 + 4 * 19.5;
    expect(scrollable.position.pixels, greaterThan(0), reason: '点大纲条目应滚到对应行');
    expect(scrollable.position.pixels, closeTo(expected, 40));
  });

  testWidgets('find bar counts and steps through matches', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('查找'));
    await tester.pumpAndSettle();
    expect(find.text('在代码中查找'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'tailFunction');
    await tester.pump();
    expect(find.text('1/1'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '不存在的符号');
    await tester.pump();
    expect(find.text('无匹配'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();
    expect(find.text('在代码中查找'), findsNothing);
  });

  testWidgets('wrap toggle switches line wrapping mode', (tester) async {
    await pumpPage(tester);

    expect(find.byTooltip('自动换行'), findsOneWidget);
    await tester.tap(find.byTooltip('自动换行'));
    await tester.pump();
    expect(find.byTooltip('关闭自动换行'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭自动换行'));
    await tester.pump();
    expect(find.byTooltip('自动换行'), findsOneWidget);
  });

  testWidgets('decodes GBK source instead of failing', (tester) async {
    final gbkFile = File('${temp.path}${Platform.pathSeparator}gbk.dart')
      ..writeAsBytesSync(gbk.encode('class 中文 {}\nvoid main() {}\n'));

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodeViewerPage(path: gbkFile.path, fileName: 'gbk.dart'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    final rich = tester.widget<RichText>(
      find.descendant(
        of: find.byType(HighlightView),
        matching: find.byType(RichText),
      ),
    );
    expect(rich.text.toPlainText(), contains('中文'));
  });

  testWidgets('chip row shows language dot, line count and size', (tester) async {
    await pumpPage(tester);

    // 规范 2.1：语言圆点 chip + 行数 chip + 体积 chip + 唯一复制钮
    expect(find.text('dart'), findsOneWidget);
    expect(find.textContaining('行'), findsOneWidget);
    expect(find.byTooltip('复制代码'), findsOneWidget);
  });

  testWidgets('selection shows the floating light toolbar with 4 actions',
      (tester) async {
    await pumpPage(tester);

    // 长按代码区进入选择态：底部浮出白卡工具条（复制/分享/导出长图/取消）
    final codeCenter = tester.getCenter(find.byType(HighlightView));
    await tester.longPressAt(codeCenter);
    await tester.pump();

    expect(find.byTooltip('复制选中行'), findsOneWidget);
    expect(find.byTooltip('分享选中行'), findsOneWidget);
    expect(find.byTooltip('导出长图'), findsOneWidget);
    expect(find.byTooltip('取消选区'), findsOneWidget);

    // 取消后工具条消失
    await tester.tap(find.byTooltip('取消选区'));
    await tester.pump();
    expect(find.byTooltip('复制选中行'), findsNothing);
  });

  testWidgets('wide layout shows the symbol sidebar with T/F prefixes',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    // 规范 2.3：≥1000dp 大纲侧栏常驻（T/F 前缀），AppBar 大纲钮消失
    expect(find.byTooltip('大纲'), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('T'), findsWidgets);
    expect(find.text('F'), findsWidgets);
  });
}
