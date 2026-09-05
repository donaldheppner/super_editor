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

### HTML paste: don't leak an html2md ignore rule per paste (MemNote NOTE-130)

`super_editor_clipboard/lib/src/editor_paste.dart`

`RichTextPaste.pasteHtml` passed its `ignoredTags` to `html2md.convert`'s
`ignore:` argument. In html2md 1.3.2 that argument is not per-conversion:
`convert()` calls `Rule.addIgnore(ignore)`, which does
`_commonMarkRules.insert(0, buildIgnoreRule(names))` on a **library-level**
`List<Rule>` in `html2md/lib/src/rules.dart`. Nothing dedupes and nothing ever
removes the entry, so the list grows by one rule per call for the life of the
isolate.

Two consequences, both reproduced against the pinned 1.3.2:

- **Cross-call contamination.** The tags one paste ignored stay ignored for
  every later `convert()` in the process — including calls from unrelated code
  that passed no `ignore:` at all. 200 calls, each ignoring a different tag,
  left all 200 tags ignored on a subsequent no-`ignore:` conversion.
- **Unbounded slowdown.** `Rule.findRule` walks the list per node, so every
  conversion anywhere in the app gets slower. 400 conversions of a small
  document took 130 ms after ~200 ignore calls and 1004 ms after ~20 200 — a
  7.7x regression.

