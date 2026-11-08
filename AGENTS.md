# AGENTS.md

**PullRead** is a read-only, mobile-first reader for note repositories. It clones a Git
repository (GitHub, Gitee, GitCode/AtomGit, GitLab, self-hosted Gitea, …) onto the
device and renders it natively: Markdown and Jupyter notebooks, syntax-highlighted
code, article TOC, original directory tree, tags, bookmarks and full-text search.
There is no backend, no build step and no hosting to maintain.

This file is the engineering contract for everyone (human or agent) changing the
code. It is descriptive of the system *and* prescriptive: constraints marked **must**
exist because ignoring them caused real regressions or data loss. Keep it in sync
with the code in the same commit (see "Maintenance").

---

## 1. Product scope

**In scope**

- Clone a whole repository, then read it comfortably. Rendering quality is the
  number-one priority.
- Browse the original directory structure. **Never flatten the tree.**
- Global search across repositories and local folders.
- Local folders (SAF on Android / directory picker on desktop) with the same reading
  pipeline as Git repositories, plus a Markdown editor that writes back.
- Reading progress, bookmarks, tags, link checking and update awareness.

**Out of scope — do not add**

- Any edit/commit/push capability for Git repositories (removed by the user in
  2026-10). Local-folder editing is the only write path and never touches Git.
- Backlinks/graphs, collaboration, private repositories, TTS, PDF, reading stats,
  deployment/CI/static-site generation.
- Platform REST APIs. See "Platform adaptation".

**Non-negotiables**

- Rendering must never be worse than a typical blog.
- Sync conflicts or content loss are unacceptable. Any change to the Git layer must
  be self-reviewed against this rule before commit.

---

## 2. Stack and identity

- **Framework**: Flutter, Dart 3 / Flutter 3.47+. iOS + Android are the product
  targets; the Windows desktop target exists for local preview only. iOS work cannot
  be verified on this machine (no macOS).
- **Package id**: `com.intersetwq.pullread` for Android `applicationId`/`namespace`
  and the iOS bundle id. Kotlin `MainActivity` lives in
  `android/app/src/main/kotlin/com/intersetwq/pullread/`. Renamed from
  `com.intersetwq.reader` in 2026-10: the old package is not upgraded in place and
  its data is not migrated.
- **No new heavy dependencies without justification**. The Git layer is already the
  riskiest part of the project.

---

## 3. Architecture at a glance

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | Startup, `_bootstrap()` (libgit2 + CA), theme, routing to `HomePage` |
| `lib/src/git/` | libgit2 FFI wrapper (`sync_service.dart`), repo metadata (`repo_meta.dart`) |
| `lib/src/notes/` | Note scanning/index, Markdown source, notebook conversion, TOC, tags, link check, code outline |
| `lib/src/search/` | Filename/full-text search, snippets, search models |
| `lib/src/local/` | SAF/desktop folder authorization and incremental mirroring |
| `lib/src/ui/` | Pages and shared widgets (reader, code view, image cache/actions, settings, …) |
| `lib/src/theme/` | `AppPrefs`, app theme |
| `lib/src/utils/` | Text encoding, directory size, small helpers |
| `test/`, `integration_test/` | Unit/widget tests, real-device render baseline |
| `docs/` | Perf baseline, UX audit, settings redesign proposal |

---

## 4. Non-negotiable invariants

These cut across features. Violating any of them has already caused a bug in this
project or would cause data loss.

1. **Git is read-only.** Clone/pull only; never commit, checkout user changes or
   rewrite history.
2. **Never delete outside the intended target.** Repo names and target paths must be
   derived safely (see "Git and sync"), and deletion helpers must refuse roots.
3. **All Git work runs in a background isolate**, and native errors must be converted
   to plain Dart errors before crossing the isolate boundary.
4. **The UI isolate never does recursive filesystem scans.** Use isolates plus the
   on-disk index cache.
5. **Long documents are lazily laid out.** Eager layout is only for capture/export.
6. **Reading progress is written only for user-initiated scrolls**, never for
   programmatic restore/animations.
7. **Server data is never rendered as executable/inline payloads**: notebook images
   go to a side store, not into Markdown source as base64.
8. **No secrets in code or logs.** Tokens, if ever added, stay on device.
9. **Startup shows exactly one splash image** and never a spinner.
10. **Pending local edits win over a stale source folder.** Never overwrite the
    mirror with older source content.

