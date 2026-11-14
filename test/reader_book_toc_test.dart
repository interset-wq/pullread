import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/books/book.dart';
import 'package:pullread/src/notes/note_scanner.dart';
import 'package:pullread/src/ui/reader/reader_pane.dart';

void main() {
  late Directory temp;
  late NoteFile first;
  late BookOutline outline;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pullread-book-toc-');
    File('${temp.path}${Platform.pathSeparator}a.md')
        .writeAsStringSync('# 第一章\n\n正文 A');
    File('${temp.path}${Platform.pathSeparator}b.md')
        .writeAsStringSync('# 第二章\n\n正文 B');
    final files = NoteScanner().scan(temp.path);
    first = files.firstWhere((note) => note.relativePath == 'a.md');
    outline = BookOutline(
      rootPath: '',
      title: '测试书',
      source: BookOutlineSource.summary,
      chapters: const [
        BookChapter(title: '第一章', path: 'a.md'),
        BookChapter(title: '第二章', path: 'b.md'),
      ],
    );
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

  testWidgets('窄屏通过书目录弹层切换章节', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPane(
          note: first,
          repoRoot: temp.path,
          book: outline,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('书目录'), findsOneWidget);
    await tester.tap(find.byTooltip('书目录'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('第二章'), findsWidgets);
    expect(find.text('2 章'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
  });

  testWidgets('宽屏常驻书目录侧栏', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPane(
          note: first,
          repoRoot: temp.path,
          book: outline,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('书目录'), findsNothing);
    expect(find.text('1 / 2 章'), findsOneWidget);
    expect(find.text('第二章'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
  });
}
