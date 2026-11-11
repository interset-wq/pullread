import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/ui/repo_image.dart';

/// 回归：本地仓库里的 SVG 必须走 flutter_svg，而不是只认位图的 Image.file。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local .svg renders through SvgPicture', (tester) async {
    final repo = Directory.systemTemp.createTempSync('reader-svg-repo');
    addTearDown(() {
      if (repo.existsSync()) repo.deleteSync(recursive: true);
    });
    File('${repo.path}${Platform.pathSeparator}diagram.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="80">'
      '<rect width="120" height="80" fill="#4c8f56"/></svg>',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: buildRepoImage('diagram.svg', baseDir: repo.path),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('uppercase .SVG is recognised too', (tester) async {
    final repo = Directory.systemTemp.createTempSync('reader-svg-upper');
    addTearDown(() {
      if (repo.existsSync()) repo.deleteSync(recursive: true);
    });
    File('${repo.path}${Platform.pathSeparator}ARCH.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
      '<circle cx="5" cy="5" r="5"/></svg>',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildRepoImage('ARCH.SVG', baseDir: repo.path),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