---

## 5. Git and sync layer (highest risk)

Uses libgit2 through FFI (`git2dart`). Only clone/fetch/pull capabilities are used.
**Change this layer in small, verifiable steps.**

### 5.1 Target paths and deletion safety

- Derive the repository name from `Uri.parse(url).pathSegments`, ignoring empty
  segments; strip only a trailing `.git` suffix (never `replaceAll('.git', '')`).
- Validate the name: non-empty, not `.`/`..`, does not start with `.` (at minimum
  reject `.meta`), and contains no path separators or Windows-illegal characters
  (`: * ? " < > |`).
- Before cloning, verify that the target's parent is exactly the repos root, using
  path segments rather than string prefixes.
- `_prepareTarget()` must refuse to delete the repos root, the metadata directory,
  the local-mirror root or the application documents root. A trailing-slash URL once
  produced an empty name and would have recursively deleted every cloned repo plus
  `.meta` (reading progress, bookmarks, favorites, update markers).
- Tests for URL/path handling must use temporary directories only, never real user
  data directories.

### 5.2 Android TLS bootstrap

`git2dart_binaries` statically links OpenSSL, which cannot see the Android system
certificate store. In `_bootstrap()` (`lib/main.dart`) the order **must** be:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Libgit2.version` (load the native library)
3. `AndroidSSLHelper.initialize()`
4. `Libgit2.setSSLCertLocations(file: certPath)`

Otherwise HTTPS clones fail with `the SSL certificate is invalid`. The CA bundle is
shipped with `git2dart_binaries`; do not add one. This bootstrap runs *after*
`runApp` (see "Startup") so the first frame is not blocked.

### 5.3 Isolates, timeout and cancellation

- **Clone and pull use `Isolate.spawn` + `ReceivePort`**; `checkRemote` uses
  `Isolate.run` because it needs no progress. Never run Git on the UI isolate.
- Inside an isolate, catch `git2dart` native exceptions and rethrow a normal
  `Exception` (or send a string). Native error objects cannot cross isolates; sending
  them leaves the returned `Future` incomplete and the UI spinning forever.
- Clone has a **5-minute timeout that must `Isolate.kill` the worker and clean up the
  target directory**. `Isolate.run(...).timeout()` only times out the future; the
  isolate keeps writing and leaves a half-cloned directory that makes retries fail
  with "local directory already exists".
- Clone reports progress through the port as `[0, receivedObjects, totalObjects,
  receivedBytes]`; the final message is `true` on success or an error string.
  `CloneCancelToken.cancel()` takes effect on the next progress message because the
  transfer itself is a blocking native call. Cancellation reuses the kill + cleanup
  path.
- **Never pass `checkoutBranch` to clone.** Guessing the default branch (`main` vs
  `master`) causes libgit2 to wipe and re-clone the whole repository. Let libgit2
  check out the remote HEAD, then store the real branch with `readHeadBranch`.

### 5.4 Sync awareness

- `checkRemote()` fetches in an isolate, then counts commits behind with
  `RevWalk` (push remote head, hide local head) without moving the local branch. The
  repository page shows the count before the user confirms a pull.
- `RepoMeta.syncedAt` is updated on clone (`writeClone`) and successful pull
  (`touchSynced`); repository cards show "synced at …".
- **Divergence**: `checkRemote()` also walks in reverse to detect local commits the
  remote lacks. On a non-fast-forward pull (`SyncException.diverged`), ask the user
  before deleting and re-cloning from the recorded URL. Reading progress, bookmarks
  and update markers live outside the repo and survive.
- **Change markers**: after a fast-forward pull (single, "update all", and silent
  background pull), diff old head → new head inside the isolate and record
  added/modified files (not deletions) in `RepoMeta.recentChanges` (cap 200; clear
  the whole list when exceeded). File rows show "new/updated"; opening the file
  clears its marker.
- **Pull progress**: `pull()` uses the same spawn/port protocol as clone and reports
  `Remote.fetch(transferProgress:)`. Pull is **not cancellable** (killing a blocking
  fetch can leave a truncated packfile), so show progress without a cancel button.
  Both the single-repo sync and "update all" use `runWithPullProgress`; the batch path
  must also write `syncedAt` and `recentChanges`.
- **Update inbox** (`updates_page.dart`): the home inbox icon shows unread counts,
  aggregated from `recentChanges` of repos and local mirrors, grouped by source.
  Opening an item marks it read; "mark all read" is supported. All openings go
  through `open_note.dart`, which dispatches to reader/gallery/code viewer, clears
  the marker and records the recent file.

### 5.5 Android build requirements

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

## 6. Rendering and reading

### 6.1 Markdown and notebooks

- Renderer: `markdown_widget` plus syntax highlighting. GFM alerts (`> [!NOTE]`)
  and `.ipynb` files are converted to Markdown before rendering. `.mdx` is treated as
  Markdown too (`NoteScanner.mdExtensions`), matching search/tags/link-check; JSX
  tags simply show as text instead of being executed. `splitGfmAlerts()` tracks fenced
  code blocks, so alert markers shown as code examples never split the document.
- **Math pipes in tables** (`lib/src/notes/math_render.dart`): GFM splits table
  cells on `|` before inline parsing, so `$|x|$` would truncate the cell (issue #2).
  `protectTableMathPipes()` replaces pipes inside table math with private-use
  placeholders and `MathNode` restores them. Apply it before every
  `MarkdownGenerator.buildWidgets` call (reader and editor preview); do not drop raw
  `|` from formulas.
- **Notebook rich output** (`lib/src/notes/ipynb.dart`, `ipynb_images.dart`):
  `image/png|jpeg|gif|svg` outputs are decoded into an in-memory store keyed by
  content hash (`IpynbImageStore`, 64 MB cap, approximate LRU). The body keeps only a
  short `pullread-ipynb://<hash>` reference — **never put base64 in the body**, or
  copy-all, in-text find and TOC line numbers all get polluted. When images exist,
  drop matplotlib's `<Figure ...>` text placeholder. Simple `text/html` tables
  (no colspan/rowspan, ≤100 rows, ≤30 columns) become Markdown tables; otherwise fall
  back to `text/plain`. Full-text search uses `toMarkdown(includeImages: false)` and
  never decodes images.
