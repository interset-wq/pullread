# Reading flow, search and data

> 细节文档：阅读流程、查找、索引/搜索、标签、断链、存储与设置页。

## Home (`home_page.dart`, `home_feed.dart`)

- Three width modes: phone `<600`, tablet portrait `600–1000` (centered content
  band, two-column grids) and tablet landscape `≥1000` (left reading column +
  right repo/local pane with segmented tabs). The landscape header is drawn inside
  the two columns, so `HomePage` has no global `AppBar` there.
- Continue reading is a quiet divider row on phone and a large hero card on
  tablets. Recent reading is capped at five entries, deduped against the current
  continue-reading file, with a "全部 ›" list page.
- Repository and local-folder tabs are mutually exclusive (`HomeSegmentedTabs`).
  The add-repository entry is the FAB on the repo tab only; local folders use the
  dashed "添加本地文件夹" card and never show the FAB.
- Pin/delete (repos) and refresh/remove (local folders) live in each card's `⋮`
  menu; destructive actions confirm first. The old horizontal
  favorites/bookmarks strips were removed from the page — cross-source 收藏 and
  书签 stay reachable from the home `⋮` menu.
- Landscape single-repo mode shows a large repo card plus up to four "仓库内热门
  目录" cards derived from `NoteIndexCache` (hidden when the cache is empty) and a
  light guidance card, so a small library still fills the pane.
- Tokens (paper/card/divider/green tint/pin/red) are defined once in
  `HomeTokens` inside `home_feed.dart`, with paired light/dark values.

## Reading flow (`markdown_viewer.dart`, `reader/reader_pane.dart`)

- **Core and shell**: `MarkdownViewerPage` is a thin public shell; the reading
  implementation lives in `ReaderPane`. Book mode passes `BookOutline` so
  previous/next follows outline chapters instead of same-directory filenames.
  `ReaderPane(embedded: true)` drops the page `Scaffold`/`AppBar` and renders a
  compact pane bar (title, find, star, more sheet) so split reading can host two
  independent readers under one route.
- **Multi-open** (`reader/split_reader_page.dart`, `reader/reader_session.dart`):
  opened from the home AppBar, with candidates from cross-source recents. At
  ≥900 dp two columns render side by side; below that an `IndexedStack` plus a
  bottom segmented switcher keeps both pane states alive. Each pane has its own
  nested `Navigator`, so chapter/sibling navigation and the back stack stay
  local; closing a pane clears only that slot.
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
  in-article panel can jump/delete. The cross-source `BookmarksPage` (home `⋮` →
  书签) groups all by repository. Opening uses `MarkdownViewerPage.initialFraction`
  (lower precedence than `initialFindQuery`, and it skips resume).
- **Previous/next in the same directory** reuse `NoteIndexCache`; opening an article
  must not trigger a recursive scan. If the cache is missing, scan in the background
  and write it back.
