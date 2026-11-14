import 'dart:convert';

/// 宽容的 URI 路径解码。
///
/// Dart 的 `Uri.decodeFull` / `decodeComponent` 要求整串都是合法编码，
/// 真实仓库的链接常常是「未编码中文 + %20」混合（docsify/中文文档极常见），
/// 直接解码会抛 `Illegal percent encoding in URI`。这里逐段收集 %XX
/// 字节按 UTF-8 解码，其余字符原样保留，畸形转义也不会抛异常。
String decodeUriPathLenient(String input) {
  if (!input.contains('%')) return input;
  final out = StringBuffer();
  var i = 0;
  while (i < input.length) {
    if (input[i] == '%' && _isHexAt(input, i + 1)) {
      final bytes = <int>[];
      var j = i;
      while (j + 2 < input.length + 0 &&
          input[j] == '%' &&
          _isHexAt(input, j + 1)) {
        bytes.add(int.parse(input.substring(j + 1, j + 3), radix: 16));
        j += 3;
      }
      try {
        out.write(utf8.decode(bytes, allowMalformed: true));
      } on FormatException {
        out.write(input.substring(i, j));
      }
      i = j;
      continue;
    }
    out.write(input[i]);
    i++;
  }
  return out.toString();
}

bool _isHexAt(String s, int index) {
  if (index + 1 >= s.length) return false;
  final code = s.codeUnitAt(index);
  final code2 = s.codeUnitAt(index + 1);
  bool hex(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x46) ||
      (c >= 0x61 && c <= 0x66);
  return hex(code) && hex(code2);
}
