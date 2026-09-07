import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor_spellcheck/super_editor_spellcheck.dart';

/// The document these tests spell check. "Hllo" is mis-spelled; the rest of the sentence is
/// somewhere else to tap.
const _paragraphText = "Hllo world, this is a sentence.";

/// Bounds of the mis-spelled word, as a spell checker reports them (end exclusive).
const _misspelledWordStart = 0;
const _misspelledWordEnd = 4;

/// A text offset inside "sentence" - a correctly-spelled word, so a tap there finds no
/// suggestions.
const _correctlySpelledWordOffset = 25;

/// The text offset the tests tap to hit the mis-spelled word.
const _misspelledWordMiddle = (_misspelledWordStart + _misspelledWordEnd) ~/ 2;

const _suggestions = ["Hello", "Hallo"];

const _correctedParagraphText = "Hello world, this is a sentence.";

void main() {
  group("SuperEditor spellcheck > mobile suggestion popover > selection handles >", () {
    // The Android and iOS tap handlers in spelling_and_grammar_plugin.dart are the only
    // callers of preventSelectionHandles()/allowSelectionHandles(), and they're the reason
    // those methods exist: a drag handle sitting on the word the suggestions popover is
    // about would compete with the popover for the user's touch. MemNote NOTE-148/171/176
    // taught every mobile handle to honour the notifier and pinned that with editor-side
    // tests that drive the controller directly; NOTE-181 pins the caller, so dropping
    // either half of the prevent/allow pair goes red here.
    //
    // Every test places an ordinary caret first, and asserts the handle that caret puts on
    // screen. That's not scene-setting: the handle a tap on a mis-spelled word has to
    // suppress is the one the user's *previous* interaction left behind, and without that
    // first tap the editor has no focus, nothing asks for a handle, and the assertions
    // below would pass with the veto removed.

    group("on Android >", () {
      testWidgetsOnAndroid("hides every handle while the popover is up", (tester) async {
        final controlsController = SuperEditorAndroidControlsController();
        addTearDown(controlsController.dispose);
        await _pumpSpellcheckEditor(tester, androidControlsController: controlsController);

        await _placeCaretOnACorrectlySpelledWord(tester);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsOneWidget);

        await _tapMisspelledWord(tester);

        expect(find.byType(AndroidSpellingSuggestionToolbar), findsOneWidget);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsNothing);
        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);
        expect(SuperEditorInspector.findMobileUpstreamDragHandle(), findsNothing);
        expect(SuperEditorInspector.findMobileDownstreamDragHandle(), findsNothing);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);

        // Placing a caret started the collapsed handle's auto-hide countdown, and only the
        // ordinary hideCollapsedHandle() cancels it - which this test never reaches. Cancel
        // it so the test doesn't end on a pending Timer.
        controlsController.cancelCollapsedHandleAutoHideCountdown();
      });

      testWidgetsOnAndroid("keeps the caret handle for the 300ms before the popover appears", (tester) async {
        // Android's tap handler allows handles on the way in, deliberately: it places a
        // collapsed caret at the tap position and only expands the selection to the whole
        // word - and prevents handles - when its 300ms timer fires. That first
        // allowSelectionHandles() is what makes the caret visible in between, and nothing
        // else in this file looks at that window.
        final controlsController = SuperEditorAndroidControlsController();
        addTearDown(controlsController.dispose);
        await _pumpSpellcheckEditor(tester, androidControlsController: controlsController);

        await _placeCaretOnACorrectlySpelledWord(tester);

        // Tap by hand rather than through tapInParagraph, whose trailing pumpAndSettle()
        // would run the 300ms timer and skip past the window under test.
        final gesture = await tester.tapDownInParagraph("1", _misspelledWordMiddle);
        await gesture.up();
        await tester.pump(kTapMinTime + const Duration(milliseconds: 1));

        expect(find.byType(AndroidSpellingSuggestionToolbar), findsNothing);
        expect(controlsController.areSelectionHandlesAllowed.value, isTrue);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsOneWidget);

        // Let the timer fire, and the popover takes the handle's place.
        await tester.pump(const Duration(milliseconds: 400));
        await _settleSuggestionPopover(tester);

        expect(find.byType(AndroidSpellingSuggestionToolbar), findsOneWidget);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsNothing);

        controlsController.cancelCollapsedHandleAutoHideCountdown();
      });

      testWidgetsOnAndroid("allows handles again when the popover is dismissed", (tester) async {
        final controlsController = SuperEditorAndroidControlsController();
        addTearDown(controlsController.dispose);
        await _pumpSpellcheckEditor(tester, androidControlsController: controlsController);

        await _placeCaretOnACorrectlySpelledWord(tester);
        await _tapMisspelledWord(tester);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);

        // Android puts a ModalBarrier over the document while the popover is up, so
        // "tapping elsewhere" is a tap on that barrier. It runs the tap handler's onDismiss,
        // which restores the caret and then calls _hideSpellCheckerPopover().
        await tester.tapAt(tester.getBottomLeft(find.byType(SuperEditor)) + const Offset(10, -10));
        await _settleSuggestionPopover(tester);

        expect(find.byType(AndroidSpellingSuggestionToolbar), findsNothing);
        expect(controlsController.areSelectionHandlesAllowed.value, isTrue);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsOneWidget);

        controlsController.cancelCollapsedHandleAutoHideCountdown();
      });

      testWidgetsOnAndroid("allows handles again when a suggestion is chosen", (tester) async {
        final controlsController = SuperEditorAndroidControlsController();
        addTearDown(controlsController.dispose);
        final editor = await _pumpSpellcheckEditor(tester, androidControlsController: controlsController);

        await _placeCaretOnACorrectlySpelledWord(tester);
        await _tapMisspelledWord(tester);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);

        // Choosing a suggestion never reaches the tap handler. The toolbar edits the
        // document, and it's the toolbar's own document listener - in
        // spelling_error_suggestion_overlay.dart - that allows handles again.
        await tester.tap(find.widgetWithText(TextButton, _suggestions.first));
        await _settleSuggestionPopover(tester);

        expect(_paragraphTextOf(editor), _correctedParagraphText);
        expect(find.byType(AndroidSpellingSuggestionToolbar), findsNothing);
        expect(controlsController.areSelectionHandlesAllowed.value, isTrue);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsOneWidget);

        controlsController.cancelCollapsedHandleAutoHideCountdown();
      });
    });

    group("on iOS >", () {
      testWidgetsOnIos("hides every handle while the popover is up", (tester) async {
        final controlsController = SuperEditorIosControlsController();
        addTearDown(controlsController.dispose);
        await _pumpSpellcheckEditor(tester, iosControlsController: controlsController);

        await _placeCaretOnACorrectlySpelledWord(tester);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsOneWidget);

        await _tapMisspelledWord(tester);

        expect(find.byType(IosSpellingSuggestionToolbar), findsOneWidget);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsNothing);
        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);
        expect(SuperEditorInspector.findMobileUpstreamDragHandle(), findsNothing);
        expect(SuperEditorInspector.findMobileDownstreamDragHandle(), findsNothing);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);
      });

      testWidgetsOnIos("allows handles again when the popover is dismissed", (tester) async {
        final controlsController = SuperEditorIosControlsController();
        addTearDown(controlsController.dispose);
        await _pumpSpellcheckEditor(tester, iosControlsController: controlsController);

        await _placeCaretOnACorrectlySpelledWord(tester);
        await _tapMisspelledWord(tester);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);

        // iOS puts no barrier over the document, so "tapping elsewhere" is an ordinary tap
        // on a correctly-spelled word: the tap handler finds no suggestions there and calls
        // _hideSpellCheckerPopover().
        await tester.tapInParagraph("1", _correctlySpelledWordOffset);
        await _settleSuggestionPopover(tester);

        expect(find.byType(IosSpellingSuggestionToolbar), findsNothing);
        expect(controlsController.areSelectionHandlesAllowed.value, isTrue);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsOneWidget);
      });

      testWidgetsOnIos("allows handles again when a suggestion is chosen", (tester) async {
        final controlsController = SuperEditorIosControlsController();
        addTearDown(controlsController.dispose);
        final editor = await _pumpSpellcheckEditor(tester, iosControlsController: controlsController);

        await _placeCaretOnACorrectlySpelledWord(tester);
        await _tapMisspelledWord(tester);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);

        await tester.tap(find.widgetWithText(TextButton, _suggestions.first));
        await _settleSuggestionPopover(tester);

        expect(_paragraphTextOf(editor), _correctedParagraphText);
        expect(find.byType(IosSpellingSuggestionToolbar), findsNothing);
        expect(controlsController.areSelectionHandlesAllowed.value, isTrue);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsOneWidget);
      });
    });
  });
}