- **In-text find**: the AppBar search icon opens a find bar (Raw mode uses
  `CodeView`'s source find). Matches are reported by line in the same coordinate
  system as `TocEntry.line` (both based on the post-front-matter / converted body).
  Jumps locate the exact block: the match line is interpolated between the
  chapter's heading slot and the next heading's slot (`_headingSlots` +
  `scroll_to_index`, lazy-list safe), and documents without headings map the
  line ratio onto the block index. Slot positions are average-height estimates;
  the per-character highlight (`MarkdownGenerator.textGenerator`,
  `_FindHighlightNode`, case-insensitive, plain-text nodes only — not
  links/code blocks) pins the exact spot on arrival.
- **Search entry**: opening from a body search result passes `initialFindQuery` so
  the find bar opens, counts matches and jumps to the first one.
- **Recent reading** (`RepoMeta.pushRecent` / `readRecentEntries`): recorded per
  source root, not per repo. Git repos share `<reposRoot>/.meta/recents.json`;
  local mirrors must pass `recentsRoot: <docs>/local` so they share
  `<docs>/local/.meta/recents.json`. Entries carry an ISO-8601 timestamp; home
  merges both roots, sorts newest first and dedupes per source. Never let each
  local mirror write its own recents file. Home filtering (`home_feed.dart`) also
  drops entries whose file no longer exists, for both the `⋮` → 收藏 list and
  recents, so deleted/renamed notes never leave unresponsive ghost cards.
- **Repository reading status**: file rows show "read N% / finished" (<0.5% is not
  shown); the toolbar's "unread only" filter hides only files that already have
  reading records. Read all records at once with `RepoMeta.readAllProgress` and
  refresh when returning from the reader.
- **Ebook mode** (`reader/book_reader_page.dart`, `books/`): the repo AppBar opens
  a book outline for the current directory. Priority is `.pullread-book.json` →
  `SUMMARY.md` → `_sidebar.md` → inferred Markdown files. Book roots are
  switchable. `RepoMeta.bookProgress` stores only the last chapter per root;
  within-chapter position still comes from the single-note progress, so opening
  the same file from the tree resumes identically. Wide layouts show a 280 dp
  book TOC sidebar; narrow layouts use an AppBar bottom sheet.

## Directory index and search

- **Index cache** (`lib/src/notes/note_index.dart`): repository file lists are
  scanned in a background isolate (never recursive `listSync` on the UI thread),
  cached to `<reposRoot>/.meta/index/<repoName>.json`, and rendered
  stale-while-revalidate. Remove the cache when deleting a repo/local folder or
  switching branches (the list is a snapshot of the old branch).
- **Branch switching** (`lib/src/ui/repo_page.dart` → `GitSyncService.switchBranch`):
  the "切换分支" menu item appears for Git repos only. After a successful switch the
  page clears the index cache and update markers, then rescans; reading progress and
  favorites are path-keyed and survive. Details in `docs/git-sync.md`.
- **Full-text search** (`lib/src/search/`): the repo page can switch between
  filename and body search; the home search icon opens
  `lib/src/ui/global_search_page.dart` across repositories and local folders
  (sequential per source, results stream in per group; local sources are labeled
  `本地 · <name>` so they stay distinct from same-named repos). Supports search
  history (persisted in `AppPrefs`,
  max 12; tap to search, ✕ to delete), source filters (multi-select; none = all)
  and "body / title only" modes. Single-character queries are allowed (the old
  2-char gate blocked common CJK searches); history is recorded only when a
  result is actually opened (`_openHit`), not when the debounced search runs, so
  partial input like `flut` never becomes a history entry. Title-only matches
  filenames/paths without reading files and does not open with a find query.
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

## Tags, link checking, storage, settings

- **Tags** (`lib/src/notes/tag_index.dart`, `lib/src/ui/tag_page.dart`): home `⋮` →
  标签 opens a page aggregating front-matter `tags` from all repos and local mirrors
  (reads only the first 8 KB of each file, scans in an isolate). Selecting multiple
  tags requires ALL of them (AND) across sources. **Implicit directory tags** are a
  toggle (default on, top-right of the tag page): each directory level is merged into
  the tag set, so repos without front matter are still navigable.
- **TOC filter & numbering**: the in-article TOC (mobile bottom sheet and the
  ≥1000dp sidebar) has a keyword filter (`_tocFilter`) — display-only, jumps
  still use original `_toc` indices. Optional hierarchical chapter numbering
  (`AppPrefs.tocNumbering`, default off, settings → 阅读行为) prefixes entries
  with `2.1.3`-style paths computed from heading levels; blank intermediate
  levels count as 1.
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
- **Reading paper** (`lib/src/theme/reading_paper.dart`): the reading surfaces
  (reader, code viewer, editor) resolve their background from `AppPrefs.paperLight`
  (`white`/`sepia`) and `paperDark` (`soft`/`black` for OLED); the Scaffold, AppBar
  and TOC sidebar use it, while body text, code blocks and tables keep their existing
  light/dark colors. Home and settings keep the brand look.
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

