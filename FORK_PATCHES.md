# Fork patches

This fork (github.com/donaldheppner/super_editor) tracks upstream
[Flutter-Bounty-Hunters/super_editor](https://github.com/Flutter-Bounty-Hunters/super_editor)
and carries a small set of MemNote-specific patches. Each entry lists whether the
patch is a candidate for upstreaming.

## Pending upstream

### Markdown inline codec: valid-CommonMark serialization (MemNote NOTE-40)

`super_editor/lib/src/infrastructure/serialization/markdown/`

Rewrites `AttributedTextMarkdownSerializer` and extends the inline parser so that
serialized markdown re-parses to the same styled text:

- Whitespace at the edges of bold/italic/strikethrough/code spans is moved outside
  the style markers (`**bold **` → `**bold** `). Upstream issues #2452 / #2650.
- Strikethrough serializes as GFM `~~text~~` instead of the non-standard single `~`.
  The parser still accepts the legacy single-tilde form.
- Underline serializes as `<u>text</u>` instead of the proprietary `¬text¬` marker.
  The parser accepts both (`¬` notes heal to `<u>` on the next save).
- Backslash escapes are preserved: parsing `3\*4` records a `markdownEscape`
  attribution on the `*`, and serialization re-emits the backslash. Previously the
  escape was destroyed and the bare marker could become emphasis on the next parse.
- Overlapping (non-nested) style spans serialize by closing and re-opening styles,
  producing properly nested markers that CommonMark can re-parse. Adjacent
  same-style spans no longer emit doubled markers (`**a****b**`).
- As a safety net the serializer re-parses its own output; if styles don't survive
  the round trip, markdown-significant characters are backslash-escaped (protects
  plain text like `3*4 and 5*6` from gaining emphasis).
- Plain paragraphs escape block-level trigger characters at line starts
  (`# `, `> `, `- `, `1. `, `---`, fences), so a paragraph that merely starts with
  those characters doesn't change block type on the next parse.

Tests: `super_editor/test/infrastructure/serialization/markdown/attributed_text_markdown_test.dart`
(group "AttributedText markdown round-trips (NOTE-40)") and updated expectations in
`super_editor_markdown_test.dart`.

### Markdown block codec: round-trippable block serialization (MemNote NOTE-41)

`super_editor/lib/src/infrastructure/serialization/markdown/`

Fixes block-level constructs that corrupted on a serialize/parse round trip:

- Code fence info strings survive: the parser stores the fence language in the
  code `ParagraphNode`'s `codeLanguage` metadata and the serializer re-emits it
  (` ```dart ` no longer degrades to a bare ` ``` `). Fence content is written as
  literal plain text (no backslash escaping / hard-break spaces inside fences),
  and the parser's trailing newline is stripped so fences don't grow a blank
  line per save.
- Ordered list items serialize with real sequential ordinals (`1. 2. 3.`)
  computed from their position among consecutive same-indent ordered siblings,
  instead of a literal `1.` for every item.
- Top-level list items have zero leading spaces (previously every list gained a
  2-space base indent per save). Nested items are indented to their parent
  marker's content column (2 under `- `, 3 under `1. `, 4 under `10. `) — a
  fixed 2-space step silently flattens nesting under ordered parents on the
  next parse.
- Unordered lists serialize with a canonical `- ` marker (`*` bullets heal to
  `- ` on the next save — a one-time, idempotent normalization).
- Multi-line blockquotes emit `> ` on every line (a bare `>` for blank lines);
  previously only the first line was marked and later lines split into separate
  paragraphs on the next parse. The parser also joins a blockquote's block
  children with a blank line instead of fusing them (`> a\n>\n> b` no longer
  collapses to "ab").
- Horizontal rules and tables follow the node-separator scheme (a trailing
  newline when not the last node) so they're followed by a blank line instead of
  fusing with the next block.

Tests: `super_editor_markdown_test.dart` (new blockquote/code-language/list
round-trip cases and updated list expectations) and canonicalized fixtures in
`super_editor_markdown_pasting_test.dart`.

## App-specific (not for upstream)

Thin patches carried on top of upstream `0.3.0-dev.52` — see `git log upstream/main..main`:

- `ImageNode.copyContent`: emit Markdown instead of a bare URL (NOTE-18).
- Teardown/layout null-check guards for four crash sites (NOTE-29).
- Android touch interactor: survive a defunct MediaQuery ancestor.
