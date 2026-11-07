import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';

import '../ui/h_scrollbar.dart';

const _mathPipe = '\uE000';
const _mathEscapedPipe = '\uE001';

final _tableDelimiter = RegExp(
  r'^\s*(?:>\s*)*\|?\s*:?-{1,}:?\s*(?:\|\s*:?-{1,}:?\s*)+\|?\s*$',
);

/// GFM 表格会先按 `|` 切分单元格，再解析行内语法；公式里的绝对值/范数
/// `|x|` 会被当成列分隔符，导致最后一列从 `|` 处截断。渲染前把表格行
/// 内公式里的竖线换成私有区占位符，[MathNode] 解析前再还原。
String protectTableMathPipes(String markdown) {
  final lines = markdown.split('\n');
  final out = <String>[];
  var i = 0;
  var inFence = false;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFence = !inFence;
      out.add(line);
      i++;
      continue;
    }
    if (!inFence &&
        i + 1 < lines.length &&
        _tableDelimiter.hasMatch(lines[i + 1])) {
      out.add(_protectLine(line));
      i++;
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        out.add(_protectLine(lines[i]));
        i++;
      }
      continue;
    }
    out.add(line);
    i++;
  }
  return out.join('\n');
}

String _protectLine(String line) {
  final out = StringBuffer();
  var i = 0;
  var inCode = false;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '`') {
      inCode = !inCode;
      out.write(ch);
      i++;
      continue;
    }
    if (!inCode && ch == r'$' && (i == 0 || line[i - 1] != '\\')) {
      final width = line.startsWith(r'$$', i) ? 2 : 1;
      final delimiter = line.substring(i, i + width);
      final end = _closingDollar(line, i + width, delimiter);
      if (end > i + width) {
        final tex = line.substring(i + width, end);
        // 两端带空白的 `$5 | $10` 是金额而非公式，不能借此跨过单元格。
        if (tex.trimLeft() == tex && tex.trimRight() == tex) {
          out
            ..write(delimiter)
            ..write(_protectMathPipes(tex))
            ..write(delimiter);
          i = end + width;
          continue;
        }
      }
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

int _closingDollar(String line, int start, String delimiter) {
  var i = start;
  while (i < line.length) {
    if (line[i] == '\\') {
      i += 2;
      continue;
    }
    if (line.startsWith(delimiter, i)) {
      if (delimiter == r'$' && line.startsWith(r'$$', i)) {
        i += 2;
        continue;
      }
      return i;
    }
    i++;
  }
  return -1;
}

String _protectMathPipes(String tex) {
  final out = StringBuffer();
  var i = 0;
  while (i < tex.length) {
    final ch = tex[i];
    if (ch == '\\' && i + 1 < tex.length && tex[i + 1] == '|') {
      out.write(_mathEscapedPipe);
      i += 2;
    } else if (ch == '|') {
      out.write(_mathPipe);
      i++;
    } else {
      out.write(ch);
      i++;
    }
  }
  return out.toString();
}

String restoreMathPipes(String tex) =>
    tex.replaceAll(_mathEscapedPipe, r'\|').replaceAll(_mathPipe, '|');

/// 行内公式：`$...$`（非贪婪，不匹配 `$100` 纯数字金额）。
class MathInlineSyntax extends m.InlineSyntax {
  MathInlineSyntax() : super(r'\$([^$\n]+?)\$');

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final tex = match.group(1)!;
    parser.addNode(m.Element.text('math', tex));
    return true;
  }
}

/// 块级公式：`$$...$$`（允许跨行）。
class MathBlockSyntax extends m.InlineSyntax {
  MathBlockSyntax() : super(r'\$\$([\s\S]+?)\$\$');

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final tex = match.group(1)!;
    parser.addNode(m.Element.text('mathblock', tex));
    return true;
  }
}

/// math/mathblock 节点 → KaTeX widget。
class MathNode extends SpanNode {
  MathNode(String tex, {this.display = false}) : tex = restoreMathPipes(tex);

  final String tex;
  final bool display;

  @override
  InlineSpan build() {
    try {
      final math = Math.tex(
        tex,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        textStyle: style ?? const TextStyle(fontSize: 15),
      );
      // 块级公式超宽时横向滚动而非截断（与代码块同一模式）；
      // 行内公式保持随文流式排版
      final Widget child = display
          ? LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth.isFinite
                      ? HScrollbar(bottomPadding: 2, child: math)
                      : math,
            )
          : math;
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: child,
      );
    } on Object {
      // 解析失败时回退为等宽文本，避免整页崩溃
      return TextSpan(
        text: display ? '\$\$$tex\$\$' : '\$$tex\$',
        style: (style ?? const TextStyle()).copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      );
    }
  }
}
