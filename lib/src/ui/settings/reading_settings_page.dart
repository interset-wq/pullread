import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_prefs.dart';
import '../code_font.dart';
import 'settings_components.dart';

class ReadingSettingsPage extends StatefulWidget {
  const ReadingSettingsPage({required this.prefs, this.focus, super.key});

  final AppPrefs prefs;

  /// 从设置搜索进入时要滚动到的锚点 id。
  final String? focus;

  @override
  State<ReadingSettingsPage> createState() => _ReadingSettingsPageState();
}

class _ReadingSettingsPageState extends State<ReadingSettingsPage> {
  late double _lineHeight;
  late double _pageMargin;
  late double _codeFoldThreshold;
  late double _recentsLimit;

  AppPrefs get _prefs => widget.prefs;

  @override
  void initState() {
    super.initState();
    _lineHeight = _prefs.lineHeight;
    _pageMargin = _prefs.pageMargin;
    _codeFoldThreshold = _prefs.codeFoldThreshold.toDouble();
    _recentsLimit = _prefs.recentsLimit.toDouble();
  }

  Future<void> _reset() async {
    await _prefs.setLineHeight(1.75);
    await _prefs.setPageMargin(16);
    await _prefs.setKeepScreenOn(true);
    await _prefs.setSwipePaging(false);
    await _prefs.setWideTable(true);
    await _prefs.setDetailsExpanded(true);
    await _prefs.setCodeFont(kCodeFontJetBrains);
    await _prefs.setCodeLineNumbers(true);
    await _prefs.setCodeFoldEnabled(true);
    await _prefs.setCodeFoldThreshold(30);
    await _prefs.setRecentsLimit(5);
    if (!mounted) return;
    setState(() {
      _lineHeight = 1.75;
      _pageMargin = 16;
      _codeFoldThreshold = 30;
      _recentsLimit = 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _prefs,
      builder: (context, _) => SettingsSubpage(
        title: '阅读与显示',
        onReset: _reset,
        focus: widget.focus,
        children: [
          SettingsSection(
            title: '排版',
            help: '行距控制正文行与行之间的距离；页边距控制正文两侧的留白。',
            children: [
              SettingsSliderTile(
                anchor: 'lineHeight',
                icon: Icons.format_line_spacing_outlined,
                title: '正文行距',
                subtitle: '行高倍数',
                valueLabel: _lineHeight.toStringAsFixed(2),
                value: _lineHeight,
                min: 1.4,
                max: 2.2,
                divisions: 16,
                onChanged: (v) => setState(() => _lineHeight = v),
                onChangeEnd: (v) => unawaited(_prefs.setLineHeight(v)),
                help: '默认 1.75。数值越大，正文行与行之间越宽松。',
              ),
              SettingsSliderTile(
                anchor: 'pageMargin',
                icon: Icons.settings_overscan_outlined,
                title: '页边距',
                subtitle: '正文两侧留白',
                valueLabel: '${_pageMargin.round()} dp',
                value: _pageMargin,
                min: 8,
                max: 32,
                divisions: 12,
                onChanged: (v) => setState(() => _pageMargin = v),
                onChangeEnd: (v) => unawaited(_prefs.setPageMargin(v)),
                help: '默认 16 dp。小屏可适当减小，宽屏可适当增大。',
              ),
            ],
          ),
          SettingsSection(
            title: '阅读行为',
            children: [
              SettingsSwitchTile(
                anchor: 'keepScreenOn',
                icon: Icons.screen_lock_portrait_outlined,
                title: '屏幕常亮',
                subtitle: '阅读文章时屏幕不会自动熄灭',
                value: _prefs.keepScreenOn,
                onChanged: (v) => unawaited(_prefs.setKeepScreenOn(v)),
              ),
              SettingsSwitchTile(
                anchor: 'swipePaging',
                icon: Icons.swipe_outlined,
                title: '手势翻页',
                subtitle: '正文区左右快滑切换上一篇/下一篇',
                value: _prefs.swipePaging,
                onChanged: (v) => unawaited(_prefs.setSwipePaging(v)),
                help: '在正文区域左右快速滑动可切换上一篇/下一篇；可能与表格或代码块的横向滚动冲突。',
              ),
              SettingsSwitchTile(
                anchor: 'wideTable',
                icon: Icons.table_rows_outlined,
                title: '表格不换行',
                subtitle: '超宽表格横向滚动',
                value: _prefs.wideTable,
                onChanged: (v) => unawaited(_prefs.setWideTable(v)),
                help: '开启后表格按内容自然宽度渲染，超出屏幕时横向滚动；关闭后超宽表格自动换行。',
              ),
              SettingsSwitchTile(
                anchor: 'detailsExpanded',
                icon: Icons.subject_outlined,
                title: '折叠块默认展开',
                subtitle: 'Markdown 折叠块未指定时默认展开',
                value: _prefs.detailsExpanded,
                onChanged: (v) => unawaited(_prefs.setDetailsExpanded(v)),
              ),
            ],
          ),
          SettingsSection(
            title: '代码块',
            children: [
              SettingsAnchor(
                id: 'codeFont',
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.code_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('代码字体')),
                          SettingsHelpButton(
                            title: '代码字体',
                            message: 'Consolas 为 Windows（VS Code）系统字体；移动端缺失时自动回退到内置的 JetBrains Mono。',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: kCodeFontJetBrains,
                              label: Text('JetBrains Mono'),
                            ),
                            ButtonSegment(
                              value: kCodeFontConsolas,
                              label: Text('Consolas'),
                            ),
                          ],
                          selected: {_prefs.codeFont},
                          onSelectionChanged: (s) =>
                              unawaited(_prefs.setCodeFont(s.first)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SettingsSwitchTile(
                anchor: 'codeLineNumbers',
                icon: Icons.format_list_numbered_outlined,
                title: '代码行号',
                subtitle: '代码块左侧显示行号',
                value: _prefs.codeLineNumbers,
                onChanged: (v) => unawaited(_prefs.setCodeLineNumbers(v)),
              ),
              SettingsSwitchTile(
                anchor: 'codeFold',
                icon: Icons.unfold_more_outlined,
                title: '长代码块折叠',
                subtitle: '超过阈值的代码块默认收起',
                value: _prefs.codeFoldEnabled,
                onChanged: (v) => unawaited(_prefs.setCodeFoldEnabled(v)),
              ),
              SettingsSliderTile(
                anchor: 'codeFoldThreshold',
                icon: Icons.unfold_more_outlined,
                title: '代码折叠阈值',
                subtitle: _prefs.codeFoldEnabled ? '超过行数后默认折叠' : '先开启长代码块折叠',
                valueLabel: '${_codeFoldThreshold.round()} 行',
                value: _codeFoldThreshold,
                min: 10,
                max: 200,
                divisions: 19,
                enabled: _prefs.codeFoldEnabled,
                onChanged: (v) => setState(() => _codeFoldThreshold = v),
                onChangeEnd: (v) =>
                    unawaited(_prefs.setCodeFoldThreshold(v.round())),
              ),
            ],
          ),
          SettingsSection(
            title: '首页',
            children: [
              SettingsSliderTile(
                anchor: 'recentsLimit',
                icon: Icons.history,
                title: '最近阅读条数',
                subtitle: '首页最近阅读最多保留',
                valueLabel: '${_recentsLimit.round()} 条',
                value: _recentsLimit,
                min: 1,
                max: 20,
                divisions: 19,
                onChanged: (v) => setState(() => _recentsLimit = v),
                onChangeEnd: (v) =>
                    unawaited(_prefs.setRecentsLimit(v.round())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
