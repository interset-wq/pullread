import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/ui/code_view.dart';

/// 行选区高亮必须和正文真实行高一致。
///
/// 回归背景：高亮高度曾按 `fontSize × height`（13 × 1.5 = 19.5）硬算，
/// 但 JetBrains Mono 在 Flutter 里实际是 20.0 一行；选中多行后每行差
/// 0.5px，高亮会逐渐偏离正文。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final data = await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf');
    final loader = FontLoader('JetBrains Mono')
      ..addFont(Future.value(ByteData.sublistView(data)));
    await loader.load();
  });

  String contentWith(int lines) =>
      List.generate(lines, (i) => 'line ${i + 1}').join('\n');

  int lineStart(String content, int index) {
    final lines = content.split('\n');
    var offset = 0;
    for (var i = 0; i < index; i++) {
      offset += lines[i].length + 1;
    }
    return offset;
  }

  RenderParagraph paragraph(WidgetTester tester) {
    return tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(HighlightView),
        matching: find.byType(RichText),
      ),
    );
  }

  Rect lineBox(RenderParagraph p, String content, int index) {
    final start = lineStart(content, index);
    final box = p
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + 1),
        )
        .first;
    return Rect.fromLTRB(box.left, box.top, box.right, box.bottom);
  }

  Offset lineCenter(WidgetTester tester, String content, int index) {
    final p = paragraph(tester);
    final box = lineBox(p, content, index);
    return p.localToGlobal(Offset(box.left + 2, box.center.dy));
  }

  testWidgets('selection highlight matches real line metrics', (tester) async {
    final content = contentWith(30);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodeView(
            content: content,
            language: 'plaintext',
            showHeader: false,
          ),
        ),
      ),
    );
    await tester.pump();

    // 长按第 5 行（0 基 4）定锚，再点第 10 行（0 基 9）扩展区间。
    await tester.longPressAt(lineCenter(tester, content, 4));
    await tester.pump();
    await tester.tapAt(lineCenter(tester, content, 9));
    await tester.pump();

    final overlay = tester.getRect(
      find.byKey(const ValueKey('code-selection-highlight')),
    );

    final p = paragraph(tester);
    final firstTop = p.localToGlobal(Offset(0, lineBox(p, content, 4).top)).dy;
    // 第 5 行到第 11 行（0 基 4 → 10）正好跨 6 个行距。
    final covered = lineBox(p, content, 10).top - lineBox(p, content, 4).top;

    // 高度必须覆盖 6 个完整行距（第 5–10 行）。旧实现按 19.5 硬算，
    // 这里会是 117 而不是真实的 120，正好能抓到这个回归。
    expect(
      overlay.height,
      closeTo(covered, 0.5),
      reason: '高亮高度应覆盖选区全部行（含行距）',
    );
    // 高亮按「行盒」绘制，起点允许比字形盒高半行以内，但不能整行错位。
    expect(
      overlay.top,
      lessThanOrEqualTo(firstTop + 0.5),
      reason: '高亮起点不应低于选区首行字形',
    );
    expect(
      overlay.top,
      greaterThan(firstTop - covered),
      reason: '高亮不应整体上移超过一行',
    );
  });
}
