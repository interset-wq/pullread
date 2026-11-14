import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/books/book.dart';

/// 目录编号 1.1.1.1：按 depth 层级进位、深层复位。
void main() {
  test('flat chapters number as 1, 2, 3', () {
    expect(computeChapterNumbers([0, 0, 0]), ['1', '2', '3']);
  });

  test('nested chapters number hierarchically and reset deep counters', () {
    // 1 / 1.1 / 1.1.1 / 1.1.2 / 1.2 / 2 / 2.1
    expect(
      computeChapterNumbers([0, 1, 2, 2, 1, 0, 1]),
      ['1', '1.1', '1.1.1', '1.1.2', '1.2', '2', '2.1'],
    );
  });

  test('negative depth is clamped to top level', () {
    expect(computeChapterNumbers([-1, 0]), ['1', '2']);
  });

  test('jumping deeper starts fresh sub-numbering', () {
    expect(
      computeChapterNumbers([0, 2, 2, 0]),
      ['1', '1.0.1', '1.0.2', '2'],
    );
  });
}
