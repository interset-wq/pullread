import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/notes/note_scanner.dart';
import 'package:pullread/src/ui/markdown_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Markdown 的 Raw 模式与代码查看器共用 CodeView：高亮、行号、查找、
/// 大纲、自动换行都应该可用。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('raw markdown uses the shared code view', (tester) async {
    final repo = Directory.systemTemp.createTempSync('raw-code-view');
    addTearDown(() {
      if (repo.existsSync()) repo.deleteSync(recursive: true);
    });
    final file = File('${repo.path}${Platform.pathSeparator}demo.md')
      ..writeAsStringSync('# Hello\n\nbody text\n\n## Second\n\nmore\n');
    final note = NoteFile(
      relativePath: 'demo.md',
      absolutePath: file.path,
      modified: file.statSync().modified,
      sizeBytes: file.lengthSync(),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: MarkdownViewerPage(note: note, repoRoot: repo.path),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Raw 模式'));
    await tester.pumpAndSettle();

    // 语法高亮 + Raw 专属工具条
    expect(find.byType(HighlightView), findsOneWidget);
    expect(find.byTooltip('大纲'), findsOneWidget);
    expect(find.byTooltip('自动换行'), findsOneWidget);

    // 文内查找在源码坐标系里工作
    await tester.tap(find.byTooltip('查找'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Hello');
    await tester.pump();
    expect(find.text('1/1'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    // 换行开关与代码查看器同款
    await tester.tap(find.byTooltip('自动换行'));
    await tester.pump();
    expect(find.byTooltip('关闭自动换行'), findsOneWidget);

    // 大纲按钮来自 Raw 源码的标题解析
    await tester.tap(find.byTooltip('大纲'));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
  });
}
