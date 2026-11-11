import 'package:flutter_test/flutter_test.dart';
import 'package:pullread/src/notes/gfm_alerts.dart';

/// 告警块分割只看正文：围栏代码块里的 `> [!NOTE]` 是代码，不是告警。
void main() {
  test('splits a real alert out of the body', () {
    final segments = splitGfmAlerts(
      '正文前\n\n> [!WARNING]\n> 注意备份\n\n正文后',
    );

    expect(segments, hasLength(3));
    expect(segments[0], isA<TextSegment>());
    expect((segments[0] as TextSegment).text, '正文前\n');
    final alert = segments[1] as AlertSegment;
    expect(alert.type, GfmAlertType.warning);
    expect(alert.body, '注意备份');
    expect((segments[2] as TextSegment).text, '\n正文后');
  });

  test('alert markers inside fenced code stay code', () {
    const md = '正文\n\n```markdown\n> [!NOTE]\n> 这是示例\n```\n\n正文后';
    final segments = splitGfmAlerts(md);

    expect(segments, hasLength(1));
    expect(segments.single, isA<TextSegment>());
    expect((segments.single as TextSegment).text, md);
  });

  test('tilde fences are honored too', () {
    const md = '~~~\n> [!TIP]\n~~~\n\n> [!CAUTION]\n> 真的注意';
    final segments = splitGfmAlerts(md);

    expect(segments, hasLength(2));
    expect((segments[0] as TextSegment).text, '~~~\n> [!TIP]\n~~~\n');
    expect((segments[1] as AlertSegment).type, GfmAlertType.caution);
  });

  test('an unclosed fence never turns later quotes into alerts', () {
    const md = '```\n> [!NOTE]\n> 仍在代码里\n';
    final segments = splitGfmAlerts(md);

    expect(segments, hasLength(1));
    expect((segments.single as TextSegment).text, md);
  });

  test('indented alert markers are still recognized outside code', () {
    final segments = splitGfmAlerts('  > [!NOTE]\n  > 缩进的告警');
    expect(segments, hasLength(1));
    expect((segments.single as AlertSegment).type, GfmAlertType.note);
  });
}
