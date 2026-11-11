import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/notes/math_render.dart';
import 'package:markdown/markdown.dart' as m;

void main() {
  final doc = m.Document(
    inlineSyntaxes: [MathInlineSyntax(), MathBlockSyntax()],
  );

  group('数学公式语法解析', () {
    test('行内公式 \$...\$ 生成 math 节点', () {
      final nodes = doc.parseInline('质能方程 \$E=mc^2\$ 很有名');
      final tags =
          nodes.whereType<m.Element>().map((e) => e.tag).toList();
      expect(tags.contains('math'), isTrue);
    });

    test('单个美元金额 \$100 不误判为公式', () {
      final nodes = doc.parseInline('花了 \$100 买书');
      final tags =
          nodes.whereType<m.Element>().map((e) => e.tag).toList();
      expect(tags.contains('math'), isFalse);
      final text = nodes.map((n) => n.textContent).join();
      expect(text.contains('100'), isTrue);
    });

    test('范围金额 \$100 到 \$200 不误判为公式', () {
      final nodes = doc.parseInline('预算 \$100 到 \$200 之间');
      final tags =
          nodes.whereType<m.Element>().map((e) => e.tag).toList();
      expect(tags.contains('math'), isFalse);
      final text = nodes.map((n) => n.textContent).join();
      expect(text.contains('100'), isTrue);
      expect(text.contains('200'), isTrue);
    });

    test('开闭 \$ 旁的空白不视为公式', () {
      for (final source in ['\$ x\$', '\$x \$']) {
        final tags = doc
            .parseInline(source)
            .whereType<m.Element>()
            .map((e) => e.tag)
            .toList();
        expect(tags.contains('math'), isFalse, reason: source);
      }
    });

    test('闭 \$ 后紧跟数字时不吞掉后续金额', () {
      final tags = doc
          .parseInline('公式 \$x\$2 元')
          .whereType<m.Element>()
          .map((e) => e.tag)
          .toList();
      expect(tags.contains('math'), isFalse);
    });

    test('正常行内公式仍能命中', () {
      for (final source in ['\$x\$', '\$a+b\$', '\$\\frac{1}{2}\$']) {
        final tags = doc
            .parseInline(source)
            .whereType<m.Element>()
            .map((e) => e.tag)
            .toList();
        expect(tags.contains('math'), isTrue, reason: source);
      }
    });

    test('块级公式 \$\$...\$\$ 生成 mathblock 节点', () {
      final nodes = doc.parseInline(r'$$\int_0^1 x^2 dx$$');
      final tags =
          nodes.whereType<m.Element>().map((e) => e.tag).toList();
      expect(tags.contains('mathblock'), isTrue);
    });
  });
}
