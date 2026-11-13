/// Markdown 源码层面的纯处理：HTML 图片归一化、图片地址收集、阅读时长估算
/// 与标题锚点 slug。从阅读页抽出来单独成库——不依赖 Flutter，便于单测，
/// 也避免 `markdown_viewer.dart` 继续膨胀。
library;

import 'ipynb_images.dart' show htmlTableToMarkdown;

/// 匹配 <img src="...">（属性顺序任意、单双引号均可、含尾部其余属性）。
final RegExp _htmlImgRegExp = RegExp(
  r'''<img[^>]*\ssrc=["']([^"']+)["'][^>]*>''',
  caseSensitive: false,
);

/// [![alt](img)](link) 徽章式链接图片展平为纯图片。
final RegExp _badgeLinkImgRegExp = RegExp(
  r'\[!\[([^\]]*)\]\(([^)\s]+)\)\]\(([^)]+)\)',
);

/// 徽章类图片直接忽略：这些图床返回的是装饰性徽章/统计图，
/// 在正文里没有阅读价值（shields.io / contrib.rocks / star-history）。
/// **不再按 `.svg` 后缀整体忽略**：仓库里的架构图、流程图大多是 SVG，
/// 现在由 flutter_svg 渲染（本地与网络都支持）。
final RegExp _ignoredImageRegExp = RegExp(
  r'!\[[^\]]*\]\((?:'
  r'https?://img\.shields\.io/[^)]*'
  r'|https?://contrib\.rocks/[^)]*'
  r'|https?://api\.star-history\.com/[^)]*)\)',
  caseSensitive: false,
);

/// 代码保护段：围栏代码块（``` / ~~~，允许未闭合）与行内代码（单反引号）。
/// 匹配到的段落内不做任何 HTML 归一化，标签原样显示。
final RegExp _codeProtectedRegExp = RegExp(
  r'```[\s\S]*?(?:```|$)|~~~[\s\S]*?(?:~~~|$)|`[^`\n]*`',
);

/// <div><img src="x"/></div> 等 HTML 内嵌图片转 Markdown 图片语法，
/// 徽章链接展平为纯图片，同时归一化 <br> 与块级 div/p/a 包裹。
String normalizeHtmlImages(String md) {
  final out = StringBuffer();
  var cursor = 0;
  for (final m in _codeProtectedRegExp.allMatches(md)) {
    out
      ..write(_normalizeHtmlImagesPlain(md.substring(cursor, m.start)))
      ..write(m.group(0)!);
    cursor = m.end;
  }
  out.write(_normalizeHtmlImagesPlain(md.substring(cursor)));
  return out.toString();
}

/// 顶层 ESM 语句的起始行：必须从第 0 列开始，缩进内容可能是代码示例。
final RegExp _mdxModuleRegExp = RegExp(r'^(?:import|export)\b');

/// 模块语句跨行时最多吞并的行数。MDX 的组件定义可能很长，但设置上限可以
/// 避免 JSX 里未配平的字符串/模板把整篇正文当成 export 吃掉。
const int _mdxStatementMaxLines = 200;

/// `.mdx` 专用的模块语法剥离：阅读视图不显示顶层 `import` / `export`
/// 与 MDX 注释 `{/* … */}`，围栏代码块、行内代码和缩进示例原样保留。
///
/// 只影响内存中的渲染正文（阅读页与全文检索共用），不修改磁盘文件；
/// 原始源码视图仍显示完整内容。
String stripMdxModuleSyntax(String md) {
  final lines = md.split('\n');
  final out = <String>[];
  var inFence = false;
  var fence = '';
  var inComment = false;
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trimLeft();

    if (inComment) {
      final end = line.indexOf('*/}');
      if (end < 0) {
        i++;
        continue;
      }
      inComment = false;
      final rest = line.substring(end + 3);
      if (rest.trim().isNotEmpty) out.add(rest);
      i++;
      continue;
    }

    if (!inFence && (trimmed.startsWith('```') || trimmed.startsWith('~~~'))) {
      inFence = true;
      fence = trimmed.substring(0, 3);
      out.add(line);
      i++;
      continue;
    }
    if (inFence) {
      if (trimmed.startsWith(fence)) inFence = false;
      out.add(line);
      i++;
      continue;
    }

    if (_mdxModuleRegExp.hasMatch(line)) {
      final next = _skipMdxStatement(lines, i);
      i = next;
      continue;
    }

    // MDX 注释可能与正文同行，也可能跨行。
    var text = line;
    while (true) {
      final start = text.indexOf('{/*');
      if (start < 0) break;
      final end = text.indexOf('*/}', start + 3);
      if (end < 0) {
        out.add(text.substring(0, start));
        inComment = true;
        break;
      }
      text = text.replaceRange(start, end + 3, '');
    }
    if (!inComment) {
      // 删除整行注释后留下的空行没有排版价值；原文的空行保留。
      if (text.trim().isNotEmpty || line.trim().isEmpty) out.add(text);
    }
    i++;
  }
  return out.join('\n');
}