- **Lazy long-document layout** (`lib/src/ui/markdown_viewer.dart`): body blocks go
  into a `SliverList` so only blocks near the viewport are built. Baseline numbers
  (reproduce with `docs/perf.md`): 5000 lines first frame 2.3s → 0.46s and +150 MB →
  +7 MB memory; 10000 lines 4.5s → 0.8s. Two hard constraints:
  1. Long-image export must switch back to the whole-document, one-shot layout
     (`_eagerForCapture`); otherwise `RepaintBoundary` only captures built blocks.
  2. TOC jumps depend on **contiguous item indices** from `scroll_to_index`: every
     block carries an `AutoScrollTag`, and headings record their slot in
     `_headingSlots`. Sparse heading-only anchors miscalculate long-distance jumps.
- **Remote image cache** (`lib/src/ui/image_cache.dart`): network images read the
  disk cache first and render immediately (offline-friendly, no 30s timeout). URLs
  are hashed with two 32-bit values into `<docs>/imgcache`; evict by write time above
  200 MB. Cache entries older than 7 days are refreshed silently in the background;
  failures fall back to the cached copy. Refreshes and re-entry use conditional
  requests: store `ETag`/`Last-Modified` in a `.meta` sidecar next to `<key>.img`,
  send `If-None-Match`/`If-Modified-Since`; a 304 reuses the cache and resets the
  freshness window without re-downloading bytes. Manual retry skips conditional
  headers.
- **SVG** (`repo_image.dart`, `markdown_source.dart`): local `.svg` uses
  `SvgPicture.file`; network bytes are sniffed and use `SvgPicture.memory`, scaled to
  available width by viewBox. `normalizeHtmlImages` only drops shields.io /
  contrib.rocks / star-history badges — **do not drop all `.svg` URLs**. Saving or
  sharing rasterizes via `svgToPng` (longest edge ≤2048).
- **Image decoding width** in the reader is capped by screen width × devicePixelRatio
  (320–2048) to avoid decoding tens of MB per image. The gallery still uses the
  original resolution for zooming.
- **Image save/share** (`image_actions.dart`): long-press in the body and the gallery
  menu/long-press share one path (save to gallery / share / copy URL).
  `loadRepoImageBytes` handles local files, network cache/download and notebook
  in-memory images. A failed gallery save only warns; sharing still works. SVG is
  converted to PNG first.

