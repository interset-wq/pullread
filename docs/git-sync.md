# Git and sync layer

> 细节文档：`AGENTS.md` 第 5 节只保留红线，这里记录完整设计与原因。
> 改这一层前先通读，并在 `PLAN.md` 登记。

## Scope

Uses libgit2 through FFI (`git2dart`). Only clone/fetch/pull capabilities are used.
**Change this layer in small, verifiable steps.**

## Target paths and deletion safety

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

## Android TLS bootstrap

`git2dart_binaries` statically links OpenSSL, which cannot see the Android system
certificate store. In `_bootstrap()` (`lib/main.dart`) the order **must** be:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Libgit2.version` (load the native library)
3. `AndroidSSLHelper.initialize()`
4. `Libgit2.setSSLCertLocations(file: certPath)`

Otherwise HTTPS clones fail with `the SSL certificate is invalid`. The CA bundle is
shipped with `git2dart_binaries`; do not add one. This bootstrap runs *after*
`runApp` (see "Startup") so the first frame is not blocked.

## Isolates, timeout and cancellation

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

## Sync awareness

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

