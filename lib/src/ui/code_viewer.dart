import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../notes/code_outline.dart';
import '../utils/text_encoding.dart';
import 'code_view.dart';

/// 代码文件只读查看页：语法高亮 + 行号 + 大纲跳转 + 文内查找 + 自动换行。
///
/// 正文渲染与 Markdown 的 Raw 模式共用 [CodeView]，本页只负责读文件、
/// 推断语言并把工具条接到 AppBar。
class CodeViewerPage extends StatefulWidget {
  const CodeViewerPage({required this.path, required this.fileName, super.key});

  final String path;
  final String fileName;

  @override
  State<CodeViewerPage> createState() => _CodeViewerPageState();
}

class _CodeViewerPageState extends State<CodeViewerPage> {
  late Future<String> _content;
  List<CodeSymbol> _symbols = const [];
  final _controller = CodeViewController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _content = _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<String> _load() async {
    final bytes = await File(widget.path).readAsBytes();
    final text = _decode(bytes);
    _symbols = extractCodeOutline(
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
      _language,
    );
    // 大纲按钮是否可用取决于符号是否解析出来：AppBar 不随 FutureBuilder
    // 一起重建，这里主动刷新一次
    if (mounted) setState(() {});
    return text;
  }

  /// 文本解码：UTF-8 优先、GBK 兜底；仍失败时按 UTF-8 容错解码，
  /// 避免二进制兜底文件直接抛异常（旧实现用 readAsString 会整页报错）。
  static String _decode(List<int> bytes) {
    try {
      return decodeTextBytes(bytes);
    } on Object {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// 根据扩展名推断语言（映射到 highlight.js 的语言名）。
  static const _extLanguage = {
    '.dart': 'dart',
    '.py': 'python',
    '.js': 'javascript',
    '.mjs': 'javascript',
    '.ts': 'typescript',
    '.tsx': 'typescript',
    '.jsx': 'javascript',
    '.java': 'java',
    '.kt': 'kotlin',
    '.kts': 'kotlin',
    '.go': 'go',
    '.rs': 'rust',
    '.c': 'c',
    '.h': 'c',
    '.cpp': 'cpp',
    '.cc': 'cpp',
    '.hpp': 'cpp',
    '.cs': 'csharp',
    '.rb': 'ruby',
    '.php': 'php',
    '.swift': 'swift',
    '.m': 'objectivec',
    '.sh': 'bash',
    '.bash': 'bash',
    '.zsh': 'bash',
    '.json': 'json',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.toml': 'ini',
    '.xml': 'xml',
    '.html': 'xml',
    '.css': 'css',
    '.scss': 'scss',
    '.vue': 'vue',
    '.sql': 'sql',
    '.r': 'r',
    '.lua': 'lua',
    '.pl': 'perl',
    '.txt': 'plaintext',
  };

  String get _language {
    final dot = widget.fileName.lastIndexOf('.');
    if (dot == -1) return 'plaintext';
    final ext = widget.fileName.substring(dot).toLowerCase();
    return _extLanguage[ext] ?? 'plaintext';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '大纲',
            icon: const Icon(Icons.toc_outlined),
            onPressed: _symbols.isEmpty
                ? null
                : () => _controller.showOutline(context),
          ),
          IconButton(
            tooltip: _controller.findOpen ? '关闭查找' : '查找',
            icon: Icon(_controller.findOpen ? Icons.search_off : Icons.search),
            onPressed: _controller.toggleFind,
          ),
          IconButton(
            tooltip: _controller.wrap ? '关闭自动换行' : '自动换行',
            icon: Icon(
              Icons.wrap_text,
              color: _controller.wrap ? theme.colorScheme.primary : null,
            ),
            onPressed: _controller.toggleWrap,
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('无法读取文件: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return CodeView(
            content: snapshot.data!,
            language: _language,
            outline: _symbols,
            controller: _controller,
          );
        },
      ),
    );
  }
}
