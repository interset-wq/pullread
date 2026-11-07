import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';

import '../notes/code_outline.dart';
import '../search/text_search.dart';
import 'code_font.dart';
import 'copy_button.dart';
import 'h_scrollbar.dart';

/// 代码/源码正文的共用视图：语法高亮、行号、横向滚动/自动换行、文内查找、
/// 大纲跳转与按行选区复制。
///
/// 文件查看（[CodeViewerPage]）与 Markdown 的 Raw 模式共用这一份渲染逻辑，
/// 避免两套实现行为漂移。内容由调用方读入内存后传入，本组件不碰文件。
class CodeView extends StatefulWidget {
  const CodeView({
    required this.content,
    required this.language,
    this.outline,
    this.controller,
    this.showHeader = true,
    super.key,
  });

  final String content;

  /// highlight.js 的语言名（如 `dart` / `markdown` / `json`）。
  final String language;

  /// 大纲符号；为 null 时按 [language] 对内容做启发式解析。
  final List<CodeSymbol>? outline;

  /// 供宿主 AppBar 开关查找/换行、打开大纲与滚动到底/顶。
  final CodeViewController? controller;

  /// 顶部信息栏（语言、行数、复制）。
  final bool showHeader;

  @override
  State<CodeView> createState() => _CodeViewState();
}

/// [CodeView] 的外部控制接口：宿主页面把查找/换行/大纲按钮放在自己的
/// AppBar 里，两边共用同一份状态。
class CodeViewController extends ChangeNotifier {
  _CodeViewState? _state;

  bool get findOpen => _state?._findOpen ?? false;
  bool get wrap => _state?._wrap ?? false;

  void _notifyChanged() => notifyListeners();

  void toggleFind() => _state?._toggleFind();
  void closeFind() => _state?._closeFind();
  void toggleWrap() => _state?._toggleWrap();
  void showOutline(BuildContext context) => _state?._showOutline(context);
  void scrollToTop() => _state?._scrollToTop();
  void scrollToBottom() => _state?._scrollToBottom();
}

class _CodeViewState extends State<CodeView> {
  static const _fontSize = 13.0;
  static const _lineHeightFactor = 1.5;
  static const _topPadding = 16.0;

  /// 实际渲染行高（逻辑像素），由 [_measureLineHeight] 在 build 时更新。
  ///
  /// 不能直接用 `fontSize * height`（13 × 1.5 = 19.5）：引擎会按字体度量
  /// 与整数像素取整，JetBrains Mono 在 13px / 1.5 下实际是 20.0。每行差
  /// 0.5px，选中几十行后高亮就会肉眼可见地偏移。
  double _lineHeight = _fontSize * _lineHeightFactor;

  late String _text;
  late List<String> _lines;
  late List<CodeSymbol> _outline;

  final _verticalController = ScrollController();
  final _currentLine = ValueNotifier<int>(1);

  /// 自动换行：开启后长行折行显示，行号列隐藏（折行后行号对不齐）。
  bool _wrap = false;

  // ---- 文内查找 ----
  bool _findOpen = false;
  final _findController = TextEditingController();
  String _findQuery = '';
  List<TextMatch> _matches = const [];
  int _findIndex = -1;

  // ---- 行选区复制：长按锚点行，点选扩展区间 ----
  int? _selAnchor;
  int? _selFocus;

