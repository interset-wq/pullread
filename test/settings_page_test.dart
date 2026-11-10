import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/theme/app_prefs.dart';
import 'package:reader/src/ui/settings/data_settings_page.dart';
import 'package:reader/src/ui/settings/settings_page.dart';
import 'package:reader/src/ui/settings/settings_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppPrefs.resetForTest();
  });

  Future<AppPrefs> pumpSettings(WidgetTester tester) async {
    final prefs = await AppPrefs.load();
    await tester.pumpWidget(MaterialApp(home: SettingsPage(prefs: prefs)));
    await tester.pump(const Duration(seconds: 4));
    return prefs;
  }

  testWidgets('root shows only navigation rows and current values', (
    tester,
  ) async {
    final prefs = await pumpSettings(tester);

    for (final title in [
      '阅读与显示',
      '外观与图标',
      '仓库与同步',
      '文件显示',
      '存储与数据',
      '关于 PullRead',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('1.75 / 16 dp'), findsOneWidget);
    expect(find.text(prefs.platform.displayName), findsOneWidget);
    expect(find.text('清空收藏'), findsNothing);
    expect(find.text('检查更新'), findsNothing);
  });

  testWidgets('reading page exposes full-width sliders and reset action', (
    tester,
  ) async {
    final prefs = await pumpSettings(tester);
    await tester.tap(find.text('阅读与显示'));
    await tester.pumpAndSettle();

    expect(find.text('正文行距'), findsOneWidget);
    expect(find.byType(Slider), findsAtLeastNWidgets(2));
    expect(find.text('恢复默认'), findsOneWidget);

    await prefs.setLineHeight(2.1);
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(prefs.lineHeight, 1.75);
  });

  testWidgets('appearance hides desktop icon settings off Android', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.tap(find.text('外观与图标'));
    await tester.pumpAndSettle();

    expect(find.text('主题'), findsWidgets);
    expect(find.text('桌面图标'), findsNothing);
  });

  testWidgets('sliders persist only after the drag ends', (tester) async {
    final prefs = await pumpSettings(tester);
    await tester.tap(find.text('阅读与显示'));
    await tester.pumpAndSettle();

    final slider = find.byType(Slider).first;
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(prefs.lineHeight, 1.75);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(prefs.lineHeight, isNot(1.75));
  });

  testWidgets('username is saved on focus loss, not per keystroke', (
    tester,
  ) async {
    final prefs = await pumpSettings(tester);
    await tester.tap(find.text('仓库与同步'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'new-owner');
    await tester.pump();
    expect(prefs.defaultOwner, isEmpty);

    await tester.tap(find.text('仓库与同步'));
    await tester.pumpAndSettle();
    expect(prefs.defaultOwner, 'new-owner');
  });

  test('settings search matches titles and aliases with AND terms', () {
    expect(searchSettings('行距').map((e) => e.title), contains('正文行距'));
    expect(searchSettings('深色').map((e) => e.title), contains('主题'));
    expect(searchSettings('待写回').map((e) => e.title), contains('未写回的修改'));
    expect(searchSettings('行距 深色'), isEmpty);
    expect(searchSettings('   '), isEmpty);
    expect(searchSettings('不存在的设置项'), isEmpty);
  });

  testWidgets('search result jumps to the matching setting', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.byTooltip('搜索设置'));
    await tester.pumpAndSettle();

    expect(find.text('可直接搜索设置名或别名，例如：'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '阈值');
    await tester.pumpAndSettle();
    expect(find.text('代码折叠阈值'), findsOneWidget);
    expect(find.text('阅读与显示 · 代码块'), findsOneWidget);

    await tester.tap(find.text('代码折叠阈值'));
    await tester.pumpAndSettle();
    expect(find.text('阅读与显示'), findsOneWidget);
    expect(find.text('代码折叠阈值'), findsOneWidget);
    // 目标行在首屏之外，锚点应在进入后把它滚进可视区。
    final dy = tester.getTopLeft(find.text('代码折叠阈值')).dy;
    expect(dy, greaterThanOrEqualTo(0));
    expect(dy, lessThan(600));
  });

  testWidgets('settings fit 320 dp at 2.0 text scale in dark mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await AppPrefs.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: SettingsPage(prefs: prefs),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('阅读与显示'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('data page separates dangerous operations', (tester) async {
    final prefs = await AppPrefs.load();
    await tester.pumpWidget(MaterialApp(home: DataSettingsPage(prefs: prefs)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('危险操作'), findsOneWidget);
    expect(find.text('清空阅读历史'), findsOneWidget);
    expect(find.text('清空收藏'), findsOneWidget);
    expect(find.text('存储占用'), findsOneWidget);
    expect(find.text('未写回的修改'), findsOneWidget);
  });
}
