import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/notes/markdown_source.dart';

/// 阅读时长估算与标题锚点（从阅读页拆出的纯函数）。
void main() {
  test('estimateReadingMinutes rounds up with a one-minute floor', () {
    expect(estimateReadingMinutes(''), 1);
    expect(estimateReadingMinutes('短句'), 1);
    expect(estimateReadingMinutes('字' * 600), 2);
    // 代码按 200 字符/分钟折算：600 个字符 = 3 分钟
    final code = '```\n${'x' * 600}\n```';
    expect(estimateReadingMinutes(code), 3);
  });

  test('slugifyHeading keeps CJK and dashes spaces', () {
    expect(slugifyHeading('Hello World'), 'hello-world');
    expect(slugifyHeading('第一 章：入门'), '第一-章入门');
    expect(slugifyHeading('  A  B  '), 'a-b');
    expect(slugifyHeading('C++ / Dart'), 'c-dart');
  });

  group('stripMdxModuleSyntax', () {
    test('removes top-level imports and exports', () {
      const src = """
import Default, { named } from 'pkg';
import './style.css'

export const meta = {
  title: 'Post',
  draft: false,
};

# 正文标题

export default function Layout({ children }) {
  return <div>{children}</div>;
}

真正的正文。
""";
      final out = stripMdxModuleSyntax(src);
      expect(out.contains('import'), isFalse, reason: out);
      expect(out.contains('export'), isFalse, reason: out);
      expect(out.contains('Layout'), isFalse, reason: out);
      expect(out.contains('# 正文标题'), isTrue);
      expect(out.contains('真正的正文。'), isTrue);
    });

    test('keeps imports inside fenced and indented code', () {
      const src = """
```js
import x from 'y';
```

    导入示例：import x from 'y';

正文
""";
      final out = stripMdxModuleSyntax(src);
      expect(out.contains("import x from 'y';"), isTrue);
      expect(out.contains('导入示例'), isTrue);
    });

    test('removes MDX comments and keeps surrounding text', () {
      const src = '前文 {/* 隐藏 */} 后文\n\n{/* 跨行\n注释 */}\n结尾';
      final out = stripMdxModuleSyntax(src);
      expect(out.contains('{/*'), isFalse, reason: out);
      expect(out.contains('隐藏'), isFalse);
      expect(out.contains('跨行'), isFalse);
      expect(out.contains('前文'), isTrue);
      expect(out.contains('后文'), isTrue);
      expect(out.contains('结尾'), isTrue);
    });

    test('leaves plain markdown untouched', () {
      const src =
          '# 标题\n\n正文里的 import 不是语句，exported 也不是。\n\n'
          'important: 仍在正文';
      expect(stripMdxModuleSyntax(src), src);
    });
  });
}
