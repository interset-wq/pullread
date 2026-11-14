import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/notes/note_scanner.dart';
import 'package:pullread/src/ui/reader/reader_session.dart';

void main() {
  NoteFile note(String path) => NoteFile(
    relativePath: path,
    absolutePath: '/tmp/$path',
    modified: DateTime.fromMillisecondsSinceEpoch(0),
    sizeBytes: 0,
  );

  ReaderEntry entry(String path) =>
      ReaderEntry(repoRoot: '/tmp', note: note(path));

  test('设置左右栏并切换焦点', () {
    final session = ReaderSession();
    session.setPane(0, entry('a.md'));
    session.setPane(1, entry('b.md'));

    expect(session.hasTwoPanes, isTrue);
    expect(session.activePane, 1);
    expect(session.activeEntry?.note.relativePath, 'b.md');

    session.select(0);
    expect(session.activeEntry?.note.relativePath, 'a.md');
  });

  test('关闭一栏后不再算双栏', () {
    final session = ReaderSession();
    session.setPane(0, entry('a.md'));
    session.setPane(1, entry('b.md'));
    session.clearPane(1);

    expect(session.panes[1], isNull);
    expect(session.hasTwoPanes, isFalse);
  });

  test('同一篇文档不能在两栏重复打开', () {
    final session = ReaderSession();
    final first = entry('a.md');
    session.setPane(0, first);

    expect(session.isOpenElsewhere(1, first.key), isTrue);
    expect(session.isOpenElsewhere(0, first.key), isFalse);
  });
}
