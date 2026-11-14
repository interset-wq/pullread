import 'package:flutter/material.dart';

import '../notes/note_scanner.dart';
import 'reader/reader_pane.dart';

/// 笔记阅读页：Markdown 渲染 + 代码高亮 + 相对路径图片。
/// 移动端优先：舒适边距、字号调节、顶栏菜单。
///
/// 页面壳保留公开构造，实际阅读内核由 [ReaderPane] 承担，
/// 电子书与多开阅读可直接复用内核。
class MarkdownViewerPage extends StatelessWidget {
  const MarkdownViewerPage({
    required this.note,
    required this.repoRoot,
    this.initialFindQuery,
    this.initialFraction,
    super.key,
  });

  final NoteFile note;
  final String repoRoot;

  /// 从正文搜索结果进入时携带的检索词：加载完成后自动打开查找条并
  /// 定位到第一处命中（否则用户得自己再滚到命中位置）。
  final String? initialFindQuery;

  /// 从书签进入时携带的全篇滚动比例（0~1）：加载后直接落到该位置，
  /// 优先级低于 [initialFindQuery]。与续读恢复互斥。
  final double? initialFraction;

  @override
  Widget build(BuildContext context) {
    return ReaderPane(
      note: note,
      repoRoot: repoRoot,
      initialFindQuery: initialFindQuery,
      initialFraction: initialFraction,
    );
  }
}
