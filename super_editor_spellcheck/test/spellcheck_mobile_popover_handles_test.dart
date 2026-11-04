import 'package:flutter/foundation.dart';
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

      testWidgetsOnAndroid("recovers handles on the next tap when the popover left them prevented", (tester) async {
        // The recovery path, and the only thing that exercises Android onTap's pre-timer
        // allowSelectionHandles(). A popover can go away without either of the two calls
        // that allow handles running, and when it does the editor is left with handles
        // prevented and no popover; the pre-timer call is what un-sticks the next tap on a
        // mis-spelled word.
        //
        // NOTE-182 reached that state by clearing the selection, which was the ordinary way
        // in until NOTE-187 closed it (see "when the selection goes away >" below). The route
        // left is an app hiding the popover through the tap handler's public
        // SpellCheckerPopoverController, reachable from the plugin's contentTapHandlers: hide()
        // only tells the overlay to forget its suggestions, and nothing allows handles.
        final controlsController = SuperEditorAndroidControlsController();
        addTearDown(controlsController.dispose);
        final plugin = _createSpellcheckPlugin(androidControlsController: controlsController);
        await _pumpSpellcheckEditor(tester, androidControlsController: controlsController, plugin: plugin);

        await _placeCaretOnACorrectlySpelledWord(tester);
        await _tapMisspelledWord(tester);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);

        _popoverControllerOf(plugin).hide();
        await _settleSuggestionPopover(tester);

        // The popover is gone and nothing allowed handles again.
        expect(find.byType(AndroidSpellingSuggestionToolbar), findsNothing);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);

        // Tap by hand, for the same reason the 300ms-window test above does: a trailing
        // pumpAndSettle() would run the timer and skip past the window this asserts on.
        final gesture = await tester.tapDownInParagraph("1", _misspelledWordMiddle);
        await gesture.up();
        await tester.pump(kTapMinTime + const Duration(milliseconds: 1));

        expect(controlsController.areSelectionHandlesAllowed.value, isTrue);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsOneWidget);

        // Let the timer fire, so the test doesn't end on a pending Timer.
        await tester.pump(const Duration(milliseconds: 400));
        await _settleSuggestionPopover(tester);

        controlsController.cancelCollapsedHandleAutoHideCountdown();
      });

      testWidgetsOnAndroid("survives the editor going away inside the 300ms window", (tester) async {
        // Android's tap handler does its real work in a 300ms timer, and that timer holds
        // no weak reference to anything: if the plugin is detached while it's pending -
        // the editor replaced, or the whole editor disposed, which
        // SpellingAndGrammarPlugin.detach answers by nulling `editor` - it used to
        // prevent selection handles and *then* throw on `editor!`, so an app that left
        // the note within 300ms of tapping a mis-spelled word got an unhandled
        // "Null check operator used on a null value" out of a Timer and a controls
        // controller vetoed by a handler that no longer had an editor. The timer now
        // bails out before the cascade.
        final controlsController = SuperEditorAndroidControlsController();
        addTearDown(controlsController.dispose);
        await _pumpSpellcheckEditor(tester, androidControlsController: controlsController);

        await _placeCaretOnACorrectlySpelledWord(tester);

        // Tap by hand: a trailing pumpAndSettle() would run the timer before the editor
        // can go away, which is the whole window under test.
        final gesture = await tester.tapDownInParagraph("1", _misspelledWordMiddle);
        await gesture.up();
        await tester.pump(kTapMinTime + const Duration(milliseconds: 1));

        // The editor goes away with the timer still pending.
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
        await tester.pump(const Duration(milliseconds: 400));
        await _settleSuggestionPopover(tester);

        expect(tester.takeException(), isNull);
        expect(controlsController.areSelectionHandlesAllowed.value, isTrue);

        controlsController.cancelCollapsedHandleAutoHideCountdown();
      });

      testWidgetsOnAndroid("swallows a drag rather than dismissing the popover", (tester) async {
        // Android's tap handler has no onPanStart override, unlike its iOS twin, and that's
        // deliberate - see the doc comment on SuperEditorAndroidSpellCheckerTapHandler. This
        // test pins the behaviour that makes the asymmetry moot: the ModalBarrier the popover
        // hangs over the document absorbs the drag, so nothing underneath it moves and there's
        // nothing for a handler to react to. If that barrier ever goes away, this goes red and
        // MemNote NOTE-183's question reopens.
        final controlsController = SuperEditorAndroidControlsController();
        addTearDown(controlsController.dispose);
        await _pumpSpellcheckEditor(
          tester,
          androidControlsController: controlsController,
          // Enough content to overflow the viewport, so "the document didn't scroll" is a real
          // assertion rather than a vacuous one about an unscrollable fixture.
          fillerParagraphCount: 40,
        );

        await _placeCaretOnACorrectlySpelledWord(tester);
        await _tapMisspelledWord(tester);

        final wordSelection = SuperEditorInspector.findDocumentSelection();
        expect(find.byType(AndroidSpellingSuggestionToolbar), findsOneWidget);
        expect(_documentScrollOffset(tester), 0.0);

        await _dragUpOnTheDocument(tester);

        // The barrier ate all of it: the popover is still up, the selection hasn't moved, the
        // document hasn't scrolled, and handles are still prevented.
        expect(find.byType(AndroidSpellingSuggestionToolbar), findsOneWidget);
        expect(SuperEditorInspector.findDocumentSelection(), wordSelection);
        expect(_documentScrollOffset(tester), 0.0);
        expect(controlsController.areSelectionHandlesAllowed.value, isFalse);
        expect(SuperEditorInspector.findMobileCaretDragHandle(), findsNothing);
        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);

        // The identical drag does scroll once the popover is gone. That's what makes the
        // assertions above about the barrier, rather than about a document that can't scroll.
        await tester.tapAt(tester.getBottomLeft(find.byType(SuperEditor)) + const Offset(10, -10));
        await _settleSuggestionPopover(tester);
        expect(find.byType(AndroidSpellingSuggestionToolbar), findsNothing);

        await _dragUpOnTheDocument(tester);
        expect(_documentScrollOffset(tester), greaterThan(0.0));

        controlsController.cancelCollapsedHandleAutoHideCountdown();
      });

      _selectionLossTests(testWidgetsOnAndroid);
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

      _selectionLossTests(testWidgetsOnIos);
    });
  });
}

