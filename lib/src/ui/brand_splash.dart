import 'package:flutter/material.dart';

/// 品牌闪屏：纸白底 + 居中 logo。
///
/// 两处共用同一实现：`main.dart` 的初始化等待页，和 [HomePage] 首屏仓库
/// 列表还没读出来时的占位。颜色、logo 尺寸与位置完全一致，所以从原生
/// 闪屏到首页之间看起来只是一次启动，不会出现「两张启动图」或尺寸跳变。
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key, this.logoWidth = 160});

  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    // 可能运行在 MaterialApp 之外（初始化阶段没有 Directionality 祖先）
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFFBFAF6),
        child: Center(
          child: Image(
            image: const AssetImage('assets/icon/app_logo.png'),
            width: logoWidth,
          ),
        ),
      ),
    );
  }
}
