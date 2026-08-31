# Fork patches

This fork (github.com/donaldheppner/super_editor) tracks upstream
[Flutter-Bounty-Hunters/super_editor](https://github.com/Flutter-Bounty-Hunters/super_editor)
and carries a small set of MemNote-specific patches. Each entry lists whether the
patch is a candidate for upstreaming.

## Upstream PR status (NOTE-43)

The NOTE-40/41/42 codec work below was sliced into six stacked PRs against
upstream `main` (fork branches `md-codec-1-…` through `md-codec-6-…`, each
based on the previous, so upstream reviews the last commit of each). MemNote
ticket references were scrubbed from the upstream branches; the fork's codec
files are byte-identical to the stack tip.

| # | Fork branch | Covers | Upstream PR | Status |
|---|-------------|--------|-------------|--------|
| 1 | `md-codec-1-inline-commonmark` | NOTE-40: whitespace-safe emphasis, escapes, overlapping spans, safety-net escaping, block-trigger escaping, abutting-span coalescing | [#3079](https://github.com/Flutter-Bounty-Hunters/super_editor/pull/3079) | Open |
| 2 | `md-codec-2-standard-inline-markers` | NOTE-40: strikethrough `~~`, underline `<u>` (legacy forms still parsed) | [#3080](https://github.com/Flutter-Bounty-Hunters/super_editor/pull/3080) | Open |
| 3 | `md-codec-3-code-fence-language` | NOTE-41: fence language metadata, literal fence content, trailing-newline strip (resolves upstream #3006) | [#3081](https://github.com/Flutter-Bounty-Hunters/super_editor/pull/3081) | Open |
| 4 | `md-codec-4-list-serialization` | NOTE-41: real ordinals, nesting indent, canonical `- `, no blank line between mixed-type items | [#3082](https://github.com/Flutter-Bounty-Hunters/super_editor/pull/3082) | Open |
| 5 | `md-codec-5-multiline-blockquotes` | NOTE-41: `> ` on every line, parse-side child joining | [#3083](https://github.com/Flutter-Bounty-Hunters/super_editor/pull/3083) | Open |
| 6 | `md-codec-6-whitespace-policy` | NOTE-42: blank-line/empty-paragraph/soft-break policy, central separators, paste trailing-newline strip | [#3084](https://github.com/Flutter-Bounty-Hunters/super_editor/pull/3084) | Open |

Notes:

- The NOTE-41 horizontal-rule/table trailing-newline fix is superseded by PR 6's
  central separator ownership and is not a separate upstream PR.
- PR 6 changes default serializer output; its description offers to gate the
  policy behind a `MarkdownSyntax` variant if upstream prefers. If upstream asks
  for that, the fork should adopt the same gated form.
- Verified NOT fixed by this codec work (probed 2026-07-05): upstream #2759
  (loose task lists parse with a leading line break and a lost `[x]` state) and
  #2924 (blank line between list types breaks task parsing). #2759 was
  subsequently fixed by the NOTE-80 nested-task-list work below; #2924 is still
  a candidate for future fork/upstream work.
- If upstream merges the PRs, rebase the fork on upstream `main` and drop the
  corresponding sections below; until then the fork already contains all fixes.

## Pending upstream

### Markdown inline codec: valid-CommonMark serialization (MemNote NOTE-40, PRs #3079/#3080)

`super_editor/lib/src/infrastructure/serialization/markdown/`

Rewrites `AttributedTextMarkdownSerializer` and extends the inline parser so that
serialized markdown re-parses to the same styled text:

- Whitespace at the edges of bold/italic/strikethrough/code spans is moved outside
  the style markers (`**bold **` → `**bold** `). Upstream issues #2424 / #2650.
- Abutting spans of the same attribution are coalesced before trimming, so a bold
  run stored as two spans meeting at a space doesn't lose the space's styling
  (added during NOTE-43 upstreaming).
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
(group "AttributedText markdown round-trips") and updated expectations in
`super_editor_markdown_test.dart`, `supereditor_attributions_test.dart`, and
`ime_ios_exceptional_cases_test.dart`.

### Markdown block codec: round-trippable block serialization (MemNote NOTE-41, PRs #3081/#3082/#3083)

`super_editor/lib/src/infrastructure/serialization/markdown/`

Fixes block-level constructs that corrupted on a serialize/parse round trip:

- Code fence info strings survive: the parser stores the fence language in the
  code `ParagraphNode`'s `codeLanguage` metadata and the serializer re-emits it
  (` ```dart ` no longer degrades to a bare ` ``` `). Fence content is written as
  literal plain text (no backslash escaping / hard-break spaces inside fences),
  and the parser's trailing newline is stripped so fences don't grow a blank
  line per save. Resolves upstream #3006.
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
- Horizontal rules and tables are followed by a blank line instead of fusing
  with the next block (now via NOTE-42's central separator ownership).

Tests: `super_editor_markdown_test.dart` (new blockquote/code-language/list
round-trip cases and updated list expectations) and canonicalized fixtures in
`super_editor_markdown_pasting_test.dart`.

### Markdown codec: blank-line, empty-paragraph & line-break policy (MemNote NOTE-42, PR #3084)

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
are stable afterwards. Verified by the `whitespace policy` test group.

Tests: `super_editor_markdown_test.dart` (group "whitespace policy",
plus updated serialization/deserialization expectations),
`super_editor_markdown_pasting_test.dart`, and updated custom serializers in
`custom_parsers/`.

### Markdown codec: nested task lists (MemNote NOTE-80, upstream #2759)

`super_editor/lib/src/infrastructure/serialization/markdown/markdown_to_document_parsing.dart`
`super_editor/lib/src/infrastructure/serialization/markdown/document_to_markdown_serializer.dart`

A nested task list did not survive the markdown → `Document` → markdown round
trip: `- [ ] Task 1\n  - [ ] Task 2` parsed to a *single* `TaskNode` with the
text `"Task 1Task 2"`, and the nested item's checkbox state was destroyed.

- Parser: a `task-list-item` `<li>` was turned into one `TaskNode` from the
  element's *recursive* `textContent` — which includes every nested item's text —
  and its children were then skipped, so a list nested inside the item never
  produced nodes. `TaskNode` was also always constructed at indent 0. The item's
  text is now read from its own children only (checkbox and nested lists pruned),
  the indent comes from the parser's existing list-type stack (the same source
  `ListItemNode` nesting already uses), and the nested lists are visited so their
  items get nodes of their own.
- Serializer: `TaskNodeSerializer` wrote no indent prefix, so even an
  editor-built nested task list (`TaskNode`s with `indent` 1/2) flattened to a
  single level on save. It now writes two spaces per indent level — the content
  column of the parent's `- ` marker.
- Incidentally fixes upstream #2759: in a *loose* task list the item's text lives
  in a `p` and the checkbox is inserted there, so reading the `li` naively picked
  up a leading line break and never found the checkbox. Both the text and the
  `[x]` state now survive.

Tests: `super_editor_markdown_test.dart` — nested-task parse (task-under-task,
bullet-under-task, task-under-bullet), indented-`TaskNode` serialization,
loose task lists, plus nested task cases in the byte-identical round-trip corpus.

### Deterministic node ids for structured-content paste (MemNote NOTE-44)

`super_editor/lib/src/default_editor/multi_node_editing.dart`

`PasteStructuredContentEditorCommand` minted node ids inside `execute()` — for
the downstream half of a split paragraph and for the empty trailing paragraph
inserted below pasted block content. Undo/redo replays the command history
against a document snapshot, so every replay recreated those nodes with fresh
ids, orphaning any later history entry that referenced them (e.g. typing into
the split-off paragraph, then undoing). The ids are now fixed at construction
and can be supplied by the caller (`splitNodeId`, `trailingParagraphNodeId`);
MemNote's paste command passes ids stored on its own command object so replays
are byte-identical.

Tests: covered indirectly by `paste_test.dart` /
`super_editor_markdown_pasting_test.dart` (behavior unchanged) and by
MemNote's `markdown_paste_handler_test.dart` undo/redo group.

### Pluggable clipboard serialization for copy/cut (MemNote NOTE-47)

`super_editor/lib/src/default_editor/common_editor_operations.dart`

`CommonEditorOperations.copy()`/`cut()` always serialized the selection to
plain text, silently dropping all styling. A static
`CommonEditorOperations.clipboardSerializer` hook now lets apps replace the
serialization (MemNote sets it to its markdown serializer); when unset,
behavior is unchanged. The override covers every copy path that runs through
`CommonEditorOperations` — keyboard shortcuts and mobile popover toolbars.
Also hardens `copy()`/`cut()` against a null selection (previously `!`).
Candidate for upstreaming, likely reshaped as an instance-level or
`SuperEditor`-level parameter if upstream prefers.

Tests: MemNote's `markdown_copy_test.dart` (copy/cut through
`CommonEditorOperations` with a mocked clipboard).

### IME insertion guard: don't crash on an unmappable insertion offset (MemNote NOTE-112)

`super_editor/lib/src/default_editor/document_ime/document_delta_editing.dart`

- `TextDeltasDocumentEditor._applyInsertion` force-unwrapped
  `imeToDocumentSelection(...)`, so an insertion delta whose offset lands inside the
  invisible `". "` prefix we prepend to the serialization killed the editing session
  with "Null check operator used on a null value" mid-keystroke (MemNote Crashlytics,
  Android 0.5.2). The unmappable insertion is now logged and dropped, and the delta
  batch continues; `DocumentImeInputClient` re-syncs the IME with our document at the
  end of the batch as it always does. Throwing also latched
  `DocumentImeInputClient._isApplyingDeltas` to `true`, permanently fizzling every
  later `_sendDocumentToIme()`, so the crash disabled IME re-sync as well.
- **Genuine upstream candidate**, not a MemNote-specific behavior change: the `!` carried
  upstream's own `// FIXME: ClickUp is getting NPE's on this line` comment (removed by this
  patch), and the sibling `_applyReplacement` / `_applyDeletion` handlers in the same file
  already treat a null mapping as a normal case. Not yet submitted upstream.

Tests: `ime_android_exceptional_cases_test.dart` — "on Pixel 11 Pro (Android 17) >
ignores an insertion whose offset maps into the invisible prefix".

### Selection leaders layer: guard both ends of the selection (MemNote NOTE-111)

`super_editor/lib/src/infrastructure/documents/selection_leader_document_layer.dart`

- `_SelectionLeadersDocumentLayerState.computeLayoutDataWithDocumentLayout` checked
  that the selection's *extent* still resolved to a component, then fell through to
  the expanded-selection branch and asked the document for
  `selectUpstreamPosition(base, extent)` — which throws
  `Exception: No such position in document` when the *base* node is gone. The crash
  window is therefore exactly an expanded selection whose base node was removed while
  its extent node survived; a collapsed selection can't reach it, which fits the low
  event count (MemNote Crashlytics, macOS 0.5.1, 4 events). It fires inside
  `LayoutBuilder`'s layout callback, where a throw is a fatal frame error, not a
  recoverable one. Both ends are now checked against the document before the expanded
  branch runs, in the method's existing "momentary transitive state → return null"
  idiom.
- The three `getRectForPosition(...)!` null-assertions in the same method (one on the
  collapsed branch, two on the expanded branch) became `return null` instead.
  `DocumentLayout.getRectForPosition` is declared nullable on the interface, its null
  case *is* this same transitive state ("could not find any component for node
  position", which it already logs), and `doBuild` renders `const SizedBox()` for null
  layout data — so returning null degrades to one frame without leaders and
  self-corrects, whereas `!` turns the same condition into a fatal. No behavior change
  when the rects resolve.
- The throwing contract of `getAffinityBetween` / `selectUpstreamPosition` /
  `selectDownstreamPosition` in `core/document_selection.dart` is deliberately left
  alone: callers do depend on it, and the layers are the right place to tolerate a
  selection that is one frame behind the document. `SingleColumnLayoutSelectionStyler`
  already `try`/`catch`es `getNodesInside` for exactly this reason.
- **Genuine upstream candidate**, not a MemNote-specific behavior change: upstream's
  own guard is right there, one endpoint short, and the fix keeps upstream's stated
  intent. Not yet submitted upstream.
- **Not fixed here**: `AndroidControlsDocumentLayerState` and
  `IosControlsDocumentLayerState` (`infrastructure/platforms/{android,ios}/…`) have the
  same expanded branch with *no* endpoint guard at all, and
  `_AndroidDocumentTouchInteractorState._ensureSelectionExtentIsVisible` null-checks
  `getRectForSelection(...)!` on the same stale selection. Verified by running this
  patch's test with `testWidgetsOnAllPlatforms`: macOS/Windows/Linux pass, Android and
  iOS still throw. Same crash class, different (mobile-only) layers — a separate change.

Tests: `super_editor/test/super_editor/supereditor_selection_test.dart` — group
"SuperEditor selection > with a stale selection", which removes the base node of an
expanded selection without updating the selection and pumps a frame. Verified to fail
with the production exception when the `lib/` change is reverted.

## App-specific (not for upstream)

Thin patches carried on top of upstream `0.3.0-dev.52` — see `git log upstream/main..main`:

- `ImageNode.copyContent`: emit Markdown instead of a bare URL (NOTE-18).
- Teardown/layout null-check guards for four crash sites (NOTE-29).
- Android touch interactor: survive a defunct MediaQuery ancestor.