/// The selection going away while the popover is up (MemNote NOTE-187), registered once per
/// mobile platform with that platform's runner.
///
/// The overlay hides its toolbar whenever the selection is null, and that used to be the
/// popover's one exit that ran no cleanup: neither the tap handler's `_hideSpellCheckerPopover()`
/// nor the toolbar's own document listener, so selection handles stayed prevented, the
/// overlay kept the suggestions it was showing, and the popover controller still said it was
/// showing. A null selection is ordinary on both platforms - `SuperEditorSelectionPolicies`
/// clears it when the editor loses focus and when the IME connection closes, both by default -
/// and neither route is a pointer, so Android's `ModalBarrier` can't absorb it.
void _selectionLossTests(void Function(String description, WidgetTesterCallback test) testWidgetsOnPlatform) {
  group("when the selection goes away >", () {
    testWidgetsOnPlatform("allows handles again", (tester) async {
      final popover = await _pumpWithPopoverUp(tester);

      popover.editor.execute([const ClearSelectionRequest()]);
      await _settleSuggestionPopover(tester);

      expect(_findSuggestionToolbar(), findsNothing);
      expect(popover.handlesAllowed.value, isTrue);
      expect(popover.popoverController.isShowing, isFalse);

      popover.finish();
    });

    testWidgetsOnPlatform("allows handles again when the editor loses focus", (tester) async {
      final popover = await _pumpWithPopoverUp(tester);

      popover.focusNode.unfocus();
      await _settleSuggestionPopover(tester);

      // clearSelectionWhenEditorLosesFocus did this, not the test.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);
      expect(_findSuggestionToolbar(), findsNothing);
      expect(popover.handlesAllowed.value, isTrue);
      expect(popover.popoverController.isShowing, isFalse);

      popover.finish();
    });

    testWidgetsOnPlatform("allows handles again when the IME connection closes", (tester) async {
      final popover = await _pumpWithPopoverUp(tester);

      // Closed the way an app closes it, which is the route upstream's own test of this policy
      // takes ("SuperEditor software keyboard > in automatic control mode > clears selection
      // when it closes"). The engine's own onConnectionClosed - tester.testTextInput
      // .closeConnection() - doesn't get this far: DocumentImeInputClient.connectionClosed only
      // logs, so the policy never sees the connection close and the selection stays.
      expect(popover.softwareKeyboardController.isConnectedToIme, isTrue);
      popover.softwareKeyboardController.close();
      await _settleSuggestionPopover(tester);

      // clearSelectionWhenImeConnectionCloses did this, not the test.
      expect(SuperEditorInspector.findDocumentSelection(), isNull);
      expect(_findSuggestionToolbar(), findsNothing);
      expect(popover.handlesAllowed.value, isTrue);
      expect(popover.popoverController.isShowing, isFalse);

      popover.finish();
    });

    testWidgetsOnPlatform("doesn't bring the old popover back when the selection does", (tester) async {
      final popover = await _pumpWithPopoverUp(tester);
      final wordSelection = SuperEditorInspector.findDocumentSelection();

      popover.focusNode.unfocus();
      await _settleSuggestionPopover(tester);
      expect(SuperEditorInspector.findDocumentSelection(), isNull);

      // Regaining focus restores the previous selection - the mis-spelled word - without a tap,
      // so nothing consults the tap handler. The overlay used to still hold that word's
      // suggestions, and showed them again with handles still prevented.
      popover.focusNode.requestFocus();
      await _settleSuggestionPopover(tester);

      expect(SuperEditorInspector.findDocumentSelection(), wordSelection);
      expect(_findSuggestionToolbar(), findsNothing);
      expect(popover.handlesAllowed.value, isTrue);

      // It came back with the caret on a correctly-spelled word, too.
      popover.editor.execute([
        const ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: _correctlySpelledWordOffset),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
      await _settleSuggestionPopover(tester);

      expect(_findSuggestionToolbar(), findsNothing);
      expect(popover.handlesAllowed.value, isTrue);

      popover.finish();
    });

    testWidgetsOnPlatform("draws the handles of a long-press selection made afterwards", (tester) async {
      // A long press never consults the content tap handlers, so it can't reach
      // _hideSpellCheckerPopover() the way a tap or double-tap does. While handles stayed
      // prevented, it landed a real selection with nothing drawn on it: no caret, no handles.
      final popover = await _pumpWithPopoverUp(tester);

      popover.editor.execute([const ClearSelectionRequest()]);
      await _settleSuggestionPopover(tester);

      await tester.longPressInParagraph("1", _correctlySpelledWordOffset);
      await _settleSuggestionPopover(tester);

      final selection = SuperEditorInspector.findDocumentSelection();
      expect(selection, isNotNull);
      expect(selection!.isCollapsed, isFalse);
      expect(popover.handlesAllowed.value, isTrue);
      expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNWidgets(2));

      // The popover's selection colour went with it. Only Android sets one by default.
      if (defaultTargetPlatform == TargetPlatform.android) {
        expect(tester.widget<TextComponent>(find.byType(TextComponent)).selectionColor,
            isNot(_androidPopoverSelectionColor));
      }

      popover.finish();
    });
  });
}

