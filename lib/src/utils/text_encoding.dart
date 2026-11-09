import 'dart:convert';

import 'package:fast_gbk/fast_gbk.dart';

/// 文本文件的原编码。解码时按 BOM / 字节内容判断，编辑器保存时按同一编码
/// 写回，避免把 GBK 或 UTF-16 笔记悄悄改成 UTF-8。
enum TextFileEncoding { utf8, utf8Bom, gbk, utf16le, utf16be }

/// 判断文本编码：BOM 优先，其次严格 UTF-8，最后回退 GBK。
///
/// UTF-16 只识别带 BOM 的文件（`FF FE` / `FE FF`）：没有 BOM 时无法可靠区分
/// UTF-16 与 GBK/二进制，宁可保持旧行为。
TextFileEncoding detectTextEncoding(List<int> bytes) {
  if (_hasPrefix(bytes, const [0xEF, 0xBB, 0xBF])) {
    return TextFileEncoding.utf8Bom;
  }
  if (_hasPrefix(bytes, const [0xFF, 0xFE])) {
    return TextFileEncoding.utf16le;
  }
  if (_hasPrefix(bytes, const [0xFE, 0xFF])) {
    return TextFileEncoding.utf16be;
  }
  try {
    utf8.decode(bytes); // 严格模式，非法字节抛 FormatException
    return TextFileEncoding.utf8;
  } on FormatException {
    return TextFileEncoding.gbk;
  }
}

/// 文本文件解码（本地 TXT / Markdown）：UTF-8（含 BOM）、UTF-16 LE/BE
/// （含 BOM）、GBK 自动识别。纯 Dart 实现，全平台可用。
String decodeTextBytes(List<int> bytes) {
  switch (detectTextEncoding(bytes)) {
    case TextFileEncoding.utf8:
      return utf8.decode(bytes);
    case TextFileEncoding.utf8Bom:
      return utf8.decode(bytes.sublist(3));
    case TextFileEncoding.utf16le:
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    case TextFileEncoding.utf16be:
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    case TextFileEncoding.gbk:
      return gbk.decode(bytes);
  }
}

/// 与 [decodeTextBytes] 配套：判断 [bytes] 是否为合法 UTF-8（允许 BOM）。
bool isUtf8Bytes(List<int> bytes) {
  final encoding = detectTextEncoding(bytes);
  return encoding == TextFileEncoding.utf8 ||
      encoding == TextFileEncoding.utf8Bom;
}

/// 按原文件编码编码文本。UTF-8 BOM 与 UTF-16 的 BOM 会原样写回；
/// GBK 无法表示的字符会由 fast_gbk 抛出异常（与旧行为一致）。
List<int> encodeTextBytes(String text, {required TextFileEncoding encoding}) {
  switch (encoding) {
    case TextFileEncoding.utf8:
      return utf8.encode(text);
    case TextFileEncoding.utf8Bom:
      return [0xEF, 0xBB, 0xBF, ...utf8.encode(text)];
    case TextFileEncoding.gbk:
      return gbk.encode(text);
    case TextFileEncoding.utf16le:
      return [0xFF, 0xFE, ..._encodeUtf16(text, littleEndian: true)];
    case TextFileEncoding.utf16be:
      return [0xFE, 0xFF, ..._encodeUtf16(text, littleEndian: false)];
  }
}

bool _hasPrefix(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  // 末尾残缺的单字节直接忽略，避免一个损坏字节让整篇笔记打不开。
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(units);
}

List<int> _encodeUtf16(String text, {required bool littleEndian}) {
  final out = <int>[];
  for (final unit in text.codeUnits) {
    if (littleEndian) {
      out
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    } else {
      out
        ..add(unit >> 8)
        ..add(unit & 0xFF);
    }
  }
  return out;
}