/// 跳过从 [start] 开始的一条 import/export 语句，返回下一行下标。
/// 语句未在 [_mdxStatementMaxLines] 内闭合时只删首行，避免误删正文。
int _skipMdxStatement(List<String> lines, int start) {
  var depth = 0;
  for (var i = start; i < lines.length; i++) {
    depth += _bracketDelta(lines[i]);
    final complete =
        depth <= 0 && (i > start || _mdxFirstLineComplete(lines[i]));
    final exhausted = i - start + 1 >= _mdxStatementMaxLines;
    if (complete) return i + 1;
    if (exhausted) return start + 1;
  }
  return lines.length;
}

bool _mdxFirstLineComplete(String line) {
  final t = line.trimRight();
  if (t.isEmpty) return true;
  const continues = [',', '+', '=', '(', '[', '{', '\\', '&&', '||', '?'];
  if (continues.any(t.endsWith)) return false;
  // import 没写分号时通常以引号结尾；以 `from` 结尾说明语句还没完。
  if (t.startsWith('import') &&
      !t.contains("'") &&
      !t.contains('"') &&
      !t.endsWith(';')) {
    return false;
  }
  // `export default function Foo()` / `export class Bar` 的函数体可能在下一行。
  if (t.startsWith('export') &&
      RegExp(r'\b(function|class)\b').hasMatch(t) &&
      !t.endsWith('}')) {
    return false;
  }
  return true;
}

int _bracketDelta(String line) {
  var delta = 0;
  for (final unit in line.codeUnits) {
    switch (unit) {
      case 0x7B: // {
      case 0x5B: // [
      case 0x28: // (
        delta++;
      case 0x7D: // }
      case 0x5D: // ]
      case 0x29: // )
        delta--;
    }
  }
  return delta;
}

/// 普通文本段的 HTML 归一化（调用前已剥离代码保护段）。
String _normalizeHtmlImagesPlain(String md) {
  final stripped = _convertHtmlBlocks(md)
      .replaceAllMapped(_htmlImgRegExp, (m) => '\n\n![](${m.group(1)!})\n\n')
      .replaceAllMapped(
        _badgeLinkImgRegExp,
        (m) => '![${m.group(1)!}](${m.group(2)!})',
      )
      // 无 src 的空 img 标签（<img> / <img />）与其余 img 残壳直接移除
      .replaceAll(RegExp(r'<img\b[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?a\b[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?div[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?picture[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<source\b[^>]*/?>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?center[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</?p\b[^>]*>', caseSensitive: false), '\n\n')
      // 徽章/SVG 图片在排版中无意义，直接忽略
      .replaceAll(_ignoredImageRegExp, '');
  return _convertHtmlTags(stripped);
}

/// 块级 HTML 转 Markdown：`<table>` → Markdown 表格（复用 notebook 的
/// 降级逻辑，复杂表格回退为按行剥壳的纯文本）、`<ul>/<ol>/<li>` →
/// Markdown 列表、`<blockquote>` → `>` 引用、`<hr>` → `---`。
/// 只处理不跨越代码保护段的块；含行内代码的表格会被分段拆散而保持原样。
String _convertHtmlBlocks(String md) {
  var text = md;

  // 表格：规整表格降级为 Markdown 表格；复杂表格剥壳保留行文本
  text = text.replaceAllMapped(
    RegExp(r'<table\b[^>]*>[\s\S]*?</table\s*>', caseSensitive: false),
    (m) {
      final converted = htmlTableToMarkdown(m.group(0)!);
      return '\n\n${converted ?? _htmlTableFallbackText(m.group(0)!)}\n\n';
    },
  );

  // 列表：先转最内层，外层转换时把已转好的子列表行缩进 4 空格。
  // 内容组必须惰性：闭合标签以 `</` 开头，不会被前瞻拦截，
  // 贪婪匹配会一路吞掉外层的 `</ul>`，把两层列表错并成一个。
  final innerList = RegExp(
    r'<(ul|ol)\b[^>]*>((?:(?!<[uo]l\b)[\s\S])*?)</\1\s*>',
    caseSensitive: false,
  );
  var guard = 0;
  var changed = true;
  while (changed && guard++ < 16) {
    changed = false;
    text = text.replaceFirstMapped(innerList, (m) {
      changed = true;
      return '\n\n${_htmlListToMarkdown(m.group(1)!, m.group(2)!)}\n\n';
    });
  }

  // 引用块：内容逐行加 "> "
  text = text.replaceAllMapped(
    RegExp(r'<blockquote\b[^>]*>([\s\S]*?)</blockquote\s*>', caseSensitive: false),
    (m) {
      final lines = m
          .group(1)!
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .map((l) => '> $l')
          .join('\n');
      return lines.isEmpty ? '' : '\n\n$lines\n\n';
    },
  );

  // 水平分割线
  text = text.replaceAllMapped(
    RegExp(r'<hr\b[^>]*/?>', caseSensitive: false),
    (m) => '\n\n---\n\n',
  );

  return text;
}