/// Pumps a [SuperEditor] with a [SpellingAndGrammarPlugin] beneath an app-owned mobile
/// controls scope, and waits for the initial spell check to underline [_paragraphText].
///
/// `SuperEditorAndroidControlsScope.rootOf` / `SuperEditorIosControlsScope.rootOf` resolve
/// the root-most scope, so hanging the scope above `SuperEditor` - and handing the plugin
/// that same instance - is what makes [androidControlsController] / [iosControlsController]
/// the controller the handle layers, the overlay manager and the suggestion toolbar all
/// talk to. That's the `_pumpAppOwnedControls` shape from
/// `super_editor/test/super_editor/mobile/super_editor_android_overlay_controls_test.dart`.
Future<Editor> _pumpSpellcheckEditor(
  WidgetTester tester, {
  SuperEditorAndroidControlsController? androidControlsController,
  SuperEditorIosControlsController? iosControlsController,
}) async {
  final editor = createDefaultDocumentEditor(
    document: MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText(_paragraphText)),
      ],
    ),
    composer: MutableDocumentComposer(),
  );

  final plugin = SpellingAndGrammarPlugin(
    androidControlsController: androidControlsController,
    iosControlsController: iosControlsController,
    spellCheckService: _FakeSpellChecker(),
  );

  final superEditor = SuperEditor(editor: editor, plugins: {plugin});

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: androidControlsController != null
            ? SuperEditorAndroidControlsScope(controller: androidControlsController, child: superEditor)
            : SuperEditorIosControlsScope(controller: iosControlsController!, child: superEditor),
      ),
    ),
  );

  // The plugin checks the whole document on attach, across an async boundary to the spell
  // check service. Pump until the suggestions have landed.
  await tester.pump();
  await tester.pump();

  return editor;
}

