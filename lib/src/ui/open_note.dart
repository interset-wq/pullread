import 'package:flutter/material.dart';

import '../git/repo_meta.dart';
import '../notes/note_scanner.dart';
import 'code_viewer.dart';
import 'image_gallery.dart';
import 'markdown_viewer.dart';

/// 打开仓库/本地镜像里的一个文件：阅读页 / 图库 / 代码查看。
///
/// 打开即清除该文件的「新增/更新」标记并记录最近打开。返回的 Future 在
/// 目标页面退出后完成，调用方可据此刷新自己的列表。
/// 无法按文本阅读、也不值得尝试解码的格式：直接提示「暂不支持预览」，
/// 不进代码查看器（二进制按文本解码只会显示乱码）。
const _unsupportedExtensions = {
  '.pdf',
  '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
  '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz',
  '.exe', '.dll', '.apk', '.ipa', '.dmg', '.msi', '.so', '.dylib',
  '.mp3', '.mp4', '.avi', '.mkv', '.mov', '.wav', '.flac', '.ogg',
  '.ttf', '.otf', '.woff', '.woff2', '.eot',
  '.psd', '.ai', '.sketch', '.ico', '.icns',
};

Future<void> openNoteFile(
  BuildContext context, {
  required String repoRoot,
  required NoteFile note,
  String? findQuery,
  double? initialFraction,
}) {
  RepoMeta.touchLastOpened(repoRoot, note.relativePath);
  RepoMeta.clearRecentChange(repoRoot, note.relativePath);
  if (note.isMarkdown) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MarkdownViewerPage(
          note: note,
          repoRoot: repoRoot,
          initialFindQuery: findQuery,
          initialFraction: initialFraction,
        ),
      ),
    );
  }
  if (note.isImage) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ImageGalleryPage(
          sources: [note.absolutePath],
          baseDir: repoRoot,
        ),
      ),
    );
  }
  if (_unsupportedExtensions.contains(note.extension.toLowerCase())) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('暂不支持预览 ${note.extension} 文件'),
      ),
    );
    return Future.value();
  }
  return Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => CodeViewerPage(
        path: note.absolutePath,
        fileName: note.fileName + note.extension,
      ),
    ),
  );
}
