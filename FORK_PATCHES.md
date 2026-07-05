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

## App-specific (not for upstream)

Thin patches carried on top of upstream `0.3.0-dev.52` — see `git log upstream/main..main`:

- `ImageNode.copyContent`: emit Markdown instead of a bare URL (NOTE-18).
- Teardown/layout null-check guards for four crash sites (NOTE-29).
- Android touch interactor: survive a defunct MediaQuery ancestor.
