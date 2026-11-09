# Local folders and the Markdown editor

> 细节文档：SAF 授权、增量镜像、编辑器写回与待写回队列。

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
  decoding goes through `lib/src/utils/text_encoding.dart` (BOM-aware UTF-8 /
  UTF-16 LE/BE first, strict UTF-8, then GBK fallback; pure Dart). The editor keeps
  the detected encoding and BOM when saving.
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