`pasteHtml` now parses the HTML itself, removes the ignored elements from the
DOM (matching on lowercase local name, the way html2md's `ignore:` filter did),
and hands `html2md.convert` the resulting `<html>` element. That is what
`convert` does to a `String` input anyway
(`parse(input).getElementsByTagName('html').first`), so output is unchanged; the
package gains a direct `html` dependency it already had transitively via
html2md.

The real fix belongs in html2md — `addIgnore` should dedupe, or ignores should
be scoped to one conversion — but that is a separate package and its own call;
this is the fix that removes the leak from super_editor. Genuine upstream
candidate for super_editor: it is a defect in upstream's code, the ignore
semantics are preserved exactly, and it needs no API change. Not yet submitted
upstream.

Tests: `super_editor_clipboard/test/copy_and_paste_test.dart` — new
"doesn't leak one paste's ignored tags into the next paste" (a paste with
`ignoredTags: {"aside"}` followed by a default paste that must keep its
`<aside>`). It fails on the pre-fix implementation (1 node instead of 2) and
passes after. The package's 12 tests pass; note that running them at all needs
local path overrides for `super_editor`/`super_keyboard`, because the pub.dev
`super_editor: ^0.3.0-dev.52` this package resolves to no longer compiles
against current Flutter (`TextInputStyle` / `TextInputConnection.updateStyle`).
That is pre-existing and unrelated.

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
- **Not fixed here, fixed in NOTE-116 below**: `AndroidControlsDocumentLayerState`,
  `IosControlsDocumentLayerState`, and the two touch interactors'
  `_ensureSelectionExtentIsVisible` had the same crash class on the mobile-only paths
  this patch doesn't reach. That's why this patch's test was originally pinned to
  `testWidgetsOnArbitraryDesktop`; NOTE-116 widened it to `testWidgetsOnAllPlatforms`.

Tests: `super_editor/test/super_editor/supereditor_selection_test.dart` — group
"SuperEditor selection > with a stale selection", which removes the base node of an
expanded selection without updating the selection and pumps a frame. Runs on all
platforms (desktop-only until NOTE-116 fixed the mobile layers). Verified to fail with
the production exception on macOS/Windows/Linux when this `lib/` change is reverted.

### IME delta path: a throw must not permanently disable IME re-sync (MemNote NOTE-115)

`super_editor/lib/src/default_editor/document_ime/document_ime_communication.dart`,
`super_editor/lib/src/default_editor/document_ime/document_delta_editing.dart`

- `DocumentImeInputClient.updateEditingValueWithDeltas` raised `_isApplyingDeltas`, called
  `textDeltasDocumentEditor.applyDeltas(...)`, and lowered the flag *after* the call, with
  no `try`/`finally`. `applyDeltas` rethrows unknown exceptions on purpose, so any throw out
  of the delta loop both (a) latched `_isApplyingDeltas` to `true` for the lifetime of the
  client and (b) skipped the `_sendDocumentToIme()` that normally follows. That flag gates
  `_sendDocumentToIme()`, `_onContentChange()`, and `setEditingState()`, so after one throw
  *every* subsequent attempt to re-sync the IME with the document fizzled silently: the
  editor kept running while our document and the platform IME drifted apart, with no way
  back. NOTE-112 removed one route into this state; this hardens the flag itself.
- The `applyDeltas` call is now wrapped in `try`/`catch`/`finally`. The `finally` lowers the
  flag; the re-sync runs after it, so it sees the flag already lowered instead of fizzling on
  its own guard. The failure path is exactly when the two sides most need to be put back in
  agreement (the document holds some of the batch, the platform holds all of it).
- The error itself is **held, not rethrown from a `finally`**. Putting `_sendDocumentToIme()`
  in the `finally` looks tidy but is wrong: `_sendDocumentToIme()` can throw, and a throw out
  of a `finally` *replaces* the exception that is already unwinding. The error `applyDeltas`
  deliberately rethrew — the one the app reports — would be silently swapped for the
  recovery's error. So the `catch` stores the error and stack trace, the recovery runs guarded,
  and `Error.throwWithStackTrace` re-raises the original with its original stack trace. On the
  nominal path (no error in flight) the re-sync is *not* guarded, so a throw there propagates
  exactly as it always has — only the unwinding case is special-cased. This matters because
  the change is what makes `_sendDocumentToIme()` run during unwinding at all, and the throw it
  can produce there is the very residual noted below (a half-applied batch can leave the
  selection pointing at content the document no longer has).
- `_sendDocumentToIme()` had the identical defect one method away: it raised `_isSendingToIme`,
  serialized the document (which can throw), and lowered the flag afterwards, so a throw
  there latched *that* flag and made every later send return at its guard. Its body is now
  in a `try`/`finally` too. This matters more after the change above, because the method is
  now also called while unwinding a failed batch, where a serializer throw is likelier.
- **Judgement call — `_calculateNewComposingRegion` stays outside the delta loop's
  `try`/`catch`, and gets its own guard instead.** It can throw
  `FailedToMapImePositionToDocumentPositionException` (via `imeToDocumentRange`), and it runs
  after the loop's `finally`, so today that throw escapes `applyDeltas` and defeats the two
  typed catches' "swallow the mapping failure, keep the editor working, let the client
  re-sync" contract — the very contract those catches were added for, and the scenario is
  reachable precisely *because* an aborted batch leaves the composing region describing text
  we no longer have. It can't simply move inside the existing block: that block's `finally`
  ends the editor transaction, and the post-transaction work has to stay post-transaction —
  reactions run at `endTransaction` and can change the document again, which is why
  `_serializedDoc` is rebuilt immediately after it. Moving the call in would either serialize
  a pre-reaction document or fold the `ChangeComposingRegionRequest` into the user's undoable
  transaction. So it keeps its position and gets a narrow `on
  FailedToMapImePositionToDocumentPositionException` catch that reports through the same
  `log?.onFailedToMapImePositionToDocumentPosition` hook and clears the composing region.
  Clearing (rather than leaving a stale region) mirrors what `_calculateNewComposingRegion`
  already does when the composing region runs past the end of our text. Unknown exceptions
  there are still not caught, so the rethrow contract is unchanged.
- `_applyInsertion`'s `isPositionInsidePlaceholder` space guard now updates `_previousImeValue`
  before returning, like the newline and tab guards beside it and like the NOTE-112 drop guard.
  This is inert today — `TextEditingDelta.apply` rebuilds from `delta.oldText`, so
  `_previousImeValue` isn't really an accumulator — but the inconsistency was latently wrong
  if that Flutter behaviour ever changes.
- **Not fixed here**: the `selection.value!` force-unwrap in the post-transaction
  re-serialization of `applyDeltas` (a batch that empties the document could null the
  selection), and the same unwrap in `_sendDocumentToIme` — plus the `getNodeById(...)!` that
  `DocumentImeSerializer` reaches through `getNodesInContentOrder` when the selection names a
  node the document no longer has. These still throw. What has changed is the blast radius: a
  throw from any of them during recovery is now caught, reported through `editorImeLog.shout`,
  and can no longer eat the original error or re-latch the flags, so the client stays usable
  and the app still gets the report it was owed. Making them not throw is a separate
  null-safety change.
- **Genuine upstream candidate**, not a MemNote-specific behavior change: upstream already
  uses a `finally` a few lines away for exactly this reason ("We must always end the
  transaction, even if an error occurred. Otherwise… the editor will never stabilize"), and
  this applies the same rule to the two flags that gate IME re-sync. Not yet submitted
  upstream.

Tests: `super_editor/test/super_editor/text_entry/ime/ime_typing_test.dart` — group
"IME input > typing > after an exception while applying deltas", two tests.

1. "the IME is re-synced and the next keystroke still lands" (widget level, all five
   platforms) sends a two-delta batch whose first delta applies and whose second one throws
   from an injected `EditRequestHandler`, then asserts the exception still escaped, that the
   client re-synced the IME with the document, and that the next keystroke lands at the caret.
   Verified to fail on all five platforms with the `lib/` change stashed
   (`Expected: a string ending with 'Hello World'  Actual: '. Hello'` — the IME frozen at its
   pre-batch value).
2. "the original error survives a recovery that also throws" covers the masking window. It
   builds a `DocumentImeInputClient` over a `TextDeltasDocumentEditor` subclass whose
   `applyDeltas` points the shared selection notifier at a node the document doesn't have and
   then throws, so the recovery's `DocumentImeSerializer` throws too. It asserts the caller
   sees the delta error rather than the recovery's, that the recovery genuinely failed (the
   IME value is still untouched, so the test can't pass by never entering the window), and
   that a later successful batch still reaches the IME — which only happens if both
   `_isApplyingDeltas` and `_isSendingToIme` were cleared. Verified to fail against the
   `finally`-based version of the fix: `Expected: <Instance of '_DeltaApplicationException'>
   Actual: _TypeError:<Null check operator used on a null value>`.

### Android/iOS controls layers: guard both ends of the selection (MemNote NOTE-116)

`super_editor/lib/src/infrastructure/platforms/android/android_document_controls.dart`,
`super_editor/lib/src/infrastructure/platforms/ios/ios_document_controls.dart`,
`super_editor/lib/src/default_editor/document_gestures_touch_android.dart`,
`super_editor/lib/src/default_editor/document_gestures_touch_ios.dart`,
`super_editor/lib/src/chat/super_message_android_overlays.dart`

- NOTE-111 above fixed the *desktop* selection leaders layer.
  `AndroidControlsDocumentLayerState.computeLayoutDataWithDocumentLayout` and
  `IosControlsDocumentLayerState.computeLayoutDataWithDocumentLayout` carry the identical
  expanded branch — `getRectForPosition(document.selectUpstreamPosition(base, extent))!` —
  and had *no* endpoint guard at all, not even the extent-only one NOTE-111 started from.
  The same stale selection therefore throws `Exception: No such position in document` out
  of `getAffinityBetween`, again from inside the `ContentLayers` layout pass
  (`RenderSliverContentLayers.performLayout` → `ContentLayersElement.buildLayers` →
  `ContentLayerState.build`), where a throw is a fatal frame error rather than something
  the framework can recover from. Both endpoints are now checked against the document
  before *either* branch runs, in the same "momentary transitive state → return null"
  idiom; `doBuild` on both layers already renders `const SizedBox()` for null layout data.
- Confirmed rather than assumed. Widening NOTE-111's test to `testWidgetsOnAllPlatforms`
  *before* touching `lib/` gave 6 passes and 4 failures: on Android and iOS, on both the
  base-removed and the extent-removed case, the run reports `_Exception ... thrown building
  AndroidHandlesDocumentLayer` / `IosHandlesDocumentLayer` with `Exception: No such
  position in document: [DocumentPosition] - node: "1"`, plus a second, independent
  `_TypeError: Null check operator used on a null value` from
  `_ensureSelectionExtentIsVisible`. Note the mobile layers fail on the *extent*-removed
  case too, which desktop never did — the extent-only guard NOTE-111 inherited simply isn't
  there.
- The sibling force-unwraps on the same two methods became null checks, for the reason
  NOTE-111 gives: `getEdgeForPosition` / `getRectForPosition` / `getRectForSelection` are
  all declared nullable on `DocumentLayout`, and their null case *is* this same transitive
  state — the node resolves in the document while the layout has no component for it yet
  (it already logs "Could not find any component for node position"). The document-level
  guard cannot subsume them: they answer a different question, about the *layout* rather
  than the document, and the two are allowed to be a frame apart in either direction. `!`
  turned a one-frame gap into a fatal; `return null` costs one frame of handles and
  self-corrects. No behavior change when the rects resolve.
- **Judgement call — iOS's `_computeRectForExpandedHandle` now returns `Rect?`, and its
  pre-existing `Rect.zero` fallback goes with it.** The method had two `!`s of its own
  (`getRectForPosition(position)!` and `getRectForSelection(...)!`) plus an early
  `return Rect.zero` when the position's component is missing. All three are the same
  condition — the layout can't place this position right now — so answering `Rect.zero` for
  one and throwing for the other two was incoherent. `Rect.zero` is not a handle position
  anyone wants: it pins the handle to the document origin, visibly detached from the
  selection. Returning null for all three and letting the caller skip the frame is both
  consistent and the better degradation. This is the one place where behavior changes on a
  path that previously didn't throw, and it costs a frame of handles in a state that was
  already drawing a wrong one.
- **Judgement call — `_ensureSelectionExtentIsVisible` is hardened, on iOS as well as
  Android.** The ticket flagged the Android copy; the iOS copy
  (`document_gestures_touch_ios.dart`) is line-for-line the same and fails in the same run,
  so both are fixed. This one is *not* a layout callback — it runs from `onNextFrame` after
  a document or selection change — so a throw here is an uncaught scheduler-callback error,
  not a fatal frame error. It's still worth fixing, and the fix isn't merely defensive: the
  method's whole job is the best-effort "scroll so the selection extent is visible", and
  when the selection names a node the document has dropped there is nothing to scroll to,
  so doing nothing is the *correct* answer rather than a fallback. The next selection change
  schedules another one. The Android copy already establishes exactly this idiom, with its
  `!mounted` / detached-render-object early returns from NOTE-29.
- It needs two guards, not one. Null-checking `getRectForSelection(...)!` alone would leave
  `document.getAffinityForSelection(selection)` on the next line throwing `No such position
  in document`, and that call keys off the *document* while `getRectForSelection` keys off
  the *layout* — a component can outlive its node by a frame, so the rect can resolve when
  the affinity can't. The document-level endpoint check therefore comes first and the rect
  null check second. Neither is redundant with the other, and neither is redundant with the
  layer guards above: this method reads the document and the layout directly, not through a
  layer.
- **Deliberately left alone**: `widget.dragHandleAutoScroller.value!` at the end of the
  Android copy (iOS uses `?.` there). It is a force-unwrap on the same method, but it is not
  this crash class — it fails on a missing auto-scroller, not on a stale selection — and the
  inconsistency between the two platforms should be settled on its own evidence. Also left
  alone, as in NOTE-111: the throwing contract of `getAffinityBetween` /
  `selectUpstreamPosition` / `selectDownstreamPosition`, and the many `getRectFor…(...)!`
  unwraps in `long_press_selection.dart`, `drag_handle_selection.dart` and the interactors'
  drag paths. Those run from gesture handlers against a selection the user is actively
  dragging, not from a layout or deferred callback against a selection that may be a frame
  stale, so they are not the same defect.
- Checked, because returning null from a path that previously always produced a value is the
  risk this change introduces: nothing consumes these layers' `layoutData` non-null. Both
  layers already return null for three earlier conditions (no selection, handles not
  allowed, and no `DocumentLayout` in `DocumentLayoutLayerState.computeLayoutData`), so the
  null path is the routine one and `doBuild` handles it. The only external readers are the
  `@visibleForTesting` getters on the layer states (`caret`, `isCaretDisplayed`,
  `isUpstreamHandleDisplayed`, `isDownstreamHandleDisplayed`), all of which already read
  through `layoutData?.`, and `SuperEditorInspector` reaches them through those same
  getters. The iOS toolbar focal point is a separate layer
  (`IosToolbarFocalPointDocumentLayer`), unaffected by these layers skipping a frame.
- **Beyond the ticket's scope, deliberately**:
  `SuperMessageAndroidControlsDocumentLayerState` in `chat/super_message_android_overlays.dart`
  is a verbatim copy of the Android controls layer, defect included, so it got the same
  two guards. MemNote doesn't use `SuperMessage` and the acceptance test doesn't reach this
  class, so this one is argued from the code being identical rather than from an observed
  failure. The iOS chat overlays reuse `IosHandlesDocumentLayer` and inherit the fix; the
  chat touch interactors have no `_ensureSelectionExtentIsVisible`, so there is no third
  copy of that half.
- **Genuine upstream candidate**, for the same reason NOTE-111 is: the same defect on the
  same widget family, it keeps upstream's stated intent, and it changes nothing when the
  document and the selection agree. Not yet submitted upstream.

Tests: NOTE-111's group in `super_editor/test/super_editor/supereditor_selection_test.dart`
— "SuperEditor selection > with a stale selection" — widened from
`testWidgetsOnArbitraryDesktop` to `testWidgetsOnAllPlatforms`. That widening is the whole
acceptance check: 6 passing / 4 failing before the `lib/` change (the four mobile variants,
with the two exceptions quoted above), 10 passing after. The fork suite goes from 5649 to
5657 passing, 7 skipped either way — `testWidgetsOnArbitraryDesktop` emits *one* test per
call (it picks one desktop platform), `testWidgetsOnAllPlatforms` emits five, so two calls
go from 2 tests to 10.

## App-specific (not for upstream)

Thin patches carried on top of upstream `0.3.0-dev.52` — see `git log upstream/main..main`:

- `ImageNode.copyContent`: emit Markdown instead of a bare URL (NOTE-18).
- Teardown/layout null-check guards for four crash sites (NOTE-29).
- Android touch interactor: survive a defunct MediaQuery ancestor.
