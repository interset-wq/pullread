import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/notes/note_scanner.dart';
import 'package:reader/src/ui/markdown_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归：超长目录名曾把文首面包屑撑成很多行，挤占正文；
/// 现在每段保持单行，整条面包屑横向滚动。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('long path breadcrumb stays on one line', (tester) async {
    final repo = Directory.systemTemp.createTempSync('reader-crumb-repo');
    addTearDown(() {
      if (repo.existsSync()) repo.deleteSync(recursive: true);
    });

    final first = 'hell${'l' * 120}o';
    final second = 'world${'d' * 120}';
    final dir = Directory(
      '${repo.path}${Platform.pathSeparator}$first'
      '${Platform.pathSeparator}$second',
    )..createSync(recursive: true);
    final file = File(
      '${dir.path}${Platform.pathSeparator}note.md',
    )..writeAsStringSync('# Title\n\nbody text\n');
    final note = NoteFile(
      relativePath: '$first/$second/note.md',
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

    final segment = find.text(first);
    expect(segment, findsOneWidget, reason: '面包屑应显示目录层级');

    // 换行时 RenderParagraph 会变成多行（高度数十到上百）；
    // 单行 bodySmall 的高度在 40 以内。
    expect(
      tester.getSize(segment).height,
      lessThan(40),
      reason: '长目录名不得把面包屑撑成多行',
    );

    final scroller = find.ancestor(
      of: segment,
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroller, findsOneWidget, reason: '超长面包屑应可横向滚动');
  });
}