/// The selection colour `SpellingAndGrammarPlugin` uses on Android, by default, while the
/// popover is up.
final _androidPopoverSelectionColor = Colors.red.withValues(alpha: 0.3);

/// Pumps a [SuperEditor] with a [SpellingAndGrammarPlugin] beneath an app-owned mobile
/// controls scope, and waits for the initial spell check to underline [_paragraphText].
///
/// `SuperEditorAndroidControlsScope.rootOf` / `SuperEditorIosControlsScope.rootOf` resolve
/// the root-most scope, so hanging the scope above `SuperEditor` - and handing the plugin
/// that same instance - is what makes [androidControlsController] / [iosControlsController]
/// the controller the handle layers, the overlay manager and the suggestion toolbar all
/// talk to. That's the `_pumpAppOwnedControls` shape from
/// `super_editor/test/super_editor/mobile/super_editor_android_overlay_controls_test.dart`.
/// Pass a non-zero [fillerParagraphCount] to append that many throwaway paragraphs after the
/// spell-checked one, which is how a test gets a document tall enough to scroll.
///
/// Pass a [plugin] to get hold of the one the editor uses (see [_createSpellcheckPlugin]), and a
/// [focusNode] to move the editor's focus by hand, and a [softwareKeyboardController] to close
/// the IME connection the way an app does.
Future<Editor> _pumpSpellcheckEditor(
  WidgetTester tester, {
  SuperEditorAndroidControlsController? androidControlsController,
  SuperEditorIosControlsController? iosControlsController,
  int fillerParagraphCount = 0,
  SpellingAndGrammarPlugin? plugin,
  FocusNode? focusNode,
  SoftwareKeyboardController? softwareKeyboardController,
}) async {
  final editor = createDefaultDocumentEditor(
    document: MutableDocument(
      nodes: [
        ParagraphNode(id: "1", text: AttributedText(_paragraphText)),
        for (int i = 0; i < fillerParagraphCount; i += 1)
          ParagraphNode(id: "filler-$i", text: AttributedText("Filler paragraph number $i, with some text in it.")),
      ],
    ),
    composer: MutableDocumentComposer(),
  );

  plugin ??= _createSpellcheckPlugin(
    androidControlsController: androidControlsController,
    iosControlsController: iosControlsController,
  );

  final superEditor = SuperEditor(
    editor: editor,
    focusNode: focusNode,
    softwareKeyboardController: softwareKeyboardController,
    plugins: {plugin},
  );

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

/// Creates the [SpellingAndGrammarPlugin] these tests attach, checking spelling with
/// [_FakeSpellChecker].
SpellingAndGrammarPlugin _createSpellcheckPlugin({
  SuperEditorAndroidControlsController? androidControlsController,
  SuperEditorIosControlsController? iosControlsController,
}) {
  return SpellingAndGrammarPlugin(
    androidControlsController: androidControlsController,
    iosControlsController: iosControlsController,
    spellCheckService: _FakeSpellChecker(),
  );
}

/// The [SpellCheckerPopoverController] the [plugin]'s mobile tap handler shows and hides the
/// popover through.
SpellCheckerPopoverController _popoverControllerOf(SpellingAndGrammarPlugin plugin) {
  return switch (plugin.contentTapHandlers.single) {
    SuperEditorAndroidSpellCheckerTapHandler(:final popoverController) => popoverController,
    SuperEditorIosSpellCheckerTapHandler(:final popoverController) => popoverController,
    final handler => throw StateError("No mobile spellcheck tap handler: $handler"),
  };
}

/// The suggestions toolbar the platform under test shows.
Finder _findSuggestionToolbar() => switch (defaultTargetPlatform) {
      TargetPlatform.android => find.byType(AndroidSpellingSuggestionToolbar),
      TargetPlatform.iOS => find.byType(IosSpellingSuggestionToolbar),
      _ => find.byType(DesktopSpellingSuggestionToolbar),
    };

/// A spellcheck editor with the suggestions popover up over the mis-spelled word, on the
/// platform under test - see [_pumpWithPopoverUp].
class _PopoverUp {
  _PopoverUp({
    required this.editor,
    required this.plugin,
    required this.focusNode,
    required this.softwareKeyboardController,
    required this.handlesAllowed,
    this.androidControlsController,
  });

  final Editor editor;
  final SpellingAndGrammarPlugin plugin;
  final FocusNode focusNode;
  final SoftwareKeyboardController softwareKeyboardController;

  /// The `areSelectionHandlesAllowed` notifier of the controls controller the plugin was
  /// handed, whichever platform that is.
  final ValueListenable<bool> handlesAllowed;

  final SuperEditorAndroidControlsController? androidControlsController;

  SpellCheckerPopoverController get popoverController => _popoverControllerOf(plugin);

  /// Ends the test without a pending `Timer`: on Android, placing a caret starts the collapsed
  /// handle's auto-hide countdown (see "hides every handle while the popover is up").
  void finish() => androidControlsController?.cancelCollapsedHandleAutoHideCountdown();
}

/// Pumps a spellcheck editor for the platform under test, places a caret on a correctly-spelled
/// word, taps the mis-spelled one, and checks the popover is up with handles prevented - the
/// starting point of every "selection goes away" test.
Future<_PopoverUp> _pumpWithPopoverUp(WidgetTester tester) async {
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);
  final softwareKeyboardController = SoftwareKeyboardController();

  SuperEditorAndroidControlsController? androidControlsController;
  SuperEditorIosControlsController? iosControlsController;
  late final ValueListenable<bool> handlesAllowed;
  if (defaultTargetPlatform == TargetPlatform.android) {
    androidControlsController = SuperEditorAndroidControlsController();
    addTearDown(androidControlsController.dispose);
    handlesAllowed = androidControlsController.areSelectionHandlesAllowed;
  } else {
    iosControlsController = SuperEditorIosControlsController();
    addTearDown(iosControlsController.dispose);
    handlesAllowed = iosControlsController.areSelectionHandlesAllowed;
  }

  final plugin = _createSpellcheckPlugin(
    androidControlsController: androidControlsController,
    iosControlsController: iosControlsController,
  );
  final editor = await _pumpSpellcheckEditor(
    tester,
    androidControlsController: androidControlsController,
    iosControlsController: iosControlsController,
    plugin: plugin,
    focusNode: focusNode,
    softwareKeyboardController: softwareKeyboardController,
  );

  await _placeCaretOnACorrectlySpelledWord(tester);
  await _tapMisspelledWord(tester);

  expect(_findSuggestionToolbar(), findsOneWidget);
  expect(handlesAllowed.value, isFalse);
  expect(_popoverControllerOf(plugin).isShowing, isTrue);

  return _PopoverUp(
    editor: editor,
    plugin: plugin,
    focusNode: focusNode,
    softwareKeyboardController: softwareKeyboardController,
    handlesAllowed: handlesAllowed,
    androidControlsController: androidControlsController,
  );
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

/// Drags upward from the middle of the editor, far enough past touch slop to scroll a document
/// that can scroll.
///
/// The start point is the middle of the editor rather than a text offset so the touch can't land
/// on the caret: Android's `EagerPanGestureRecognizer.shouldAccept` claims the pan when it starts
/// over the caret, which drags the caret instead of scrolling.
Future<void> _dragUpOnTheDocument(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getRect(find.byType(SuperEditor)).center);
  for (int i = 0; i < 10; i += 1) {
    await gesture.moveBy(const Offset(0, -12));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await _settleSuggestionPopover(tester);
}

/// The scroll offset of the editor's viewport.
double _documentScrollOffset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

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
