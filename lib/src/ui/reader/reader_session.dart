import '../../notes/note_scanner.dart';

/// 多开阅读中的一栏：来源根目录 + 文件。
///
/// 会话只在当前页面生命周期内有效，不落盘；切换文章时直接替换该栏入口。
class ReaderEntry {
  const ReaderEntry({required this.repoRoot, required this.note});

  final String repoRoot;
  final NoteFile note;

  String get key => '$repoRoot|${note.relativePath}';
}

/// 双栏阅读会话：左右栏各自持有入口，窄屏用 [activePane] 切换显示。
class ReaderSession {
  ReaderSession({this.paneCount = 2})
    : panes = List<ReaderEntry?>.filled(paneCount, null);

  final int paneCount;
  final List<ReaderEntry?> panes;
  int activePane = 0;

  ReaderEntry? get activeEntry => panes[activePane];

  bool get isEmpty => panes.every((entry) => entry == null);

  bool get hasTwoPanes => panes.every((entry) => entry != null);

  void select(int index) {
    if (index < 0 || index >= paneCount) return;
    activePane = index;
  }

  void setPane(int index, ReaderEntry entry) {
    if (index < 0 || index >= paneCount) return;
    panes[index] = entry;
    activePane = index;
  }

  void clearPane(int index) {
    if (index < 0 || index >= paneCount) return;
    panes[index] = null;
  }

  /// 同一篇文档不在两栏重复打开。
  bool isOpenElsewhere(int index, String key) {
    for (var i = 0; i < panes.length; i++) {
      if (i != index && panes[i]?.key == key) return true;
    }
    return false;
  }
}
