import 'dart:io';

import 'package:flutter/services.dart';

/// 一次已获得安全作用域访问权的本地文件夹。
class ScopedFolder {
  const ScopedFolder({required this.path, this.bookmark});

  /// 系统解析后的真实路径（文件夹在「文件」里被移动时会变）。
  final String path;

  /// 新的书签（书签过期时原生侧会重建），null 表示沿用原书签。
  final String? bookmark;
}

/// iOS 本地文件夹授权通道。
///
/// iOS 的沙盒不允许直接按路径长期访问用户挑选的文件夹：必须在
/// `UIDocumentPickerViewController` 里选中后创建 security-scoped bookmark，
/// 每次读写前 `startAccessingSecurityScopedResource()`，用完停止。
/// 这一段只能在原生侧完成（Dart 无法创建书签），因此走
/// `pullread/folder` 通道，实现在 `ios/Runner/FolderAccess.swift`。
///
/// Android 用 SAF、桌面用绝对路径，都不经过这里。
class IosFolderAccess {
  const IosFolderAccess._();

  static const _channel = MethodChannel('pullread/folder');

  static bool get _supported => Platform.isIOS;

  /// 弹出系统文件夹选择器，返回路径、名称与可持久化的书签。
  static Future<ScopedFolder?> pickFolder() async {
    if (!_supported) return null;
    final raw = await _channel.invokeMapMethod<String, Object?>('pickFolder');
    final path = raw?['path'] as String?;
    if (path == null || path.isEmpty) return null;
    return ScopedFolder(
      path: path,
      bookmark: raw?['bookmark'] as String?,
    );
  }

  /// 开始访问 [name] 对应的文件夹，返回解析后的路径。
  ///
  /// [bookmark] 为空时回退到原生侧按名称保存的书签。授权失效（文件夹被
  /// 删除、iCloud 未下载等）返回 null，调用方应保留旧镜像而不是清空。
  static Future<ScopedFolder?> startAccess({
    required String name,
    String? bookmark,
  }) async {
    if (!_supported) return null;
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'startAccess',
      {'name': name, 'bookmark': bookmark},
    );
    final path = raw?['path'] as String?;
    if (path == null || path.isEmpty) return null;
    return ScopedFolder(
      path: path,
      bookmark: raw?['bookmark'] as String?,
    );
  }

  /// 结束访问（必须与 [startAccess] 成对调用）。
  static Future<void> stopAccess(String path) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('stopAccess', {'path': path});
    } on Object {
      // 停止访问失败不会造成数据问题，忽略
    }
  }

  /// 删除本地文件夹时清掉原生侧保存的书签。
  static Future<void> release(String name) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('release', {'name': name});
    } on Object {
      // 忽略
    }
  }
}
