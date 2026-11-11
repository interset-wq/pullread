import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:pullread/src/notes/math_render.dart';
import 'package:pullread/src/notes/note_scanner.dart';
import 'package:pullread/src/ui/markdown_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// issue #2：表格单元格里的公式含 `|` 时被 GFM 当成列分隔符，最后一列截断。
const _issueTable = r'''
| 层面 | 性质 | 载体 |
| --- | --- | --- |
| 样本空间 | 离散 | 有限词表 $\mathcal{V}$、$|\mathcal{V}|$ 和 $10^5$ |
| 输出分布 $p(x_i \mid x_{<i})$ | 离散（categorical） | 单纯形上的概率向量 |
| 整句分布 $p(x_{1:L})$ | 离散 | 可数集 $\mathcal{V}^{*}$ 上的概率质量 |
| logits $\mathbf{z}$ | 连续 | $\mathbb{R}^{|\mathcal{V}|}$ |
| 隐状态 $\mathbf{h}$ | 连续 | $\mathbb{R}^{d}$ |
| 参数 $\theta$ | 连续 | $\mathbb{R}^{P}$、$P$ 可达 $10^{12}$ |
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('表格公式管道符', () {
    test('保护后可还原，且最后一列不被截断', () {
      final protected = protectTableMathPipes(_issueTable);
      expect(restoreMathPipes(protected), _issueTable);

      final nodes = m.Document(
        extensionSet: m.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
        inlineSyntaxes: [MathInlineSyntax(), MathBlockSyntax()],
      ).parseLines(protected.split('\n'));

      final table = nodes.whereType<m.Element>().firstWhere(
        (e) => e.tag == 'table',
      );
      final body = table.children!.whereType<m.Element>().firstWhere(
        (e) => e.tag == 'tbody',
      );
      final lastCells = body.children!.whereType<m.Element>().map(
        (row) =>
            restoreMathPipes((row.children!.last as m.Element).textContent),
      );

      expect(lastCells.any((t) => t.contains(r'|\mathcal{V}|')), isTrue);
      expect(
        lastCells.any((t) => t.contains(r'\mathbb{R}^{|\mathcal{V}|}')),
        isTrue,
      );
    });

    test('表格金额不会被拼成公式', () {
      const markdown =
          '| 项目 | 价格 | 备注 |\n'
          '| --- | --- | --- |\n'
          '| A | \$5 | \$10 |\n';
      final protected = protectTableMathPipes(markdown);

      final nodes = m.Document(
        extensionSet: m.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
        inlineSyntaxes: [MathInlineSyntax(), MathBlockSyntax()],
      ).parseLines(protected.split('\n'));
      final mathTags = nodes
          .whereType<m.Element>()
          .expand((e) => e.children ?? const <m.Node>[])
          .whereType<m.Element>()
          .where((e) => e.tag == 'math')
          .length;

      expect(mathTags, 0);
    });

    test('代码块内的公式竖线保持原样', () {
      const markdown = '```\n| a | b |\n| --- | --- |\n| x | \$|x|\$ |\n```\n';
      expect(protectTableMathPipes(markdown), markdown);
    });
  });

  testWidgets('表格最后一列公式正常渲染', (tester) async {
    final repo = Directory.systemTemp.createTempSync('reader-table-math');
    addTearDown(() {
      if (repo.existsSync()) repo.deleteSync(recursive: true);
    });
    final file = File('${repo.path}${Platform.pathSeparator}note.md')
      ..writeAsStringSync(_issueTable);
    final note = NoteFile(
      relativePath: 'note.md',
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

    expect(find.byType(Math), findsNWidgets(14));
    expect(find.textContaining(r'$'), findsNothing);
  });
}
