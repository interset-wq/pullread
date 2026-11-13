import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:mermaid_flutter/mermaid_flutter.dart';

import '../local/local_folder_service.dart';
import '../notes/math_render.dart';
import '../theme/app_prefs.dart';
import '../theme/reading_paper.dart';
import '../utils/text_encoding.dart';
import 'code_font.dart';
import 'desktop_shortcuts.dart';

/// 本地 Markdown 编辑器：
/// 源码编辑 + 预览切换，手动保存写回镜像文件与原文件夹（Android 经 SAF、
/// 桌面直写真实路径）；未保存离开弹提醒。编辑仅针对本地文件夹（镜像），
/// 仓库内文件不提供编辑入口。
class MarkdownEditorPage extends StatefulWidget {
  const MarkdownEditorPage({
    required this.filePath,
    required this.mirrorRoot,
    required this.displayTitle,
    required this.relativePath,
    super.key,
  });

  /// 镜像文件绝对路径（dart:io 始终可写，保存的第一落点）。
  final String filePath;

  /// 镜像根目录（matchMirror 用它识别本地文件夹记录）。
  final String mirrorRoot;
  final String displayTitle;

  /// 相对镜像根的路径（`sub/a.md`）：写回原文件夹时用于定位 SAF 文档
  /// 或桌面真实路径下的同名文件。
  final String relativePath;

  @override
  State<MarkdownEditorPage> createState() => _MarkdownEditorPageState();
}

class _MarkdownEditorPageState extends State<MarkdownEditorPage> {
  late final TextEditingController _controller;
  late String _savedText;
  late final AppLifecycleListener _lifecycle;

  /// 原文件编码；保存时按同一编码写回，避免悄悄改编码。
  late final TextFileEncoding _encoding;
  bool _preview = false;
  bool _saving = false;

  bool get _dirty => _controller.text != _savedText;

