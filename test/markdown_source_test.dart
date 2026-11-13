import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/notes/markdown_source.dart';

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

  group('normalizeHtmlImages: block-level HTML', () {
    test('converts a simple HTML table to a Markdown table', () {
      const src = '<table><tr><th>A</th><th>B</th></tr>'
          '<tr><td>1</td><td>2</td></tr></table>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('| A | B |'));
      expect(out, contains('| --- | --- |'));
      expect(out, contains('| 1 | 2 |'));
      expect(out.contains('<table'), isFalse, reason: out);
    });

    test('complex table falls back to stripped per-row text', () {
      const src = '<table><tr><td rowspan="2">x</td><td>y</td></tr>'
          '<tr><td>z</td></tr></table>';
      final out = normalizeHtmlImages(src);
      expect(out.contains('<t'), isFalse, reason: out);
      expect(out, contains('x y'));
      expect(out, contains('z'));
    });

    test('converts ul and ol lists', () {
      const src = '<ul><li>甲</li><li>乙</li></ul>\n'
          '<ol><li>第一</li><li>第二</li></ol>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('- 甲'));
      expect(out, contains('- 乙'));
      expect(out, contains('1. 第一'));
      expect(out, contains('2. 第二'));
      expect(out.contains('<li'), isFalse, reason: out);
    });

    test('nested lists keep hierarchy via indentation', () {
      const src = '<ul><li>外层<ul><li>内层</li></ul></li>'
          '<li>兄弟</li></ul>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('- 外层'));
      expect(out, contains('    - 内层'));
      expect(out, contains('- 兄弟'));
    });

    test('blockquote and hr are converted', () {
      const src = '<blockquote>引用一句话</blockquote>\n正文\n<hr>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('> 引用一句话'));
      expect(out, contains('---'));
      expect(out.contains('<blockquote'), isFalse);
      expect(out.contains('<hr'), isFalse);
    });

    test('HTML inside fenced code blocks is left untouched', () {
      const src = '```\n<table><tr><td>x</td></tr></table>\n<ul><li>y</li></ul>\n```';
      final out = normalizeHtmlImages(src);
      expect(out, contains('<table><tr><td>x</td></tr></table>'));
      expect(out, contains('<ul><li>y</li></ul>'));
    });
  });

  group('normalizeHtmlImages: parse hardening', () {
    test('li without closing tags auto-closes at the next li', () {
      const src = '<ul><li>甲<li>乙<li>丙</ul>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('- 甲'));
      expect(out, contains('- 乙'));
      expect(out, contains('- 丙'));
      expect(out.contains('<li'), isFalse, reason: out);
    });

    test('li auto-close keeps inline tags inside items', () {
      const src = '<ul><li>加粗<b>重点</b>结尾<li>第二项</ul>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('- 加粗**重点**结尾'));
      expect(out, contains('- 第二项'));
    });

    test('ol numbering survives unclosed li items', () {
      const src = '<ol><li>第一<li>第二<li>第三</ol>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('1. 第一'));
      expect(out, contains('2. 第二'));
      expect(out, contains('3. 第三'));
    });

    test('a href becomes a markdown link', () {
      const src = '<p>看 <a href="https://example.com/docs">文档</a> 说明</p>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('[文档](https://example.com/docs)'));
      expect(out.contains('<a'), isFalse);
    });

    test('bare a without href keeps text only', () {
      const src = '<a name="anchor">锚点文字</a>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('锚点文字'));
      expect(out.contains(']('), isFalse, reason: out);
    });

    test('javascript: href keeps label but emits no link', () {
      const src = '<a href="javascript:evil()">点我</a>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('点我'));
      expect(out.contains(']('), isFalse, reason: out);
    });

    test('html badge link flattens to a plain image', () {
      const src =
          '<a href="https://example.com/repo"><img src="https://img.example/badge.svg" alt="badge"/></a>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('![](https://img.example/badge.svg)'));
      expect(out.contains('[!['), isFalse, reason: out);
    });

    test('empty label falls back to the href as label', () {
      const src = '<a href="https://example.com"></a>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('[https://example.com](https://example.com)'));
    });

    test('html comments are removed', () {
      const src = '正文<!-- <table><tr><td>藏起来的</td></tr></table> -->续文';
      final out = normalizeHtmlImages(src);
      expect(out, contains('正文'));
      expect(out, contains('续文'));
      expect(out.contains('藏起来的'), isFalse);
      expect(out.contains('<!--'), isFalse);
    });

    test('entities are decoded in lists, headings and quotes', () {
      const src = '<ul><li>A &amp; B &gt; C</li></ul>\n'
          '<h2>标题 &quot;引用&quot;</h2>\n'
          '<blockquote>&lt;tag&gt; 与 &#39;单引号&#39;</blockquote>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('- A & B > C'));
      expect(out, contains('## 标题 "引用"'));
      expect(out, contains('> <tag> 与 \'单引号\''));
      expect(out.contains('&amp;'), isFalse, reason: out);
    });

    test('pre becomes a fenced code block with language', () {
      const src = '<pre><code class="language-dart">void main() {'
          '\n  print(&quot;hi&quot;);\n}</code></pre>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('```dart'));
      expect(out, contains('print("hi");'));
      expect(out.contains('<pre'), isFalse, reason: out);
      expect(out.contains('&quot;'), isFalse);
    });

    test('pre without language class yields a bare fence', () {
      const src = '<pre>x = 1 &amp;&amp; 2</pre>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('```\nx = 1 && 2\n```'));
      expect(out.contains('language'), isFalse, reason: out);
    });

    test('html inside pre is kept as code text, not converted', () {
      const src = '<pre><code>&lt;div&gt;&lt;img src="x.png"&gt;&lt;/div&gt;</code></pre>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('<div><img src="x.png"></div>'));
      expect(out.contains('![](x.png)'), isFalse, reason: out);
    });

    test('unclosed pre at end of document still fences its content', () {
      const src = '正文\n<pre>let a = 1;';
      final out = normalizeHtmlImages(src);
      expect(out, contains('```'));
      expect(out, contains('let a = 1;'));
    });

    test('table with thead/tbody still converts', () {
      const src = '<table><thead><tr><th>H1</th><th>H2</th></tr></thead>'
          '<tbody><tr><td>a</td><td>b</td></tr></tbody></table>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('| H1 | H2 |'));
      expect(out, contains('| a | b |'));
      expect(out.contains('<thead'), isFalse, reason: out);
    });

    test('pre inside fenced markdown code is untouched', () {
      const src = '```\n<pre><code>x</code></pre>\n```';
      final out = normalizeHtmlImages(src);
      expect(out, contains('<pre><code>x</code></pre>'));
      expect(out.contains('```dart'), isFalse);
    });
  });

  group('normalizeHtmlImages: long-tail HTML', () {
    test('unclosed ul at end of document still converts', () {
      const src = '正文\n\n<ul><li>甲<li>乙';
      final out = normalizeHtmlImages(src);
      expect(out, contains('- 甲'));
      expect(out, contains('- 乙'));
      expect(out.contains('<ul'), isFalse, reason: out);
      expect(out, contains('正文'));
    });

    test('unclosed nested ul converts inner first then outer', () {
      const src = '<ul><li>外层<ul><li>内层';
      final out = normalizeHtmlImages(src);
      expect(out, contains('- 外层'));
      expect(out, contains('    - 内层'));
      expect(out.contains('<ul'), isFalse, reason: out);
    });

    test('a closed list followed by an unclosed one converts both', () {
      const src = '<ul><li>闭合</li></ul>\n\n段落文字\n\n<ol><li>尾项';
      final out = normalizeHtmlImages(src);
      expect(out, contains('- 闭合'));
      expect(out, contains('1. 尾项'));
      expect(out, contains('段落文字'));
      expect(out.contains('<ul'), isFalse, reason: out);
      expect(out.contains('<ol'), isFalse, reason: out);
    });

    test('unclosed table falls back to stripped rows', () {
      const src = '<table><tr><td>x</td><td>y</td></tr><tr><td>a</td>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('x y'));
      expect(out, contains('a'));
      expect(out.contains('<table'), isFalse, reason: out);
      expect(out.contains('<tr'), isFalse, reason: out);
    });

    test('unclosed blockquote converts to quote lines', () {
      const src = '<blockquote>引用第一行\n引用第二行';
      final out = normalizeHtmlImages(src);
      expect(out, contains('> 引用第一行'));
      expect(out, contains('> 引用第二行'));
      expect(out.contains('<blockquote'), isFalse, reason: out);
    });

    test('dl/dt/dd becomes bold term with indented definition', () {
      const src = '<dl><dt>术语</dt><dd>这是解释</dd>'
          '<dt>第二项</dt><dd>第二个解释</dd></dl>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('**术语**'));
      expect(out, contains('    这是解释'));
      expect(out, contains('**第二项**'));
      expect(out, contains('    第二个解释'));
      expect(out.contains('<dl'), isFalse, reason: out);
      expect(out.contains('<dt'), isFalse, reason: out);
    });

    test('inline code tag becomes backticks with entities decoded', () {
      const src = '调用 <code>foo(&lt;bar&gt;)</code> 完成初始化';
      final out = normalizeHtmlImages(src);
      expect(out, contains('调用 `foo(<bar>)` 完成初始化'));
      expect(out.contains('<code'), isFalse, reason: out);
    });

    test('inline code inside a blockquote also gets backticks', () {
      const src = '<blockquote>用 <code>npm i</code> 安装</blockquote>';
      final out = normalizeHtmlImages(src);
      expect(out, contains('> 用 `npm i` 安装'));
    });
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
