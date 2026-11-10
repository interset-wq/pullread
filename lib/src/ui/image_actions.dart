import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app_settings/app_settings.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../notes/ipynb_images.dart';
import 'repo_image.dart';

/// 图片长按菜单：保存到相册 / 分享 / 复制原始地址。
///
/// 正文图片与图库共用；notebook 内嵌图没有可复制的持久地址，不显示复制项。
Future<void> showImageActions(
  BuildContext context, {
  required String src,
  required String baseDir,
}) async {
  final clean = src.trim();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final isIpynb = IpynbImageStore.isIpynbImage(clean);
  final isNetwork =
      clean.startsWith('http://') || clean.startsWith('https://');
  final action = await showModalBottomSheet<ImageAction>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('保存到相册'),
            onTap: () => Navigator.pop(sheet, ImageAction.save),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('分享图片'),
            onTap: () => Navigator.pop(sheet, ImageAction.share),
          ),
          if (!isIpynb)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(isNetwork ? '复制图片链接' : '复制图片路径'),
              onTap: () => Navigator.pop(sheet, ImageAction.copyLink),
            ),
        ],
      ),
    ),
  );
  if (action == null) return;

  if (action == ImageAction.copyLink) {
    await Clipboard.setData(ClipboardData(text: clean));
    messenger?.showSnackBar(
      SnackBar(content: Text(isNetwork ? '已复制图片链接' : '已复制图片路径')),
    );
    return;
  }

  final bytes = await loadRepoImageBytes(clean, baseDir: baseDir);
  if (bytes == null) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('图片读取失败，请稍后重试')),
    );
    return;
  }

  // SVG 转成 PNG 再落地：相册与聊天软件对矢量图支持不一，
  // 直接存/发 .svg 往往会变成无法预览的文件。
  final sourceExt = imageExtensionFor(bytes);
  final raster = sourceExt == '.svg' ? await svgToPng(bytes) : null;
  final payload = raster ?? bytes;
  final ext = raster != null ? '.png' : sourceExt;

  if (action == ImageAction.save) {
    if (!_gallerySupports(ext)) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            ext == '.svg'
                ? 'SVG 转换失败，暂不能存入相册，请使用分享'
                : '暂不支持保存这种图片格式，请使用分享',
          ),
        ),
      );
      return;
    }
    final outcome = await saveImageBytesToGallery(
      payload,
      name: imageBaseName(clean),
    );
    messenger?.showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          GallerySaveOutcome.saved => '已保存到相册「PullRead」',
          GallerySaveOutcome.denied => '未获得相册权限，保存失败',
          GallerySaveOutcome.unsupported => '该图片格式无法存入相册，请使用分享',
          GallerySaveOutcome.failed => '保存失败，请稍后重试',
        }),
        // iOS/Android 权限被拒后 SnackBar 里给一条直接出路，避免死胡同
        action: outcome == GallerySaveOutcome.denied
            ? SnackBarAction(
                label: '去设置',
                onPressed: () => AppSettings.openAppSettings(),
              )
            : null,
      ),
    );
    return;
  }

  try {
    await shareImageBytes(
      payload,
      name: imageBaseName(clean),
      extension: ext,
    );
  } on Object catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('分享失败：$e')));
  }
}

/// 把 SVG 栅格化为 PNG：相册与分享面板对矢量图支持不一致。
/// 按 viewBox 的原始尺寸渲染（最大边不超过 [maxSide]），失败返回 null。
Future<Uint8List?> svgToPng(Uint8List bytes, {int maxSide = 2048}) async {
  PictureInfo? info;
  ui.Image? image;
  try {
    info = await vg.loadPicture(SvgBytesLoader(bytes), null);
    var w = info.size.width;
    var h = info.size.height;
    if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
      w = 1024;
      h = 1024;
    }
    final longest = w > h ? w : h;
    if (longest > maxSide) {
      final scale = maxSide / longest;
      w *= scale;
      h *= scale;
    }
    image = await info.picture.toImage(
      (w < 1 ? 1 : w).round(),
      (h < 1 ? 1 : h).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } on Object {
    return null;
  } finally {
    info?.picture.dispose();
    image?.dispose();
  }
}

enum ImageAction { save, share, copyLink }

enum GallerySaveOutcome { saved, denied, unsupported, failed }

