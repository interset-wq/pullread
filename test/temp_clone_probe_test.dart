import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:git2dart/git2dart.dart';

void main() {
  test('probe gitcode https clone', () {
    const url = 'https://gitcode.com/interset-wq/t.git';
    const path = '/tmp/opencode/probe-gitcode';
    final dir = Directory(path);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    try {
      final r = Repository.clone(url: url, localPath: path);
      // ignore: avoid_print
      print('CLONE OK head=${r.head.name}');
      r.free();
      // ignore: avoid_print
      print(Process.runSync('ls', ['-R', path]).stdout);
    } catch (e) {
      // ignore: avoid_print
      print('CLONE FAILED: $e');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