  @override
  void initState() {
    super.initState();
    _text = _normalize(widget.content);
    _lines = _text.split('\n');
    _outline = widget.outline ?? extractCodeOutline(_text, widget.language);
    _verticalController.addListener(_onScroll);
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller!._state = null;
      }
      widget.controller?._state = this;
    }
    if (oldWidget.content != widget.content ||
        oldWidget.language != widget.language) {
      _text = _normalize(widget.content);
      _lines = _text.split('\n');
      _outline = widget.outline ?? extractCodeOutline(_text, widget.language);
      _selAnchor = null;
      _selFocus = null;
      _findOpen = false;
      _findQuery = '';
      _matches = const [];
      _findIndex = -1;
      _findController.clear();
      _currentLine.value = 1;
      if (_verticalController.hasClients) _verticalController.jumpTo(0);
    } else if (oldWidget.outline != widget.outline) {
      _outline = widget.outline ?? extractCodeOutline(_text, widget.language);
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller!._state = null;
    }
    _verticalController.removeListener(_onScroll);
    _verticalController.dispose();
    _currentLine.dispose();
    _findController.dispose();
    super.dispose();
  }

  static String _normalize(String content) =>
      content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  void _notifyHost() => widget.controller?._notifyChanged();

  void _onScroll() {
    if (!_verticalController.hasClients) return;
    final line =
        ((_verticalController.offset - _topPadding) / _lineHeight).floor() + 1;
    final clamped = line < 1 ? 1 : line;
    if (clamped != _currentLine.value) _currentLine.value = clamped;
  }

  /// 跳到第 [line] 行（1 基）：按固定行高估算偏移。
  void _jumpToLine(int line) {
    if (!_verticalController.hasClients) return;
    final max = _verticalController.position.maxScrollExtent;
    final offset = _topPadding + (line - 1) * _lineHeight;
    _verticalController.animateTo(
      offset.clamp(0.0, max),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _scrollToTop() {
    if (!_verticalController.hasClients) return;
    _verticalController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    if (!_verticalController.hasClients) return;
    _verticalController.animateTo(
      _verticalController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _showOutline(BuildContext context) {
    if (_outline.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有识别到可跳转的符号'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (sheetContext, scrollController) =>
            ValueListenableBuilder<int>(
              valueListenable: _currentLine,
              builder: (sheetContext, currentLine, _) => ListView.builder(
                controller: scrollController,
                itemCount: _outline.length,
                itemBuilder: (sheetContext, i) {
                  final symbol = _outline[i];
                  final nextLine = i + 1 < _outline.length
                      ? _outline[i + 1].line
                      : 1 << 30;
                  final isCurrent =
                      currentLine >= symbol.line && currentLine < nextLine;
                  return ListTile(
                    dense: true,
                    selected: isCurrent,
                    leading: Icon(_iconFor(symbol.kind), size: 18),
                    title: Text(
                      symbol.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      '${symbol.line}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _jumpToLine(symbol.line);
                    },
                  );
                },
              ),
            ),
      ),
    );
  }

  static IconData _iconFor(String kind) => switch (kind) {
    'class' => Icons.category_outlined,
    'section' => Icons.segment,
    _ => Icons.functions,
  };

  // ---- 文内查找 ----

  void _toggleFind() {
    if (_findOpen) {
      _closeFind();
      return;
    }
    setState(() => _findOpen = true);
    _notifyHost();
  }

  void _closeFind() {
    setState(() {
      _findOpen = false;
      _findQuery = '';
      _matches = const [];
      _findIndex = -1;
    });
    _findController.clear();
    _notifyHost();
  }

  void _onFindChanged(String value) {
    final query = value.trim();
    final matches = query.isEmpty
        ? const <TextMatch>[]
        : findTextMatches(_text, query);
    setState(() {
      _findQuery = query;
      _matches = matches;
      _findIndex = matches.isEmpty ? -1 : 0;
    });
    if (matches.isNotEmpty) _jumpToLine(matches.first.line + 1);
  }

  void _stepMatch(int delta) {
    if (_matches.isEmpty) return;
    final next = (_findIndex + delta + _matches.length) % _matches.length;
    setState(() => _findIndex = next);
    _jumpToLine(_matches[next].line + 1);
  }

  // ---- 行选区复制 ----

  void _toggleWrap() {
    setState(() {
      _wrap = !_wrap;
      _selAnchor = null;
      _selFocus = null;
    });
    _notifyHost();
  }

  /// 把视口内触摸位置换算成内容行号（0 基）；仅在非换行模式有效。
  int _lineAt(Offset localPosition) {
    final dy = localPosition.dy + _verticalController.offset - _topPadding;
    final line = (dy / _lineHeight).floor();
    return line.clamp(0, _lines.length - 1);
  }

  void _onSelectionLongPress(LongPressStartDetails d) {
    if (_wrap) return;
    final line = _lineAt(d.localPosition);
    setState(() {
      _selAnchor = line;
      _selFocus = line;
    });
  }

  void _onSelectionTapUp(TapUpDetails d) {
    if (_wrap || _selAnchor == null) return;
    setState(() => _selFocus = _lineAt(d.localPosition));
  }

  Future<void> _copySelection(int start, int end) async {
    await Clipboard.setData(
      ClipboardData(text: _lines.sublist(start, end + 1).join('\n')),
    );
    setState(() {
      _selAnchor = null;
      _selFocus = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已复制 ${start + 1}–${end + 1} 行')));
    }
  }

  Widget _buildSelectionBar(ThemeData theme, int selStart, int selEnd) {
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '已选 ${selStart + 1}–${selEnd + 1} 行',
                style: currentCodeFontStyle().copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            IconButton(
              tooltip: '复制选中行',
              icon: const Icon(Icons.copy_all),
              color: theme.colorScheme.onSecondaryContainer,
              onPressed: () => _copySelection(selStart, selEnd),
            ),
            IconButton(
              tooltip: '取消选区',
              icon: const Icon(Icons.close),
              color: theme.colorScheme.onSecondaryContainer,
              onPressed: () => setState(() {
                _selAnchor = null;
                _selFocus = null;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindBar(ThemeData theme) {
    final counter = _matches.isEmpty
        ? (_findQuery.isEmpty ? '' : '无匹配')
        : '${_findIndex + 1}/${_matches.length}';
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _findController,
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '在代码中查找',
                border: InputBorder.none,
              ),
              onChanged: _onFindChanged,
            ),
          ),
          Text(counter, style: theme.textTheme.bodySmall),
          IconButton(
            tooltip: '上一处',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: _matches.isEmpty ? null : () => _stepMatch(-1),
          ),
          IconButton(
            tooltip: '下一处',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: _matches.isEmpty ? null : () => _stepMatch(1),
          ),
          IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close),
            onPressed: _closeFind,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(70),
      child: Row(
        children: [
          Icon(Icons.code, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            widget.language,
            style: currentCodeFontStyle().copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text('${_lines.length} 行', style: theme.textTheme.bodySmall),
          const Spacer(),
          CopyButton(code: widget.content),
        ],
      ),
    );
  }

  Widget _buildLineNumbers(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, _topPadding, 6, _topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _lines.length; i++)
            Text(
              '${i + 1}',
              // 与代码正文一致：不跟随系统字体缩放（HighlightView 的
              // RichText 默认 noScaling），否则行号与代码会逐行错开。
              textScaler: TextScaler.noScaling,
              style: currentCodeFontStyle().copyWith(
                fontSize: _fontSize,
                height: _lineHeightFactor,
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }

  TextStyle get _codeTextStyle => currentCodeFontStyle().copyWith(
        fontSize: _fontSize,
        height: _lineHeightFactor,
      );

  /// 量一次真实行高：用与 [HighlightView] 完全相同的字体、字号与
  /// `TextScaler.noScaling`（HighlightView 内部的 RichText 默认不跟随
  /// 系统字体缩放），避免硬编码 `fontSize * height` 带来的累积误差。
  double _measureLineHeight() {
    final painter = TextPainter(
      text: TextSpan(text: 'M\nM', style: _codeTextStyle),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final height = painter.height / 2;
    painter.dispose();
    return height;
  }

  Widget _buildHighlight(ThemeData theme, {required EdgeInsets padding}) {
    return HighlightView(
      _text,
      language: widget.language,
      theme: theme.brightness == Brightness.dark
          ? atomOneDarkTheme
          : githubTheme,
      padding: padding,
      textStyle: _codeTextStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _lineHeight = _measureLineHeight();
    final anchor = _selAnchor;
    final focus = _selFocus;
    final selStart = anchor != null && focus != null && !_wrap
        ? (anchor < focus ? anchor : focus)
        : null;
    final selEnd = anchor != null && focus != null && !_wrap
        ? (anchor < focus ? focus : anchor)
        : null;
    return Column(
      children: [
        if (widget.showHeader) _buildInfoBar(theme),
        if (_findOpen) _buildFindBar(theme),
        if (selStart != null) _buildSelectionBar(theme, selStart, selEnd!),
        Expanded(
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            thickness: 4,
            radius: const Radius.circular(4),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: _onSelectionLongPress,
              onTapUp: _onSelectionTapUp,
              child: SingleChildScrollView(
                controller: _verticalController,
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_wrap) _buildLineNumbers(theme),
                        Expanded(
                          child: _wrap
                              ? _buildHighlight(
                                  theme,
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    _topPadding,
                                    16,
                                    _topPadding,
                                  ),
                                )
                              : HScrollbar(
                                  child: _buildHighlight(
                                    theme,
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      _topPadding,
                                      16,
                                      _topPadding,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    // 选区高亮跟着内容一起滚动（放在滚动内容里），而不是
                    // 固定在视口：滚到下方时选区仍压在正确行上。
                    if (selStart != null)
                      Positioned(
                        top: _topPadding + selStart * _lineHeight,
                        left: 0,
                        right: 0,
                        height: (selEnd! - selStart + 1) * _lineHeight,
                        child: IgnorePointer(
                          child: ColoredBox(
                            key: const ValueKey('code-selection-highlight'),
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
