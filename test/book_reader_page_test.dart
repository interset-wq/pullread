import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/git/repo_meta.dart';
import 'package:pullread/src/notes/note_scanner.dart';
import 'package:pullread/src/ui/reader/book_reader_page.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pullread-book-ui-');
    File('${temp.path}${Platform.pathSeparator}SUMMARY.md').writeAsStringSync(
      '# 测试书\n\n- [第一章](a.md)\n- [第二章](b.md)\n',
    );
    File('${temp.path}${Platform.pathSeparator}a.md')
        .writeAsStringSync('# 第一章\n\n正文 A');
    File('${temp.path}${Platform.pathSeparator}b.md')
        .writeAsStringSync('# 第二章\n\n正文 B');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final files = NoteScanner().scan(temp.path);
    await tester.pumpWidget(
      MaterialApp(
        home: BookReaderPage(repoRoot: temp.path, files: files),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('展示书单并从上次章节继续', (tester) async {
    RepoMeta.saveBookProgress(temp.path, '', 'b.md');
    await pumpPage(tester);

    expect(find.text('测试书'), findsWidgets);
    expect(find.text('第一章'), findsOneWidget);
    expect(find.text('第二章'), findsOneWidget);
    expect(find.text('继续阅读'), findsOneWidget);
    expect(find.textContaining('上次读到：第二章'), findsOneWidget);
  });

}
