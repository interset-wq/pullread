# Platform, startup and icons

> 细节文档：平台适配、启动链与桌面图标。

## Platform adaptation

Clone only needs the **full URL** the user provides. The `GitPlatform` enum is for
display and for turning "username/repo" into a URL; business code must never call
platform REST APIs. The old `RepositoryAdapter` / adapter factory / four platform
adapters were deleted in 2026-10. Adding a platform means adding an enum value and a
`guessPlatform` case — do not reintroduce an HTTP abstraction layer.

Authentication: tokens, if ever added, stay on device only — never hardcode them or
log them. Only public repositories are supported (the user explicitly does not want
private-repo support).

## Startup chain

The native splash paints only the brand paper color (`launch_background` plus v31
`windowSplashScreenBackground`; `windowSplashScreenAnimatedIcon` points at a
transparent placeholder). It **must not draw a logo**. The only startup logo is
Flutter's `BrandSplash` (`lib/src/ui/brand_splash.dart`), shared by `main()`'s
bootstrap page and `HomePage`'s first repo-list load so sizes/positions match and the
user sees a single splash.

Hard constraints:

1. `main()` must call `runApp` immediately. libgit2/CA initialization (Android and
   iOS) happens in `_bootstrap()` after the first frame; doing it before `runApp`
   shows a black surface for hundreds of ms to seconds.
2. All five `activity-alias` entries must use `android:theme="@style/LaunchTheme"`;
   otherwise a release build (launched from an alias) shows black in dark mode.
3. `NormalTheme` must also use `@drawable/launch_background` as `windowBackground`;
   Flutter switches to it in `onCreate`.
4. Never use `?android:colorBackground` for the splash background — it turns black in
   dark mode.
5. The home loading state must not use a `CircularProgressIndicator`; it would
   overlap the splash tail and look like a green dot in the middle of the screen.
   Use `BrandSplash` instead.
6. The launch/normal themes set the status bar and navigation bar to
   `@color/brand_paper` with `windowLightStatusBar=true`. Without this, Android adds
   a gray scrim behind light status-bar icons, which looks like a flash during
   startup.

## Icons and logo

- Desktop icon is selectable in settings (five designs: open book, page-as-arrow,
  pull-page arrow, converge-pages arrow, page-stack arrow; pine green on paper
  white). Android implements this with five `activity-alias` entries
  (`MainActivityBook/Page/Arrow/Converge/Tray`); exactly one is enabled at a time and
  switching goes through `PackageManager.setComponentEnabledSetting` over the
  `app_icon` MethodChannel. Adaptive icon foregrounds are
  `drawable-xxxhdpi/ic_launcher_fg_*.png` (the mark is normalized to 50% of 432px;
  **XML inset must be 0%** — ~66% fills the canvas with no padding, ~33% with a 16%
  inset occupies only about 1/9), with `@color/brand_icon_paper` background
  (`#E3D6BC`, one step darker than the splash paper so the icon stays visible on a
  light iPad dock / launcher). The splash keeps `@color/brand_paper` (`#FBFAF6`).
- iOS/Windows icon switching is not implemented (the iOS alternate-icon API needs
  real-device verification; Windows has no such concept). On platforms without the
  channel, `setAppIcon` persists the preference and silently does nothing.
- In-app logo: transparent `assets/icon/app_logo.png` is used in the home header and
  the settings "about" page (a full set `app_logo_<key>.png` covers all five marks).
  Never use a white-background version in-app (it looks wrong in dark mode). Larger
  marks are generated losslessly from the SVG sources in `design/icons/` (all three
  sets: appicon / adaptive foreground / transparent in-app logo, see its README)
  with the logo-design skill renderer.
- `assets/icon/app_icon.png` and `app_icon_foreground.png` (book, 1024px) are the
  `flutter_launcher_icons` sources for the iOS AppIcon set and Windows `icon.ico`.
  **Set `android: false` in pubspec before running the tool and restore it
  afterwards**: the tool overwrites the hand-maintained
  `mipmap-anydpi-v26/ic_launcher.xml` (0% inset + foreground) and related default
  launcher resources. The five alias-specific mipmap/fg files have distinct names and
  are not touched.
- `assets/icons/` holds five **opaque** desktop icon PNGs (settings preview + launcher
  mipmap source). Never replace them with transparent versions — Android launcher
  icons must not be transparent.

---

## Android build requirements

- `INTERNET` **must** be declared in `android/app/src/main/AndroidManifest.xml`.
  The Flutter template only adds it to debug/profile; a release build then fails all
  HTTPS requests with `GIT_ERROR_NET: No address associated with hostname`.
- The release launcher entry lives on `activity-alias` widgets (five icon variants).
  Flutter tooling only recognizes `MAIN`/`LAUNCHER` on `<activity>`, so
  `android/app/src/debug/AndroidManifest.xml` and
  `android/app/src/profile/AndroidManifest.xml` override the manifest: they attach
  the launcher intent-filter to `MainActivity` and remove the five aliases. Release
  builds do not read those directories, which means **icon switching can only be
  verified on a release build**. Do not touch those two manifests while working on
  icons.

---

