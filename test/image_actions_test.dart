import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/ui/image_actions.dart';

void main() {
  group('imageBaseName', () {
    test('network URL: decoded last segment, query stripped', () {
      expect(
        imageBaseName(
          'https://example.com/pics/%E7%A4%BA%E4%BE%8B%20%E5%9B%BE.png?x=1',
        ),
        '示例 图',
      );
    });

    test('local path: keeps file name and drops extension', () {
      expect(imageBaseName('notes/assets/pic.jpg'), 'pic');
      expect(imageBaseName(r'C:\notes\assets\pic.png'), 'pic');
    });

    test('notebook reference has a readable fallback', () {
      expect(imageBaseName('pullread-ipynb://abc123.png'), 'notebook-image');
    });

    test('empty or unsafe names fall back to image', () {
      expect(imageBaseName('https://example.com/'), 'image');
      expect(imageBaseName('a/b/..'), 'image');
      expect(imageBaseName('a/b/   .png'), 'image');
    });

    test('illegal file-system characters are replaced and length capped', () {
      final name = imageBaseName('${'x' * 80}.png');
      expect(name.length, 60);
      expect(imageBaseName('a/b/a:b*c?.png'), 'a_b_c_');
    });
  });

  testWidgets('svgToPng rasterizes vector diagrams for album/share',
      (tester) async {
    final svg = Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="80">'
        '<rect width="120" height="80" fill="#4c8f56"/></svg>',
      ),
    );
    final png = await tester.runAsync(() => svgToPng(svg));
    expect(png, isNotNull);
    expect(
      png!.take(8).toList(),
      [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    );
  });

  group('imageExtensionFor', () {
    Uint8List bytes(List<int> head) => Uint8List.fromList(head);

    test('detects common raster signatures', () {
      expect(
        imageExtensionFor(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])),
        '.png',
      );
      expect(imageExtensionFor(bytes([0xFF, 0xD8, 0xFF, 0xE0])), '.jpg');
      expect(imageExtensionFor(bytes(ascii.encode('GIF89a'))), '.gif');
      expect(imageExtensionFor(bytes([0x42, 0x4D, 0, 0])), '.bmp');
      expect(
        imageExtensionFor(
          bytes([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]),
        ),
        '.webp',
      );
    });

    test('detects svg and unknown data', () {
      expect(
        imageExtensionFor(bytes(utf8.encode('<?xml version="1.0"?><svg>'))),
        '.svg',
      );
      expect(imageExtensionFor(bytes([1, 2, 3])), '.img');
    });
  });
}
