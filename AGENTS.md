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
- Platform REST APIs. See `docs/platform.md`.

**Non-negotiables**

- Rendering must never be worse than a typical blog.
- Sync conflicts or content loss are unacceptable. Any change to the Git layer must
  be self-reviewed against this rule before commit.

---

## 2. Stack and identity

- **Framework**: Flutter, Dart 3 / Flutter 3.47+. The product is cross-platform but
  mobile-first: Android is the primary release target, iOS/iPadOS is built from
  source and awaiting real-device acceptance, Windows is a secondary desktop target
  built from source. Linux/macOS have no platform directory yet. iOS/Windows work
  cannot be verified on this machine (no macOS / Windows host).
- **Package id**: `com.intersetwq.pullread` for Android `applicationId`/`namespace`
  and the iOS bundle id. Kotlin `MainActivity` lives in
  `android/app/src/main/kotlin/com/intersetwq/pullread/`. Renamed from
  `com.intersetwq.reader` in 2026-10: the old package is not upgraded in place and
  its data is not migrated.
- **No new heavy dependencies without justification**. The Git layer is already the
  riskiest part of the project.
- **Dependency licenses are tracked in `THIRD_PARTY_NOTICES.md`**. When
  `pubspec.lock` changes, update the inventory; new bundled binaries, fonts or
  assets must also be registered in `main.dart`'s `LicenseRegistry`. A GPL/LGPL/MPL
  addition needs an explicit distribution review before merge.

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
| `docs/` | Detail docs (`git-sync`, `rendering`, `reading`, `local-folders`, `platform`), perf baseline, proposals |

---

## 4. Non-negotiable invariants

These cut across features. Violating any of them has already caused a bug in this
project or would cause data loss.

1. **Git is read-only.** Clone/pull only; never commit, checkout user changes or
   rewrite history.
2. **Never delete outside the intended target.** Repo names and target paths must be
   derived safely (see §5.1), and deletion helpers must refuse roots.
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

## 5. Hard rules by area

Violating any of these has already caused regressions or data loss. Full designs and
rationale live in the docs below; read the matching doc before editing that area.

### 5.1 Git and sync (`lib/src/git/`)

- Git is read-only: clone and pull only, never commit, checkout user changes or rewrite
  history.
- Repo names come from `Uri.parse(url).pathSegments`, strip only a trailing `.git`, and
  must reject empty, `.`, `..`, dot-leading names, separators and Windows-illegal
  characters. The clone target's parent must be exactly the repos root, and
  `_prepareTarget()` / `deleteRepo()` must refuse the repos root, `.meta`, the
  local-mirror root and the documents root.
- Clone and pull run with `Isolate.spawn` (progress through `ReceivePort`);
  `checkRemote` uses `Isolate.run`. Convert native errors to plain Dart errors before
  crossing the isolate boundary.
- Clone's timeout must `Isolate.kill` the worker and clean the target directory.
- Never pass `checkoutBranch` to clone; read the real branch with `readHeadBranch`.
- Branch switching is read-only too: only checkout existing local/remote refs, never
  commit or push; validate the branch name and clear the index cache afterwards
  (details in `docs/git-sync.md`).
- Pull is not cancellable; a diverged branch asks before delete + re-clone.
- Every test that touches URLs or paths uses temporary directories only.

### 5.2 Rendering and reading

- Notebook images stay in `IpynbImageStore`; never put base64 into the Markdown body.
- Call `protectTableMathPipes()` before every `MarkdownGenerator.buildWidgets` call.
- Long documents stay lazily laid out: every block keeps an `AutoScrollTag` and heading
  slots stay contiguous; only capture/export switches to the eager layout.
- Line height is measured with `TextPainter`, never `fontSize × height`.
- Reading progress is written only after user-initiated scrolls.
- Server content is never executed: unknown HTML/JSX stays inert text.

### 5.3 Startup, icons and local write-back

- The native splash paints only the paper color (no logo, no spinner); `runApp` runs
  before the libgit2/CA bootstrap; all five `activity-alias` entries use `LaunchTheme`.
- Never overwrite a newer local edit with a stale source folder; failed write-backs go
  to `.pullread_pending.json` and are retried, never dropped.
- No secrets in code or logs.

## 6. Detail docs and ownership

| Topic | Doc |
| --- | --- |
| Git/sync internals, change markers, Android build requirements | `docs/git-sync.md` |
| Markdown/notebook rendering, math, images, mermaid, code viewer | `docs/rendering.md` |
| Reading flow, find, bookmarks, index/search, tags, link check, storage, settings | `docs/reading.md` |
| Local folders, SAF mirroring, editor, pending write-backs | `docs/local-folders.md` |
| Platform adaptation, startup chain, launcher icons | `docs/platform.md` |
| Render performance baseline | `docs/perf.md` |
| Settings redesign proposal | `docs/settings-redesign.md` |
| UX audit (reference) | `docs/user-feedback.md` |
| Roadmap, priorities and file ownership | `PLAN.md` |

Keep this file to rules that change behavior; put feature walkthroughs and rationale in
the matching doc. When a change alters a doc, update it in the same commit.

## 7. Development workflow

### 7.1 Conventions

- Commits: English Conventional Commits (`feat/fix/chore/docs/test/…`), atomic.
  **Push requires explicit user approval.**
- Roadmap, current priorities and file ownership live in `PLAN.md`; read it before
  starting cross-cutting work and register any overlapping files there.
- Temporary files go in `temp/` (git-ignored), not the system temp directory.
- No TDD/SDD process. When a change touches behavior already covered by tests,
  update or extend those tests in the same commit.
- On Windows, Python file reads must pass `encoding="utf-8"` explicitly.
- Comments and UI copy are Chinese; identifiers and commit messages are English.

### 7.2 Commands

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

### 7.3 Verification

- Every change: `flutter analyze --fatal-infos` and `flutter test`.
- Git-layer changes: add isolated tests (temp dirs only) and manually reason about
  data-loss and fast-forward behavior.
- UI changes that depend on gestures, SAF write-back, icon switching or volume keys
  need real-device verification; widget tests are not enough. Icon switching in
  particular can only be tested on a release build.
- Startup changes: verify cold start light and dark, and confirm there is exactly one
  splash image and no green dot.

### 7.4 CI

`.github/workflows/ci.yml` runs `flutter analyze --fatal-infos` + `flutter test` on
PRs and pushes to `main`, plus a separate `build-apk` job that builds a debug arm64
APK. Manifest merging, icon resources and plugin compatibility only surface in a real
assemble, so keep that job. Release builds are still triggered only by `v*` tags via
`release.yml`.

### 7.5 Release

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

## 8. Testing notes

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

## 9. Maintenance

If project structure, build/test commands, architecture boundaries, conventions or any
other fact recorded here changes, update this file in the same commit. Outdated
instructions are worse than no instructions.
