import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/notes/note_scanner.dart';
import 'package:pullread/src/ui/reader/reader_pane.dart';

void main() {
  late Directory temp;
  late NoteFile note;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pullread-reader-embedded-');
    File('${temp.path}${Platform.pathSeparator}note.md').writeAsStringSync(
      '# 标题\n\n正文内容',
    );
    note = NoteScanner().scan(temp.path).single;
  });

  tearDown(() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  });

  testWidgets('嵌入形态不创建 Scaffold 或 AppBar', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderPane(
            note: note,
            repoRoot: temp.path,
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('查找'), findsOneWidget);
    expect(find.byTooltip('收藏'), findsOneWidget);
    expect(find.byTooltip('更多'), findsOneWidget);
    expect(find.text('note'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
  });
}