  @override
  void initState() {
    super.initState();
    final bytes = File(widget.filePath).readAsBytesSync();
    _encoding = detectTextEncoding(bytes);
    _savedText = decodeTextBytes(bytes);
    _controller = TextEditingController(text: _savedText);
    // 桌面端点窗口关闭按钮不会走 Navigator.pop，必须在这里拦一次，
    // 否则未保存的修改会随窗口消失（移动端仍由 PopScope 负责）。
    _lifecycle = AppLifecycleListener(onExitRequested: _handleExitRequested);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _handleExitRequested() async {
    if (!_dirty) return AppExitResponse.exit;
    if (_saving) return AppExitResponse.cancel;
    final action = await _askDiscard();
    switch (action) {
      case 'save':
        return await _save() ? AppExitResponse.exit : AppExitResponse.cancel;
      case 'discard':
        return AppExitResponse.exit;
      default:
        return AppExitResponse.cancel;
    }
  }

  /// 保存：写镜像（dart:io 恒可写）→ 写回原文件夹（Android SAF / 桌面
  /// 真实路径）。原文件夹写回失败不阻断（镜像已保存，提示用户）。
  Future<bool> _save() async {
    if (_saving) return false;
    setState(() => _saving = true);
    final text = _controller.text;
    final encoded = encodeTextBytes(text, encoding: _encoding);
    var mirrorOk = false;
    var sourceOk = false;
    String? sourceError;
    try {
      await File(widget.filePath).writeAsBytes(encoded, flush: true);
      mirrorOk = true;
      sourceOk = await _writeBackSource(encoded);
    } on Object catch (e) {
      sourceError = e.toString();
    }
    // 源侧没写成功时记录待写回：下次打开文件夹会增量同步，若无此记录
    // 源侧的旧内容会把镜像里的修改覆盖掉（改不可见地丢失）
    if (mirrorOk) {
      if (sourceOk) {
        LocalFolderService.clearPending(widget.mirrorRoot, widget.relativePath);
      } else {
        LocalFolderService.markPending(widget.mirrorRoot, widget.relativePath);
      }
    }
    if (!mounted) return false;
    setState(() {
      _saving = false;
      if (sourceOk) _savedText = text;
    });
    if (sourceOk) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sourceError == null
              ? '镜像已保存，写回原文件夹失败；已记录，可在设置里重试'
              : '写回原文件夹失败：$sourceError（已记录，可在设置里重试）',
        ),
      ),
    );
    return false;
  }

  /// 写回用户授权的原文件夹（SAF / 桌面真实路径共用服务层实现）。
  Future<bool> _writeBackSource(List<int> bytes) async {
    final folder = await LocalFolderService.matchMirror(widget.mirrorRoot);
    if (folder == null) return false;
    return LocalFolderService.writeBack(folder, widget.relativePath, bytes);
  }

  Future<String?> _askDiscard() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的修改'),
        content: const Text('修改尚未保存，离开会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('保存并离开'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final act = await _askDiscard();
    if (!mounted) return;
    switch (act) {
      case 'save':
        if (await _save()) if (mounted) Navigator.pop(context, true);
      case 'discard':
        Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DesktopShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (!_saving) _save();
        },
      },
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _dirty) _confirmDiscard();
        },
        child: Scaffold(
        backgroundColor: ReadingPaper.resolve(context, AppPrefs.instance)
            .background,
        appBar: AppBar(
          backgroundColor:
              ReadingPaper.resolve(context, AppPrefs.instance).appBar,
          foregroundColor:
              ReadingPaper.resolve(context, AppPrefs.instance).onAppBar,
          title: Row(
            children: [
              Flexible(
                child: Text(
                  widget.displayTitle,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (_dirty)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.fiber_manual_record,
                    size: 10,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: _preview ? '编辑' : '预览',
              icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _preview = !_preview),
            ),
            IconButton(
              tooltip: '保存',
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.save_outlined,
                      color: _dirty ? theme.colorScheme.primary : null,
                    ),
              onPressed: _saving ? null : () => _save(),
            ),
          ],
        ),
        body: _preview
            ? _buildPreview(theme)
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      // 未保存状态驱动保存按钮颜色、「未保存」圆点与 PopScope.canPop；
                      // 在桌面端关闭编辑器离开时会弹提醒（canPop 不是绝对值）。
                      onChanged: (_) => setState(() {}),
                      style: currentCodeFontStyle().copyWith(
                        fontSize: 14,
                        height: AppPrefs.instance?.lineHeight ?? 1.75,
                      ),
                      decoration:
                          const InputDecoration.collapsed(hintText: ''),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  /// 预览：复用阅读页做法——MarkdownGenerator.buildWidgets 直接产出
  /// Widget 列表自行排版（数学公式/mermaid/代码高亮跟随主题）。不能用
  /// MarkdownWidget：其内部自带 ListView 滚动容器，外层再套滚动视图
  /// 纵向无界直接崩溃黑屏。预览是保存前快速校验，不追求与阅读页同保真
  /// （告警块按普通引用、details 标签剥离）。
  Widget _buildPreview(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final data = protectTableMathPipes(_stripDetails(_controller.text));
    final fontSize = 16.0;
    final generator = MarkdownGenerator(
      inlineSyntaxList: [MathInlineSyntax(), MathBlockSyntax()],
      generators: [
        SpanNodeGeneratorWithTag(
          tag: 'math',
          generator: (element, config, visitor) =>
              MathNode(element.textContent),
        ),
        SpanNodeGeneratorWithTag(
          tag: 'mathblock',
          generator: (element, config, visitor) =>
              MathNode(element.textContent, display: true),
        ),
      ],
    );
    final config = MarkdownConfig(
      configs: [
        H1Config(style: theme.textTheme.headlineSmall!),
        H2Config(style: theme.textTheme.titleLarge!),
        H3Config(style: theme.textTheme.titleMedium!),
        PConfig(
          textStyle: theme.textTheme.bodyLarge!.copyWith(
            fontSize: fontSize,
            height: AppPrefs.instance?.lineHeight ?? 1.75,
          ),
        ),
        CodeConfig(
          style: currentCodeFontStyle().copyWith(
            backgroundColor: isDark
                ? theme.colorScheme.surfaceContainerHighest.withAlpha(204)
                : const Color(0xCCeff1f3),
            color: theme.colorScheme.onSurface,
          ),
        ),
        PreConfig(
          padding: EdgeInsets.zero,
          decoration: const BoxDecoration(),
          builder: (code, language) => _previewCodeBlock(
            code.trimRight(),
            language,
            isDark ? atomOneDarkTheme : githubTheme,
            theme,
          ),
        ),
        BlockquoteConfig(
          sideColor: theme.colorScheme.primary.withAlpha(160),
          textColor: theme.colorScheme.onSurfaceVariant,
        ),
        LinkConfig(
          style: theme.textTheme.bodyLarge!.copyWith(
            fontSize: fontSize,
            color: isDark
                ? theme.colorScheme.tertiary
                : const Color(0xff0969da),
            decoration: TextDecoration.underline,
          ),
        ),
        TableConfig(
          headerRowDecoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(25),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          border: TableBorder.all(color: theme.colorScheme.outlineVariant),
        ),
        CheckBoxConfig(
          builder: (checked) => Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      // 大屏行宽限制与阅读页一致（860dp 居中），窄屏不起作用
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: generator.buildWidgets(data, config: config),
          ),
        ),
      ),
    );
  }

  /// 预览代码块：mermaid 围栏走原生图表（失败回退源码），其余直接高亮。
  Widget _previewCodeBlock(
    String code,
    String language,
    Map<String, TextStyle> highlightTheme,
    ThemeData theme,
  ) {
    if (language.toLowerCase() == 'mermaid') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: MermaidDiagram(
          source: code,
          theme: MaterialMermaidTheme.fromTheme(theme),
          errorBuilder: (context, error) => HighlightView(
            code,
            language: 'mermaid',
            theme: highlightTheme,
            textStyle: currentCodeFontStyle().copyWith(
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HighlightView(
            code,
            language: language.isEmpty ? 'text' : language,
            theme: highlightTheme,
            padding: const EdgeInsets.all(12),
            textStyle: currentCodeFontStyle().copyWith(
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// 预览数据预处理：剥离 `<details>`/`<summary>` 标签（markdown 包不解析
/// 原始 HTML 块，直接渲染会露出标签文本；summary 转为粗体行）。
String _stripDetails(String src) => src
    .replaceAll(RegExp(r'<details[^>]*>', caseSensitive: false), '')
    .replaceAll(RegExp(r'</details>', caseSensitive: false), '')
    .replaceAll(RegExp(r'<summary[^>]*>', caseSensitive: false), '**')
    .replaceAll(RegExp(r'</summary>', caseSensitive: false), '**');