/// Taps a correctly-spelled word, which focuses the editor and leaves a caret drag handle on
/// screen for the mis-spelled-word tap to suppress.
Future<void> _placeCaretOnACorrectlySpelledWord(WidgetTester tester) async {
  await tester.placeCaretInParagraph("1", _correctlySpelledWordOffset);
  await _settleSuggestionPopover(tester);
}

/// Taps the middle of the mis-spelled word, and pumps until the suggestions popover is up.
Future<void> _tapMisspelledWord(WidgetTester tester) async {
  await tester.tapInParagraph("1", _misspelledWordMiddle);

  // Android holds the popover behind a 300ms timer, so the caret is briefly visible at the
  // tap position before the selection expands to the whole word. iOS shows the popover at
  // once, and doesn't mind the extra elapsed time.
  await tester.pump(const Duration(milliseconds: 400));
  await _settleSuggestionPopover(tester);
}

/// Pumps the handful of frames the suggestion overlay needs to settle.
///
/// The overlay computes its layout during a frame and then shows or hides its `OverlayPortal`
/// from a post-frame callback, so one `pump()` is never enough. This is a bounded loop rather
/// than `pumpAndSettle()` because the editor keeps scheduling frames of its own while a caret
/// is on screen.
Future<void> _settleSuggestionPopover(WidgetTester tester) async {
  for (int i = 0; i < 5; i += 1) {
    await tester.pump();
  }
}

String _paragraphTextOf(Editor editor) => (editor.document.first as ParagraphNode).text.toPlainText();

/// A [SpellCheckService] that reports "Hllo" as mis-spelled, with [_suggestions] as its
/// replacements, so the word is underlined and a tap on it has something to show.
class _FakeSpellChecker extends SpellCheckService {
  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    if (!text.startsWith("Hllo")) {
      // The word was corrected. Nothing is mis-spelled any more.
      return const [];
    }

    return const [
      SuggestionSpan(
        TextRange(start: _misspelledWordStart, end: _misspelledWordEnd),
        _suggestions,
      ),
    ];
  }
}
