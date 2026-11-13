# Rendering and reading surface

> 细节文档：渲染/阅读的硬约束摘要在 `AGENTS.md` 第 5.2 节，这里记录实现细节。

## Markdown and notebooks

- Renderer: `markdown_widget` plus syntax highlighting. GFM alerts (`> [!NOTE]`)
  and `.ipynb` files are converted to Markdown before rendering. `.mdx` is treated as
  Markdown too (`NoteScanner.mdExtensions`), matching search/tags/link-check; JSX
  tags simply show as text instead of being executed. `.mdx` also drops top-level
  `import`/`export` statements and `{/* … */}` comments before rendering and
  full-text indexing (`stripMdxModuleSyntax()`), while fenced/indented code and the
  raw source view keep them. `splitGfmAlerts()` tracks fenced
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
- **Block-level HTML in Markdown** (`markdown_source.dart`, `normalizeHtmlImages`):
  before image normalization, `_convertHtmlBlocks` converts common HTML blocks to
  Markdown so they render instead of staying inert text: `<table>` → Markdown table
  (reuses `htmlTableToMarkdown`; rowspan/colspan tables fall back to per-row stripped
  text), `<ul>/<ol>/<li>` → Markdown lists (innermost first, nested levels indented
  4 spaces; `<li>` auto-closes at the next `<li>`/list end, closing tags are
  optional), `<a href>` → `[text](href)` (image-only labels flatten to plain
  images like markdown badges; `javascript:` hrefs keep only the label),
  `<blockquote>` → `>` quotes, `<hr>` → `---`. HTML comments are dropped and
  common entities (`&amp; &lt; &gt; &quot; &#39; &nbsp;`, numeric) are decoded in
  converted text. `<pre>` is part of the code-protected segments and becomes a
  fenced code block (`language-x`/`lang-x` class → fence language); only blocks
  that do not cross a code-protected segment are converted.
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
- **Mermaid diagrams** (`markdown_viewer.dart`): rendered natively by
  `mermaid_flutter` inside a `RepaintBoundary` (layered cache keeps scrolling
  smooth). Long-press a diagram, or use the fullscreen share action, to save/share a
  PNG captured by `captureRepaintBoundaryPng` (longest side ≤2048, painted on the
  surface color so the gallery copy is not transparent). Capture runs only after the
  user picks an action.

## Code viewer

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