/// 存入系统相册「PullRead」；权限/格式失败都转成结果枚举，不向上抛。
Future<GallerySaveOutcome> saveImageBytesToGallery(
  Uint8List bytes, {
  required String name,
}) async {
  try {
    if (!await Gal.hasAccess(toAlbum: true)) {
      await Gal.requestAccess(toAlbum: true);
    }
    if (!await Gal.hasAccess(toAlbum: true)) {
      return GallerySaveOutcome.denied;
    }
    await Gal.putImageBytes(bytes, album: 'PullRead', name: name);
    return GallerySaveOutcome.saved;
  } on GalException catch (e) {
    return switch (e.type) {
      GalExceptionType.accessDenied => GallerySaveOutcome.denied,
      GalExceptionType.notSupportedFormat => GallerySaveOutcome.unsupported,
      _ => GallerySaveOutcome.failed,
    };
  } on Object {
    return GallerySaveOutcome.failed;
  }
}

/// 把 [RepaintBoundary] 抓成 PNG（mermaid 图表导出用）。
///
/// 像素比按最长边 2048 封顶，与 [svgToPng] 保持一致；边界尚未布局或渲染
/// 失败时返回 null，由调用方提示。
Future<Uint8List?> captureRepaintBoundaryPng(
  GlobalKey boundaryKey, {
  int maxSide = 2048,
}) async {
  final render = boundaryKey.currentContext?.findRenderObject();
  if (render is! RenderRepaintBoundary) return null;
  final longest = render.size.longestSide;
  if (longest <= 0) return null;
  final ratio = (maxSide / longest).clamp(1.0, 3.0);
  try {
    final image = await render.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } on Object {
    return null;
  }
}

/// 把图片字节写到临时文件后调起系统分享；文件在分享面板拉起后延迟清理。
Future<void> shareImageBytes(
  Uint8List bytes, {
  required String name,
  String? text,
  String? extension,
}) async {
  final dir = await getTemporaryDirectory();
  final ext = extension ?? imageExtensionFor(bytes);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File(
    '${dir.path}${Platform.pathSeparator}'
    'pullread-$stamp-${_safeSegment(name)}$ext',
  );
  await file.writeAsBytes(bytes, flush: true);
  try {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  } finally {
    // 分享面板拉起后临时文件即可清理（延迟留给慢加载的接收方）
    Future<void>.delayed(const Duration(minutes: 5), () {
      try {
        if (file.existsSync()) file.deleteSync();
      } on Object {
        // 清理失败无碍
      }
    });
  }
}

/// 生成相册/临时文件用的可读名称：去掉目录、查询串与扩展名，
/// 过滤文件系统非法字符；取不到时回退 `image`。
@visibleForTesting
String imageBaseName(String src) {
  final clean = src.trim();
  String name;
  if (IpynbImageStore.isIpynbImage(clean)) {
    name = 'notebook-image';
  } else if (clean.startsWith('http://') ||
      clean.startsWith('https://')) {
    final uri = Uri.tryParse(clean);
    final segments =
        uri?.pathSegments.where((s) => s.isNotEmpty).toList() ??
            const <String>[];
    name = segments.isEmpty ? 'image' : segments.last;
  } else {
    name = clean.split(RegExp(r'[/\\]')).last;
  }
  try {
    name = Uri.decodeComponent(name);
  } on Object {
    // 非法百分号编码保持原样
  }
  final dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  name = name
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'[\u0000-\u001f]'), '_')
      .trim()
      .replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  if (name.isEmpty) return 'image';
  return name.length > 60 ? name.substring(0, 60) : name;
}

/// 按文件头嗅探图片格式：扩展名只用于落盘/相册，绝不信任 URL 后缀。
@visibleForTesting
String imageExtensionFor(Uint8List bytes) {
  bool startsAt(int offset, List<int> sig) {
    if (bytes.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (startsAt(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return '.png';
  }
  if (startsAt(0, const [0xFF, 0xD8, 0xFF])) return '.jpg';
  if (startsAt(0, const [0x47, 0x49, 0x46, 0x38])) return '.gif';
  if (startsAt(0, const [0x42, 0x4D])) return '.bmp';
  if (startsAt(0, const [0x52, 0x49, 0x46, 0x46]) &&
      startsAt(8, const [0x57, 0x45, 0x42, 0x50])) {
    return '.webp';
  }
  if (looksLikeSvg(bytes)) return '.svg';
  return '.img';
}

bool _gallerySupports(String ext) =>
    ext == '.png' || ext == '.jpg' || ext == '.gif' || ext == '.bmp' ||
    ext == '.webp';

String _safeSegment(String name) {
  final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return safe.isEmpty ? 'image' : safe;
}