### 6.2 Code viewer

- Non-Markdown files open in a syntax-highlighted read-only viewer
  (`code_viewer.dart` + `code_view.dart` + `notes/code_outline.dart`), matching
  GitHub mobile while adding an outline and notebook support.
- **Shared rendering**: `CodeView` / `CodeViewController` are used by both the code
  file page and Markdown "Raw" mode. They share highlighting, line numbers, find,
  outline, wrapping and line selection. Raw mode fixes font size at 13, does not wrap
  by default, and uses its **own scroll controller** (never the reader's
  `_scrollController`, so view switches don't leak positions or corrupt progress).
  File reads always go through `decodeTextBytes` (strict UTF-8 first, GBK fallback).
- **Outline**: regex heuristics for `class/mixin/enum/extension`, `def`,
  `function`/`const` arrow functions, `fun`, `func`, `fn`, shell functions,
  `# section` comments and top-level YAML keys; cap 500 entries. The panel can jump
  to a line and highlights the current entry (`_currentLine` derived from scroll
  offset). Raw Markdown reuses `extractToc` (skipping fenced code); `.ipynb` raw text
  is treated as JSON.
- **Find**: reuses `findTextMatches`, shows match count and previous/next.
  Per-character highlighting is intentionally not implemented because
  `HighlightView` does not expose text offsets.
- **Line selection copy**: long-press anchors the start line, tap extends to the end
  line, and the whole line range is highlighted. The overlay lives in the **scrolled
  content coordinate space** (a viewport-fixed overlay drifts after scrolling). A top
  action bar offers copy/cancel. **Wrapping mode does not support line selection**
  (line heights vary, so a `dy` cannot be mapped back to a line).
  **Line height must be measured with `TextPainter` using the real font**
  (`_measureLineHeight`), never `fontSize × height`: JetBrains Mono at 13px / 1.5
  renders at 20.0, not 19.5; hard-coding 19.5 shifts the highlight by 0.5px per line
  and visibly accumulates over dozens of lines. Line numbers use
  `TextScaler.noScaling` to match the `RichText` inside `HighlightView`. Regression
  test: `test/code_selection_test.dart`.
- **Wrapping** is an AppBar toggle; enabling it hides the line-number gutter because
  wrapped rows no longer align with line numbers.

### 6.3 Reading flow (`markdown_viewer.dart`)

- **Open and resume**: after the first layout, restore the last position (heading
  anchor first, fraction fallback) and offer "read from start" in a SnackBar. Do not
  show a modal on every open (old behavior).
- **Write progress only for user scrolls**: restore uses `animateTo` /
  `scrollToIndex`, which also fire the `ScrollController` listener. Confirm the round
  of scrolling was user-initiated (`ScrollStartNotification.dragDetails != null`,
  reset on `ScrollEndNotification`) before persisting. Otherwise opening and
  immediately leaving overwrites progress with an intermediate animation position
  (observed: 87% became 55%).
- **Bookmarks** are paragraph-level: record heading + whole-document fraction in
  `RepoMeta.bookmarks` (100 per repo, dedupe within 1% of the same file). The
  in-article panel can jump/delete. Home shows the five most recent; `BookmarksPage`
  groups all by repository. Opening uses `MarkdownViewerPage.initialFraction`
  (lower precedence than `initialFindQuery`, and it skips resume).
- **Previous/next in the same directory** reuse `NoteIndexCache`; opening an article
  must not trigger a recursive scan. If the cache is missing, scan in the background
  and write it back.
- **In-text find**: the AppBar search icon opens a find bar (Raw mode uses
  `CodeView`'s source find). Matches are reported by line in the same coordinate
  system as `TocEntry.line` (both based on the post-front-matter / converted body).
  Jumps currently locate the heading that contains the match; documents without
  headings scroll by character ratio. Match highlighting is per character via
  `MarkdownGenerator.textGenerator` (`_FindHighlightNode`), case-insensitive, and
  only applies to plain-text nodes (not links/code blocks).
- **Search entry**: opening from a body search result passes `initialFindQuery` so
  the find bar opens, counts matches and jumps to the first one.
- **Recent reading** (`RepoMeta.pushRecent` / `readRecentEntries`): recorded per
  source root, not per repo. Git repos share `<reposRoot>/.meta/recents.json`;
  local mirrors must pass `recentsRoot: <docs>/local` so they share
  `<docs>/local/.meta/recents.json`. Entries carry an ISO-8601 timestamp; home
  merges both roots, sorts newest first and dedupes per source. Never let each
  local mirror write its own recents file. Home filtering (`home_feed.dart`) also
  drops entries whose file no longer exists, for both favorites and recents, so
  deleted/renamed notes never leave unresponsive ghost cards.
- **Repository reading status**: file rows show "read N% / finished" (<0.5% is not
  shown); the toolbar's "unread only" filter hides only files that already have
  reading records. Read all records at once with `RepoMeta.readAllProgress` and
  refresh when returning from the reader.

### 6.4 Directory index and search

- **Index cache** (`lib/src/notes/note_index.dart`): repository file lists are
  scanned in a background isolate (never recursive `listSync` on the UI thread),
  cached to `<reposRoot>/.meta/index/<repoName>.json`, and rendered
  stale-while-revalidate. Remove the cache when deleting a repo/local folder.
- **Full-text search** (`lib/src/search/`): the repo page can switch between
  filename and body search; the home search icon opens
  `lib/src/ui/global_search_page.dart` across repositories and local folders
  (sequential per source, results stream in per group; local sources are labeled
  `本地 · <name>` so they stay distinct from same-named repos). Supports search
  history (persisted in `AppPrefs`,
  max 12; tap to search, ✕ to delete), source filters (multi-select; none = all)
  and "body / title only" modes. Title-only matches filenames/paths without reading
  files and does not open with a find query.
- Body search reads md/ipynb inside an isolate (max 2 MB per file) and does linear
  matching: split the query on whitespace (including full-width spaces), require
  **all terms** (AND), and produce per-term highlight ranges with
  `SearchSnippet.highlights` for the UI. Markdown is searched after stripping
  front matter and normalizing HTML images, i.e. the same body the reader renders,
  so every reported hit is visible to in-text find. Sort order: path matches all
  terms → match count → path.
- **Deliberately no inverted index**: for Chinese 2-grams the postings are the same
  order of magnitude as the text, often larger after serialization, while note repos
  hold only a few MB. Page cache + `indexOf` is fast and has no index staleness.

### 6.5 Tags, link checking, storage

- **Tags** (`lib/src/notes/tag_index.dart`, `lib/src/ui/tag_page.dart`): the home tag
  icon opens a page aggregating front-matter `tags` from all repos and local mirrors
  (reads only the first 8 KB of each file, scans in an isolate). Selecting multiple
  tags requires ALL of them (AND) across sources. **Implicit directory tags** are a
  toggle (default on, top-right of the tag page): each directory level is merged into
  the tag set, so repos without front matter are still navigable.
- **Link checking** (`lib/src/notes/link_check.dart`): repo page "more → check broken
  links" validates relative links/images in bulk, skipping external URLs, anchors and
  code blocks, decoding percent-encoding and resolving `../`. Results are grouped by
  source file and copyable. Strictly read-only.
- **Settings** (`lib/src/ui/settings/`): two-level Material 3 layout. The root has
  six navigation rows (reading, appearance, repositories, file display, storage/data,
  about) with current values; each subpage owns 2–4 card groups. Sliders keep a local
  draft and persist only on `onChangeEnd`; the fold threshold is disabled while long
  code folding is off; desktop icon switching is Android-only; every subpage has
  "restore this page". Shared theme selection is in `theme_mode_selector.dart`.
- **Storage page** (`lib/src/ui/storage_page.dart`, `lib/src/utils/dir_size.dart`):
  settings → Storage & data → Storage shows disk usage for `repos`, `local`,
  `imgcache` and `.meta` (recursive sizes summed in a background isolate). Image cache
  can be cleared (delete files, keep the directory); the metadata section can clear
  reading history. Repo/mirror deletion stays on the home cards.
- **Storage & data settings** (`lib/src/ui/settings/data_settings_page.dart`): lists
  pending write-backs with a conflict badge and clears search history; reading history
  and favorites live under a separate destructive section with counts. Clearing them
  covers **both** source roots (`<docs>/repos` and `<docs>/local`) and counts come
  from `RepoMeta.countStars`, so local folders are never skipped.

### 6.6 Local folders and the editor

- **Local folder reading** (`lib/src/local/local_folder_service.dart`): Android uses
  the `saf` package to authorize a tree URI (persisted; no real path, so `dart:io`
  cannot read it) and **incrementally mirrors** it to `<docs>/local/<name>`, then
  reuses `RepoPage` and the whole rendering pipeline — treat it as a repository, do
  not invent a second content-source abstraction. Desktop uses `file_selector` with a
  real path. A `.pullread_local` marker distinguishes local sources; "sync" means
  re-mirror. Mirror only md/ipynb/code/images (skip files >32 MB); append a numeric
  suffix on name collisions.
- Incremental sync compares source-side `(size, mtime)` snapshots stored in
  `.pullread_manifest.json` at the mirror root.
- SAF authorization **must request write permission**
  (`pickDirectory(writePermission: true)`), otherwise the editor cannot write back.
- `.txt` is mirrored and opened as an ordinary code file, with no special case. Text
  decoding goes through `lib/src/utils/text_encoding.dart` (strict UTF-8 first, GBK
  fallback, pure Dart).
- **Local Markdown editor** (`lib/src/ui/markdown_editor.dart`): opened from the
  reader's "edit" action for mirrored Markdown. Source/preview toggle, manual save,
  unsaved-changes prompt on exit. Saving writes both the mirror (dart:io) and the
  original folder (Android SAF `writeFileBytes(overwrite:)`, resolving each path
  segment with `child()`; desktop writes the real path). Returning to the reader
  reloads automatically. Repository files remain read-only and are never committed.
- If write-back fails, record the file in `.pullread_pending.json` next to
  `.pullread_manifest.json`. Later incremental syncs **skip** those files and retry
  the write-back; never overwrite the mirror with stale source content. Settings →
  Storage & data → "pending write-backs" lists them, allows retry, or force-overwrites
  from the mirror.

---

## 7. Platform and startup

### 7.1 Platform adaptation

Clone only needs the **full URL** the user provides. The `GitPlatform` enum is for
display and for turning "username/repo" into a URL; business code must never call
platform REST APIs. The old `RepositoryAdapter` / adapter factory / four platform
adapters were deleted in 2026-10. Adding a platform means adding an enum value and a
`guessPlatform` case — do not reintroduce an HTTP abstraction layer.

Authentication: tokens, if ever added, stay on device only — never hardcode them or
log them. Only public repositories are supported (the user explicitly does not want
private-repo support).

### 7.2 Startup chain

The native splash paints only the brand paper color (`launch_background` plus v31
`windowSplashScreenBackground`; `windowSplashScreenAnimatedIcon` points at a
transparent placeholder). It **must not draw a logo**. The only startup logo is
Flutter's `BrandSplash` (`lib/src/ui/brand_splash.dart`), shared by `main()`'s
bootstrap page and `HomePage`'s first repo-list load so sizes/positions match and the
user sees a single splash.

Hard constraints:

1. `main()` must call `runApp` immediately. libgit2/CA initialization happens in
   `_bootstrap()` after the first frame; doing it before `runApp` shows a black
   surface for hundreds of ms to seconds.
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

### 7.3 Icons and logo

- Desktop icon is selectable in settings (five designs: open book, page-as-arrow,
  pull-page arrow, converge-pages arrow, page-stack arrow; pine green on paper
  white). Android implements this with five `activity-alias` entries
  (`MainActivityBook/Page/Arrow/Converge/Tray`); exactly one is enabled at a time and
  switching goes through `PackageManager.setComponentEnabledSetting` over the
  `app_icon` MethodChannel. Adaptive icon foregrounds are
  `drawable-xxxhdpi/ic_launcher_fg_*.png` (the mark is normalized to 50% of 432px;
  **XML inset must be 0%** — ~66% fills the canvas with no padding, ~33% with a 16%
  inset occupies only about 1/9), with `@color/brand_paper` background and the same
  paper color for the splash.
- iOS/Windows icon switching is not implemented (the iOS alternate-icon API needs
  real-device verification; Windows has no such concept). On platforms without the
  channel, `setAppIcon` persists the preference and silently does nothing.
- In-app logo: transparent `assets/icon/app_logo.png` is used in the home header and
  the settings "about" page. Never use a white-background version in-app (it looks
  wrong in dark mode). Larger marks are generated losslessly from the SVG sources in
  `temp/icon-design/` with the logo-design skill renderer.
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

## 8. Development workflow

### 8.1 Conventions

- Commits: English Conventional Commits (`feat/fix/chore/docs/test/…`), atomic.
  **Push requires explicit user approval.**
- Temporary files go in `temp/` (git-ignored), not the system temp directory.
- No TDD/SDD process. When a change touches behavior already covered by tests,
  update or extend those tests in the same commit.
- On Windows, Python file reads must pass `encoding="utf-8"` explicitly.
- Comments and UI copy are Chinese; identifiers and commit messages are English.

### 8.2 Commands

```bash
flutter pub get
flutter run                 # device/emulator; see the alias note for dev manifests
flutter analyze --fatal-infos
flutter test

# Release APK: arm64 only, fixed command
flutter build apk --split-per-abi --target-platform android-arm64

# Long-document render baseline (real device, profile mode)
flutter drive --profile -d <deviceId> \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/render_perf_test.dart
# Single size / cleaner memory: add --dart-define=PERF_SIZES=10000
```

APK packaging: only arm64-v8a (mainstream phones). Output is
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~32 MB; the fat APK is
~79 MB). Do **not** use gradle `ndk.abiFilters` to restrict ABIs — it does not affect
Flutter-injected `.so` files and conflicts with `--split-per-abi`. x86_64 emulators
cannot install this APK; use a debug build for emulator work.

### 8.3 Verification

- Every change: `flutter analyze --fatal-infos` and `flutter test`.
- Git-layer changes: add isolated tests (temp dirs only) and manually reason about
  data-loss and fast-forward behavior.
- UI changes that depend on gestures, SAF write-back, icon switching or volume keys
  need real-device verification; widget tests are not enough. Icon switching in
  particular can only be tested on a release build.
- Startup changes: verify cold start light and dark, and confirm there is exactly one
  splash image and no green dot.

### 8.4 CI

`.github/workflows/ci.yml` runs `flutter analyze --fatal-infos` + `flutter test` on
PRs and pushes to `main`, plus a separate `build-apk` job that builds a debug arm64
APK. Manifest merging, icon resources and plugin compatibility only surface in a real
assemble, so keep that job. Release builds are still triggered only by `v*` tags via
`release.yml`.

### 8.5 Release

- Official releases come only from GitHub (`interset-wq/pullread`). Push a `v*` tag;
  `.github/workflows/release.yml` validates that the tag matches the pubspec
  `version`, builds the arm64 APK and creates the GitHub Release. **Never upload an
  APK manually** — it would diverge from the tagged source.
- Flow: bump `pubspec.yaml` version → commit → push the matching tag.
- **Prerelease**: a SemVer prerelease suffix (e.g. tag `v1.12.0-rc1`, pubspec
  `1.12.0-rc1+21`) uses the same build but is marked prerelease on GitHub, meaning it
  has not passed real-device acceptance yet. Tags without `-` are stable releases.
  Version comparison ignores the `+build` suffix.
- Actions → Release → Run workflow (`workflow_dispatch`) performs a build + signature
  smoke test only and **creates no Release** (version validation and publishing are
  tag-gated). Use it after upgrading actions or the build environment.
- Signing: local release builds use a different key from the official APK, so
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE` is expected. For local installs, use a
  temporary `applicationIdSuffix` and never commit it.

---

## 9. Testing notes

- `test/widget_test.dart` injects a fake `PathProviderPlatform` pointing at a temp
  directory. Never let tests touch the real `~/Documents` (or any user data
  directory), and avoid real IO inside fake-async widget tests.
- Prefer `pump` with fixed durations over `pumpAndSettle` when pages contain image
  decoding or indefinite animations.
- Rendering baselines and their definitions live in `docs/perf.md`.
- The UX audit is reference material, not a binding spec: `docs/user-feedback.md`.
  Settings redesign phases 1–2 are implemented under `lib/src/ui/settings/`; phase 3
  items remain optional and are tracked in `docs/settings-redesign.md`.

---

## 10. Maintenance

If project structure, build/test commands, architecture boundaries, conventions or any
other fact recorded here changes, update this file in the same commit. Outdated
instructions are worse than no instructions.
