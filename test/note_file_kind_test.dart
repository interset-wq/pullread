import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/notes/note_scanner.dart';

/// `.mdx` 必须与检索、标签、断链检查保持同一分类（Markdown），
/// 否则搜索结果点开后会进代码查看器，文内查找对不上。
void main() {
  NoteFile note(String relativePath) => NoteFile(
    relativePath: relativePath,
    absolutePath: '/tmp/$relativePath',
    modified: DateTime(2026),
    sizeBytes: 1,
  );

  test('mdx is a Markdown note like md/ipynb', () {
    for (final path in ['a.mdx', 'b.md', 'c.markdown', 'd.ipynb']) {
      expect(note(path).isMarkdown, isTrue, reason: path);
    }
  });

  test('code and plain text stay non-Markdown', () {
    for (final path in ['a.dart', 'b.txt', 'c.json', 'd.log']) {
      expect(note(path).isMarkdown, isFalse, reason: path);
    }
  });

  test('extensions are classified once', () {
    expect(
      NoteScanner.mdExtensions
          .intersection(NoteScanner.codeExtensions),
      isEmpty,
      reason: '一个扩展名不能同时算 Markdown 和代码',
    );
  });
}
