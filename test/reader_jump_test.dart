import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/notes/note_scanner.dart';
import 'package:pullread/src/ui/markdown_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('jump buttons are always visible', (tester) async {
    final repo = Directory.systemTemp.createTempSync('reader-jump-repo');
    final body = List.generate(60, (i) => '段落 $i：一些足够长的正文内容。').join('\n\n');
    final file = File('${repo.path}${Platform.pathSeparator}long.md')
      ..writeAsStringSync('# 标题\n\n$body\n');

    final note = NoteFile(
      relativePath: 'long.md',
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
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 规范 3：目录主钮 + 回顶/回底副钮应始终显示（自定义样式，非 FAB 类型）
    expect(find.byTooltip('目录'), findsOneWidget);
    expect(find.byTooltip('回到顶部'), findsOneWidget);
    expect(find.byTooltip('跳到文末'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(find.byTooltip('目录'), findsOneWidget, reason: '滚动后按钮仍然显示');
    expect(find.byTooltip('回到顶部'), findsOneWidget, reason: '滚动后按钮仍然显示');
    expect(find.byTooltip('跳到文末'), findsOneWidget, reason: '滚动后按钮仍然显示');
  });
}
