import 'dart:convert';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/utils/text_encoding.dart';

void main() {
  test('UTF-8 正常解码', () {
    final bytes = utf8.encode('第一章 起始\n正文内容');
    expect(decodeTextBytes(bytes), '第一章 起始\n正文内容');
  });

  test('UTF-8 BOM 被去除', () {
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('标题')];
    expect(decodeTextBytes(bytes), '标题');
  });

  test('GBK 中文自动回退解码', () {
    final bytes =
        ascii.encode('name=') + const [0xC4, 0xE3, 0xBA, 0xC3]; // "你好" 的 GBK 编码
    expect(decodeTextBytes(bytes), 'name=你好');
  });

  test('GBK 长文（小说场景）', () {
    const text = '第三百二十章 故人重逢\n\n他推门而入，屋里灯还亮着。';
    final bytes = latin1.encode('x') + gbk.encode(text);
    expect(decodeTextBytes(bytes).substring(1), text);
  });

  test('识别原编码并按原编码写回', () {
    const text = '第一章 起始';
    final utf8Bytes = utf8.encode(text);
    final gbkBytes = gbk.encode(text);
    final utf8BomBytes = [0xEF, 0xBB, 0xBF, ...utf8Bytes];

    expect(detectTextEncoding(utf8Bytes), TextFileEncoding.utf8);
    expect(detectTextEncoding(utf8BomBytes), TextFileEncoding.utf8Bom);
    expect(detectTextEncoding(gbkBytes), TextFileEncoding.gbk);

    expect(isUtf8Bytes(utf8Bytes), isTrue);
    expect(isUtf8Bytes(utf8BomBytes), isTrue);
    expect(isUtf8Bytes(gbkBytes), isFalse);

    expect(
      utf8.decode(encodeTextBytes(text, encoding: TextFileEncoding.utf8)),
      text,
    );
    expect(
      encodeTextBytes(text, encoding: TextFileEncoding.utf8Bom),
      utf8BomBytes,
    );
    expect(
      gbk.decode(encodeTextBytes(text, encoding: TextFileEncoding.gbk)),
      text,
    );
  });

  test('UTF-16 LE/BE（含 BOM 与 emoji）解码和写回', () {
    const text = '标题 😀\n正文';
    final le = utf16Bytes(text, littleEndian: true);
    final be = utf16Bytes(text, littleEndian: false);

    expect(detectTextEncoding(le), TextFileEncoding.utf16le);
    expect(detectTextEncoding(be), TextFileEncoding.utf16be);
    expect(isUtf8Bytes(le), isFalse);
    expect(decodeTextBytes(le), text);
    expect(decodeTextBytes(be), text);

    expect(encodeTextBytes(text, encoding: TextFileEncoding.utf16le), le);
    expect(encodeTextBytes(text, encoding: TextFileEncoding.utf16be), be);
    expect(
      decodeTextBytes(
        encodeTextBytes(text, encoding: TextFileEncoding.utf16le),
      ),
      text,
    );
  });

  test('UTF-16 末尾残缺字节被忽略', () {
    final bytes = [
      ...utf16Bytes('标题', littleEndian: true),
      0x41, // 多余的单字节
    ];
    expect(decodeTextBytes(bytes), '标题');
  });
}

/// 带 BOM 的 UTF-16 编码，供测试构造真实文件字节。
List<int> utf16Bytes(String text, {required bool littleEndian}) {
  final body = <int>[];
  for (final unit in text.codeUnits) {
    if (littleEndian) {
      body
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    } else {
      body
        ..add(unit >> 8)
        ..add(unit & 0xFF);
    }
  }
  return littleEndian ? [0xFF, 0xFE, ...body] : [0xFE, 0xFF, ...body];
}
