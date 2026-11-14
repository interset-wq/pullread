import 'dart:io';

import '../../git/repo_meta.dart';
import '../../local/local_folder_service.dart';
import '../../notes/code_outline.dart';
import '../../notes/ipynb.dart';
import '../../notes/markdown_source.dart';
import '../../notes/note_scanner.dart';
import '../../notes/toc.dart';
import '../../theme/app_prefs.dart';
import '../../utils/text_encoding.dart';

/// 单篇文档的加载与解析状态。
///
/// 只负责“把文件变成可渲染的正文 + 元数据”，不碰 Scaffold、滚动、查找条等
/// 视图状态；[ReaderPane] 继续持有这些 UI 状态，分屏/电子书共用同一份解析。
class ReaderController {
  ReaderController({required this.note, required this.repoRoot});

  final NoteFile note;
  final String repoRoot;

  String? title;
  List<String> tags = const [];

  /// 渲染用正文（front-matter/ipynb 转换之后），与 [toc] 行号同一坐标系。
  String? bodySource;
  List<TocEntry> toc = const [];
  List<String> imageUrls = const [];

  /// 原始文件内容（Raw 视图、导出、编辑器回写使用）。
  String? rawSource;
  List<CodeSymbol> rawOutline = const [];

  int readingMinutes = 0;

  String get displayTitle => title ?? note.fileName;

  bool get rawIsNotebook => note.absolutePath.toLowerCase().endsWith('.ipynb');

  String get rawLanguage => rawIsNotebook ? 'json' : 'markdown';

  /// 读取当前文件并刷新解析状态，返回渲染正文。
  Future<String> load() async {
    String raw;
    try {
      raw = decodeTextBytes(await File(note.absolutePath).readAsBytes());
    } on FileSystemException catch (error) {
      // 带上路径与 OS 原因：长路径、权限、文件消失等在报错里能直接分辨
      throw FileSystemException(
        '读取文件失败：${error.message}（${error.osError?.message ?? error.message}）\n'
        '${note.absolutePath}',
        note.absolutePath,
        error.osError,
      );
    }
    rawSource = raw;
    rawOutline = _buildRawOutline(raw);
    RepoMeta.touchLastOpened(repoRoot, note.relativePath);
    RepoMeta.pushRecent(
      repoRoot,
      note.relativePath,
      limit: AppPrefs.instance?.recentsLimit ?? 5,
      // 本地镜像没有 .git，显式让所有镜像共用 <docs>/local 的全局记录，
      // 否则每个镜像各写一份，首页无法跨来源按时间排序。
      recentsRoot:
          LocalFolderService.isLocalMirror(repoRoot)
              ? File(repoRoot).parent.path
              : null,
    );
    final isMdx = note.absolutePath.toLowerCase().endsWith('.mdx');
    var body = raw;
    if (rawIsNotebook) {
      body = IpynbConverter.toMarkdown(raw);
    } else {
      final fm = FrontMatter.parse(raw);
      title = fm.title;
      tags = fm.tags;
      body = fm.body;
      // .mdx 的顶层 import/export 与 MDX 注释不参与阅读排版，
      // 但原始源码视图（[rawSource]）仍保留完整内容。
      if (isMdx) body = stripMdxModuleSyntax(body);
    }
    body = normalizeHtmlImages(body);
    bodySource = body;
    toc = extractToc(body);
    imageUrls = collectImageUrls(body);
    readingMinutes = estimateReadingMinutes(body);
    return body;
  }

  /// Raw 大纲：Markdown 复用 TOC 的标题解析（跳过围栏代码块），
  /// notebook 原文是 JSON，按代码启发式解析（通常为空）。
  List<CodeSymbol> _buildRawOutline(String raw) {
    if (rawIsNotebook) {
      final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      return extractCodeOutline(text, 'json');
    }
    return extractToc(raw)
        .take(maxCodeSymbols)
        .map(
          (entry) => CodeSymbol(
            line: entry.line + 1,
            name: entry.text,
            kind: 'section',
          ),
        )
        .toList(growable: false);
  }
}
