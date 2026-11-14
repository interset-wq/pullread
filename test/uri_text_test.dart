import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/books/book_outline.dart';
import 'package:pullread/src/utils/uri_text.dart';

/// 回归：真实仓库（hello-agents docsify 侧栏）的链接是
/// 「未编码中文 + %20」混合，Uri.decodeFull 会抛
/// Illegal percent encoding，导致整本电子书章节打不开。
void main() {
  test('lenient decoder handles mixed unencoded-CJK and %20', () {
    expect(
      decodeUriPathLenient('chapter1/第一章%20初识智能体.md'),
      'chapter1/第一章 初识智能体.md',
    );
  });

  test('lenient decoder decodes multibyte UTF-8 escapes', () {
    // %E4%B8%AD = 中
    expect(decodeUriPathLenient('docs/%E4%B8%AD.md'), 'docs/中.md');
  });

  test('lenient decoder keeps literal percent and malformed escapes', () {
    expect(decodeUriPathLenient('100%.md'), '100%.md');
    expect(decodeUriPathLenient('%zz.md'), '%zz.md');
    expect(decodeUriPathLenient('plain.md'), 'plain.md');
  });

  test('sidebar links with mixed encoding resolve to decodable paths', () {
    final chapters = BookOutlineReader.parseOutlineMarkdown(
      '- [第一章 初识智能体](./chapter1/第一章%20初识智能体.md)\n'
      '  - [前言](./前言.md)',
      rootPath: 'docs',
    );
    expect(chapters, hasLength(2));
    expect(
      chapters.first.path,
      'docs/chapter1/第一章 初识智能体.md',
    );
  });
}