/// 复杂表格（rowspan/colspan 等）的回退：剥掉标签，每行一行文本。
String _htmlTableFallbackText(String html) => html
    .replaceAllMapped(
      RegExp(r'</tr\s*>', caseSensitive: false),
      (m) => '\n',
    )
    .replaceAllMapped(
      RegExp(r'</t[hd]\s*>', caseSensitive: false),
      (m) => ' ',
    )
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .split('\n')
    .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
    .where((l) => l.isNotEmpty)
    .join('\n');

/// 单层 `<ul>/<ol>` 内容转 Markdown 列表；条目内容里已转换的子列表行
/// 随条目缩进 4 空格，保持层级可读。
String _htmlListToMarkdown(String tag, String body) {
  final ordered = tag.toLowerCase() == 'ol';
  final items = RegExp(
    r'<li\b[^>]*>([\s\S]*?)</li\s*>',
    caseSensitive: false,
  ).allMatches(body).map((m) => m.group(1)!).toList();
  if (items.isEmpty) return '';
  final out = <String>[];
  for (var i = 0; i < items.length; i++) {
    final bullet = ordered ? '${i + 1}.' : '-';
    final lines = items[i]
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;
    out.add('$bullet ${lines.first}');
    for (final l in lines.skip(1)) {
      out.add('    $l');
    }
  }
  return out.join('\n');
}

/// HTML 标签转 Markdown：
/// 块级 h1-h6 → `#` 标题；strong/b→加粗、em/i→斜体、del/s/strike→删除线；
/// u/mark/kbd/sub/sup/small/span/font 等无等价语法的剥壳保留文字。
String _convertHtmlTags(String md) {
  var text = md;
  // 块级标题：<h1>标题</h1> → # 标题（多行内容取首行）
  text = text.replaceAllMapped(
    RegExp(r'<h([1-6])\b[^>]*>([\s\S]*?)</h\1\s*>', caseSensitive: false),
    (m) {
      final level = int.parse(m.group(1)!);
      final inner = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      return '\n\n${'#' * level} $inner\n\n';
    },
  );
  return text
      .replaceAllMapped(
        RegExp(r'<(strong|b)\b[^>]*>([\s\S]*?)</\1\s*>', caseSensitive: false),
        (m) => '**${m.group(2)!}**',
      )
      .replaceAllMapped(
        RegExp(r'<(em|i)\b[^>]*>([\s\S]*?)</\1\s*>', caseSensitive: false),
        (m) => '*${m.group(2)!}*',
      )
      .replaceAllMapped(
        RegExp(
          r'<(del|s|strike)\b[^>]*>([\s\S]*?)</\1\s*>',
          caseSensitive: false,
        ),
        (m) => '~~${m.group(2)!}~~',
      )
      .replaceAll(
        RegExp(
          r'</?(u|mark|kbd|sub|sup|small|span|font)\b[^>]*>',
          caseSensitive: false,
        ),
        '',
      );
}

/// 收集文档中按顺序出现的图片地址（Markdown 图片语法）。
List<String> collectImageUrls(String body) =>
    RegExp(r'!\[[^\]]*\]\(([^)\s]+)\)')
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toList();

/// 估算阅读分钟数：正文按 300 字/分钟，代码块按 200 字符/分钟折算。
int estimateReadingMinutes(String body) {
  var codeChars = 0;
  var textChars = 0;
  var inFence = false;
  for (final line in body.split('\n')) {
    final t = line.trim();
    if (t.startsWith('```') || t.startsWith('~~~')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      codeChars += t.length;
    } else {
      textChars += t.replaceAll(RegExp(r'\s'), '').length;
    }
  }
  final minutes = textChars / 300 + codeChars / 200;
  return minutes < 1 ? 1 : minutes.ceil();
}

/// 标题 → GitHub 风格锚点：小写、去特殊字符、空格转连字符（保留 CJK）。
///
/// 必须开 `unicode: true`：否则 `\p{L}` 不被识别，整个字符类会退化，
/// 把正文字符全删光（历史 bug：站内 `#标题` 锚点因此永远匹配不上）。
String slugifyHeading(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), '-');
