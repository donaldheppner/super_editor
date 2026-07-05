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

### Markdown codec: blank-line, empty-paragraph & line-break policy (MemNote NOTE-42)

`super_editor/lib/src/infrastructure/serialization/markdown/`

Replaces the codec's bespoke whitespace scheme with one written policy (see the
doc comment on `serializeDocumentToMarkdown`), making the serializer the exact
inverse of the parser for every structure the parser produces:

- **Blank lines.** One blank line separates blocks; each additional blank line
  is one empty `ParagraphNode`. External input like `A\n\n\nB` parses to
  `[A, empty, B]` and round-trips byte-identically. The old scheme parsed 2+
  blank lines written by any other tool into a paragraph with an embedded
  leading `\n` — the "random line breaks" symptom.
- **Soft breaks.** A single `\n` inside a paragraph round-trips verbatim. The
  serializer no longer appends two-space hard-break markers, which accumulated
  one invisible `"  "` per line per save (upstream issue #3006), and the parser
  no longer needs trailing spaces to keep lines together. Legacy `"  \n"` heals
  to `"\n"` on the next save.
- **Tight headings.** `# Title\nBody` parses with `tight: true` metadata on the
  heading and serializes back without inserting a blank line; the
  blank-line-separated form round-trips unchanged too.
- **Document edges.** Trailing newlines map 1:1 to trailing empty paragraphs
  (`"A"` ↔ `[A]`, `"A\n"` ↔ `[A, empty]`, `"A\n\n"` ↔ `[A, empty, empty]`), so
  the presence/absence of a trailing newline survives a round trip. Leading
  blank lines are leading empty paragraphs. A document of nothing but newlines
  is one empty paragraph per newline plus one.
- **Separator ownership.** Node serializers no longer emit trailing newlines;
  `serializeDocumentToMarkdown` writes all separators centrally (`\n\n` between
  blocks, `\n` between list-family items and after tight headings, `\n` per
  empty paragraph). Custom node serializers must NOT append trailing newlines.
- **Paste.** `pasteMarkdown` strips trailing newlines from clipboard content so
  a paste doesn't insert phantom empty paragraphs.

**Migration** — notes saved under the old scheme reopen without data loss. The
old serializer encoded N consecutive empty paragraphs as 2N+2 newlines; that
byte form now parses to 2N empty paragraphs and serializes back to the *same
bytes*, so stored notes don't churn — the editor simply shows 2N empty lines
where the old parser showed N (typically 2 instead of 1). Old two-space
hard-break soft wraps and old trailing-blank-line forms heal in one save and
are stable afterwards. Verified by the `whitespace policy (NOTE-42)` test
group.

Tests: `super_editor_markdown_test.dart` (group "whitespace policy (NOTE-42)",
plus updated serialization/deserialization expectations),
`super_editor_markdown_pasting_test.dart`, and updated custom serializers in
`custom_parsers/`.

## App-specific (not for upstream)

Thin patches carried on top of upstream `0.3.0-dev.52` — see `git log upstream/main..main`:

- `ImageNode.copyContent`: emit Markdown instead of a bare URL (NOTE-18).
- Teardown/layout null-check guards for four crash sites (NOTE-29).
- Android touch interactor: survive a defunct MediaQuery ancestor.
