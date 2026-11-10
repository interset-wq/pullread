import Flutter
import UIKit
import UniformTypeIdentifiers

/// iOS 本地文件夹授权。
///
/// iOS 沙盒不允许直接按路径长期访问用户挑选的文件夹：必须在
/// `UIDocumentPickerViewController` 里选中目录，创建 security-scoped
/// bookmark，之后每次读写前重新开始访问。Dart 侧无法创建书签，所以由
/// `pullread/folder` 通道调用这里的实现。
final class FolderAccess: NSObject, UIDocumentPickerDelegate {
  private static let channelName = "pullread/folder"
  private static let bookmarkKeyPrefix = "pullread.folder.bookmark."

  /// 当前已开始访问的路径，保证 start/stop 成对且不重复。
  private var activeScopes = Set<String>()

  /// 选择器一次只允许弹一个，回调也必须只回一次。
  private var pendingResult: FlutterResult?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    let instance = FolderAccess()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickFolder":
      pickFolder(result: result)
    case "startAccess":
      startAccess(call, result: result)
    case "stopAccess":
      stopAccess(call, result: result)
    case "release":
      release(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 选择文件夹

  private func pickFolder(result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(
        FlutterError(
          code: "busy",
          message: "A folder picker is already open.",
          details: nil
        )
      )
      return
    }
    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "no_presenter",
          message: "No active view controller to present the picker.",
          details: nil
        )
      )
      return
    }
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [UTType.folder],
      asCopy: false
    )
    picker.delegate = self
    picker.allowsMultipleSelection = false
    pendingResult = result
    presenter.present(picker, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    guard let url = urls.first else {
      result(nil)
      return
    }

    // 创建书签需要临时开始访问；书签本身负责之后的持久授权。
    let started = url.startAccessingSecurityScopedResource()
    defer {
      if started { url.stopAccessingSecurityScopedResource() }
    }

    do {
      let bookmark = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      let name = url.lastPathComponent
      UserDefaults.standard.set(
        bookmark,
        forKey: Self.bookmarkKeyPrefix + name
      )
      result([
        "path": url.path,
        "name": name,
        "bookmark": bookmark.base64EncodedString(),
      ])
    } catch {
      result(
        FlutterError(
          code: "bookmark_failed",
          message: "Could not create a security-scoped bookmark: "
            + error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pendingResult
    pendingResult = nil
    result?(nil)
  }

  // MARK: - 安全作用域访问

  private func startAccess(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let name = args["name"] as? String
    else {
      result(
        FlutterError(code: "bad_args", message: "Missing folder name.", details: nil)
      )
      return
    }

    let key = Self.bookmarkKeyPrefix + name
    var data: Data?
    if let raw = args["bookmark"] as? String, !raw.isEmpty {
      data = Data(base64Encoded: raw)
    }
    if data == nil {
      data = UserDefaults.standard.data(forKey: key)
    }
    guard let bookmark = data else {
      // 没有书签：旧记录或原生存储被清理，交给 Dart 保留旧镜像
      result(nil)
      return
    }

    var stale = false
    do {
      let url = try URL(
        resolvingBookmarkData: bookmark,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      )

      if !activeScopes.contains(url.path) {
        if url.startAccessingSecurityScopedResource() {
          activeScopes.insert(url.path)
        }
      }

      var payload: [String: Any] = ["path": url.path]
      if stale,
        let renewed = try? url.bookmarkData(
          options: .withSecurityScope,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
      {
        UserDefaults.standard.set(renewed, forKey: key)
        payload["bookmark"] = renewed.base64EncodedString()
      }
      result(payload)
    } catch {
      // 书签损坏或文件夹已不存在：视为授权失效
      result(nil)
    }
  }

  private func stopAccess(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String
    else {
      result(nil)
      return
    }
    if activeScopes.remove(path) != nil {
      URL(fileURLWithPath: path).stopAccessingSecurityScopedResource()
    }
    result(nil)
  }

  private func release(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let name = args["name"] as? String
    else {
      result(nil)
      return
    }
    UserDefaults.standard.removeObject(forKey: Self.bookmarkKeyPrefix + name)
    result(nil)
  }

  // MARK: - 弹出选择器

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap {
      $0 as? UIWindowScene
    }
    let scene =
      scenes.first { $0.activationState == .foregroundActive }
      ?? scenes.first
    guard
      let window =
        scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    else {
      return nil
    }
    var controller = window.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
