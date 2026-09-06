import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_keyboard/test/keyboard_simulator.dart';
import 'package:super_text_layout/super_text_layout.dart';

import '../../test_runners.dart';
import '../../test_tools.dart';
import '../test_documents.dart';

void main() {
  group("SuperEditor > iOS > overlay controls >", () {
    testWidgetsOnIos("hides all controls when placing the caret", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Place the caret.
      await tester.tapInParagraph("1", 200);

      // Ensure all controls are hidden.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
    });

    testWidgetsOnIos("toggles toolbar when tapping on caret (with software keyboard)", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Place the caret at the end of a word, because iOS snaps the caret
      // to word boundaries by default.
      await tester.tapInParagraph("1", 207);

      // Ensure all controls are hidden.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Tap again on the caret.
      await tester.tapInParagraph("1", 207);

      // Ensure that the toolbar is visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);

      // Tap on the caret again, to toggle the toolbar off.
      await tester.tapInParagraph("1", 207);

      // Ensure that the toolbar is hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
    });

    testWidgetsOnIos("hides toolbar when IME connection is closed (with software keyboard)", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Place the caret at the end of a word, because iOS snaps the caret
      // to word boundaries by default.
      await tester.tapInParagraph("1", 207);

      // Ensure all controls are hidden.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Tap again on the caret.
      await tester.tapInParagraph("1", 207);

      // Ensure that the toolbar is visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);

      // Take the IME connection away from Super Editor. The best we can do to
      // simulate this is to move the focus somewhere else. In practice, this is
      // how it actually occurs. It's not obvious under which circumstances the OS
      // forcibly reclaims the IME, or how we should simulate that in tests.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();

      // Ensure that the toolbar is hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
    });

    testWidgetsOnIos("toggles toolbar when tapping on caret (with hardware keyboard)", (tester) async {
      await _pumpSingleParagraphApp(tester, simulateSoftwareKeyboardAppearance: false);

      // Place the caret at the end of a word, because iOS snaps the caret
      // to word boundaries by default.
      await tester.tapInParagraph("1", 207);

      // Ensure all controls are hidden.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Tap again on the caret.
      await tester.tapInParagraph("1", 207);

      // Ensure that the toolbar is visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);

      // Tap on the caret again, to toggle the toolbar off.
      await tester.tapInParagraph("1", 207);

      // Ensure that the toolbar is hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
    });

    testWidgetsOnIos("hides toolbar when IME connection is closed (with hardware keyboard)", (tester) async {
      await _pumpSingleParagraphApp(tester, simulateSoftwareKeyboardAppearance: false);

      // Place the caret at the end of a word, because iOS snaps the caret
      // to word boundaries by default.
      await tester.tapInParagraph("1", 207);

      // Ensure all controls are hidden.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Tap again on the caret.
      await tester.tapInParagraph("1", 207);

      // Ensure that the toolbar is visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);

      // Take the IME connection away from Super Editor. The best we can do to
      // simulate this is to move the focus somewhere else. In practice, this is
      // how it actually occurs. It's not obvious under which circumstances the OS
      // forcibly reclaims the IME, or how we should simulate that in tests.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();

      // Ensure that the toolbar is hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
    });

    testWidgetsOnIos("shows magnifier when dragging the caret", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Place the caret.
      await tester.tapInParagraph("1", 200);

      // Press and drag the caret somewhere else in the paragraph.
      final gesture = await tester.tapDownInParagraph("1", 200);
      for (int i = 0; i < 5; i += 1) {
        await gesture.moveBy(const Offset(24, 0));
        await tester.pump();
      }

      // Ensure magnifier is visible and toolbar is hidden.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Resolve the gesture so that we don't have pending gesture timers.
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgetsOnIos("does not blink caret while dragging it", (tester) async {
      BlinkController.indeterminateAnimationsEnabled = true;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

      await _pumpSingleParagraphApp(tester);

      // Place the caret.
      await tester.tapInParagraph("1", 200);

      // Press and drag the caret somewhere else in the paragraph.
      final gesture = await tester.tapDownInParagraph("1", 200);
      for (int i = 0; i < 5; i += 1) {
        await gesture.moveBy(const Offset(24, 0));
        await tester.pump();
      }

      // Duration for the caret to switch between visible and invisible.
      final flashPeriod = SuperEditorInspector.caretFlashPeriod();

      // Ensure caret is visible.
      expect(SuperEditorInspector.isCaretVisible(), isTrue);

      // Trigger a frame with an ellapsed time equal to the flashPeriod,
      // so if the caret is blinking it will change from visible to invisible.
      await tester.pump(flashPeriod);

      // Ensure caret is still visible after the flash period, which means it isn't blinking.
      expect(SuperEditorInspector.isCaretVisible(), isTrue);

      // Trigger another frame.
      await tester.pump(flashPeriod);

      // Ensure caret is still visible.
      expect(SuperEditorInspector.isCaretVisible(), isTrue);

      // Resolve the gesture so that we don't have pending gesture timers.
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgetsOnIos("shows toolbar when selection is expanded", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Select a word.
      await tester.doubleTapInParagraph("1", 200);

      // Ensure toolbar is visible and magnifier is hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
    });

    testWidgetsOnIos("hides toolbar when tapping on expanded selection", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Select a word.
      await tester.doubleTapInParagraph("1", 200);

      // Ensure toolbar is visible and magnifier is hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);

      // Tap on the selected text.
      await tester.tapInParagraph("1", 200);

      // Ensure that all controls are now hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
    });

    testWidgetsOnIos("shows toolbar when long pressing on an empty paragraph and hides it after typing",
        (tester) async {
      await tester //
          .createDocument()
          .withSingleEmptyParagraph()
          .pump();

      // The decision about showing the toolbar depends on the keyboard visibility.
      // Simulate the keyboard being visible immediately after the IME is connected.
      TestSuperKeyboard.install(id: '1', vsync: tester, keyboardAnimationTime: Duration.zero);
      addTearDown(() => TestSuperKeyboard.uninstall('1'));

      // Ensure the toolbar is not visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Long press, this shouldn't show the toolbar.
      final gesture = await tester.longPressDownInParagraph('1', 0);

      // Ensure the toolbar is not visible yet.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Release the finger.
      await gesture.up();
      await tester.pump();

      // Ensure the toolbar is visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);

      // Type a character to hide the toolbar.
      await tester.typeImeText('a');

      // Ensure the toolbar is not visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
    });

    testWidgetsOnIos("does not show toolbar upon first tap", (tester) async {
      await tester //
          .createDocument()
          .withTwoEmptyParagraphs()
          .pump();

      // Place the caret at the beginning of the document.
      await tester.placeCaretInParagraph("1", 0);

      // Ensure the toolbar isn't visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Place the caret at the beginning of the second paragraph, at the same offset.
      await tester.placeCaretInParagraph("2", 0);

      // Ensure the toolbar isn't visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
    });

    testWidgetsOnIos("shows magnifier when dragging expanded handle", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Select a word.
      await tester.doubleTapInParagraph("1", 250);

      // Press and drag upstream handle
      final gesture = await tester.pressDownOnUpstreamMobileHandle();
      for (int i = 0; i < 5; i += 1) {
        await gesture.moveBy(const Offset(-24, 0));
        await tester.pump();
      }

      // Ensure that the magnifier is visible.
      expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Resolve the gesture so that we don't have pending gesture timers.
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgetsOnIos("hides expanded handles and toolbar when deleting an expanded selection", (tester) async {
      // Configure BlinkController to animate, otherwise it won't blink. We want to make sure
      // the caret blinks after deleting the content.
      BlinkController.indeterminateAnimationsEnabled = true;
      addTearDown(() => BlinkController.indeterminateAnimationsEnabled = false);

      await _pumpSingleParagraphApp(tester);

      // Double tap to select "Lorem".
      await tester.doubleTapInParagraph("1", 1);
      await tester.pump();

      // Ensure the toolbar and the drag handles are visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
      expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNWidgets(2));

      // Press backspace to delete the word "Lorem" while the expanded handles are visible.
      await tester.ime.backspace(getter: imeClientGetter);

      // Ensure the toolbar and the drag handles were hidden.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
      expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);

      // Ensure caret is blinking.

      expect(SuperEditorInspector.isCaretVisible(), true);

      // Duration to switch between visible and invisible.
      final flashPeriod = SuperEditorInspector.caretFlashPeriod();

      // Trigger a frame with an ellapsed time equal to the flashPeriod,
      // so the caret should change from visible to invisible.
      await tester.pump(flashPeriod);

      // Ensure caret is invisible after the flash period.
      expect(SuperEditorInspector.isCaretVisible(), false);

      // Trigger another frame to make caret visible again.
      await tester.pump(flashPeriod);

      // Ensure caret is visible.
      expect(SuperEditorInspector.isCaretVisible(), true);
    });

    testWidgetsOnIos("keeps current selection when tapping on caret", (tester) async {
      await _pumpSingleParagraphApp(tester);

      // Tap at "consectetur|" to place the caret.
      await tester.tapInParagraph("1", 39);

      // Ensure that the selection was placed at the end of the word.
      expect(
        SuperEditorInspector.findDocumentSelection(),
        selectionEquivalentTo(const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 39),
          ),
        )),
      );

      // Press and drag the caret to "con|sectetur" because dragging is the only way
      // we can place the caret at the middle of a word when caret snapping is enabled.
      final gesture = await tester.tapDownInParagraph("1", 39);
      for (int i = 0; i < 7; i += 1) {
        await gesture.moveBy(const Offset(-19, 0));
        await tester.pump();
      }

      // Resolve the gesture so that we don't have pending gesture timers.
      await gesture.up();
      await tester.pump(kDoubleTapTimeout);

      // Ensure that the selection moved to "con|sectetur".
      expect(
        SuperEditorInspector.findDocumentSelection(),
        selectionEquivalentTo(const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 32),
          ),
        )),
      );

      // Ensure the toolbar is not visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);

      // Tap on the caret.
      await tester.tapInParagraph("1", 32);

      // Ensure the selection was kept at "con|sectetur".
      expect(
        SuperEditorInspector.findDocumentSelection(),
        selectionEquivalentTo(const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 32),
          ),
        )),
      );

      // Ensure the toolbar is visible.
      expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
    });

    group("on device and web > shows ", () {
      testWidgetsOnIosDeviceAndWeb("caret", (tester) async {
        await _pumpSingleParagraphApp(tester);

        // Create a collapsed selection.
        await tester.tapInParagraph("1", 1);

        // Ensure we have a collapsed selection.
        expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
        expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isTrue);

        // Ensure caret (and only caret) is visible.
        expect(SuperEditorInspector.findMobileCaret(), findsOneWidget);
        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);
      });

      testWidgetsOnIosDeviceAndWeb("upstream and downstream handles", (tester) async {
        await _pumpSingleParagraphApp(tester);

        // Create an expanded selection.
        await tester.doubleTapInParagraph("1", 1);

        // Ensure we have an expanded selection.
        expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
        expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isFalse);

        // Ensure expanded handles are visible, but caret isn't.
        expect(SuperEditorInspector.findMobileCaret(), findsNothing);
        expect(SuperEditorInspector.findMobileUpstreamDragHandle(), findsOneWidget);
        expect(SuperEditorInspector.findMobileDownstreamDragHandle(), findsOneWidget);
      });
    });

    group("on device >", () {
      group("shows", () {
        testWidgetsOnIos("the magnifier", (tester) async {
          await _pumpSingleParagraphApp(tester);

          // Long press, and hold, so that the magnifier appears.
          await tester.longPressDownInParagraph("1", 1);

          // Ensure the magnifier is wanted AND visible.
          expect(SuperEditorInspector.wantsMobileMagnifierToBeVisible(), isTrue);
          expect(SuperEditorInspector.isMobileMagnifierVisible(), isTrue);
        });

        testWidgetsOnIos("the floating toolbar", (tester) async {
          await _pumpSingleParagraphApp(tester);

          // Create an expanded selection.
          await tester.doubleTapInParagraph("1", 1);

          // Ensure we have an expanded selection.
          expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
          expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isFalse);

          // Ensure that the toolbar is desired AND displayed.
          expect(SuperEditorInspector.wantsMobileToolbarToBeVisible(), isTrue);
          expect(SuperEditorInspector.isMobileToolbarVisible(), isTrue);
        });
      });
    });

    group("on web >", () {
      group("defers to browser to show", () {
        testWidgetsOnWebIos("the magnifier", (tester) async {
          await _pumpSingleParagraphApp(tester);

          // Long press, and hold, so that the magnifier appears.
          await tester.longPressDownInParagraph("1", 1);

          // Ensure the magnifier is desired, but not displayed.
          expect(SuperEditorInspector.wantsMobileMagnifierToBeVisible(), isTrue);
          expect(SuperEditorInspector.isMobileMagnifierVisible(), isFalse);
        });

        testWidgetsOnWebIos("the floating toolbar", (tester) async {
          await _pumpSingleParagraphApp(tester);

          // Create an expanded selection.
          await tester.doubleTapInParagraph("1", 1);

          // Ensure we have an expanded selection.
          expect(SuperEditorInspector.findDocumentSelection(), isNotNull);
          expect(SuperEditorInspector.findDocumentSelection()!.isCollapsed, isFalse);

          // Ensure that the toolbar is desired, but not displayed.
          expect(SuperEditorInspector.wantsMobileToolbarToBeVisible(), isTrue);
          expect(SuperEditorInspector.isMobileToolbarVisible(), isFalse);
        });
      });
    });

    group("layer lifecycle >", () {
      testWidgetsOnIos("keeps working after the app disposes and replaces the controls controller", (tester) async {
        // An app is free to own the iOS controls scope itself and hang it above SuperEditor,
        // and to *replace* the controller while the editor beneath it stays mounted - e.g.
        // rebuilding it whenever the theme's selection-handle color changes, from
        // didChangeDependencies. Everything the old controller handed out is still referenced
        // by the live editor at that instant: the handles layer's listeners on
        // shouldCaretBlink and handleBeingDragged, and the Leaders on its focal points.
        final handleColor = ValueNotifier<Color>(const Color(0xFFFF0000));
        addTearDown(handleColor.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _ThemedAppOwnedIosControlsScope(handleColor: handleColor),
            ),
          ),
        );

        // Place the caret, so the handles layer is showing a caret and its Leader.
        await tester.placeCaretInParagraph("1", 0);

        // Change the theme color. The scope disposes the old controller from
        // didChangeDependencies and rebuilds the subtree against a new one, in the same
        // frame, while the old layer still points at the old controller.
        handleColor.value = const Color(0xFF0000FF);
        await tester.pumpAndSettle();

        // Keep using the editor against the replacement controller.
        await tester.placeCaretInParagraph("1", 10);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgetsOnIos("keeps driving the floating cursor after the controls controller is replaced",
          (tester) async {
        // Same app-owned swap as above, but with the floating cursor mid-gesture, because
        // that's the only thing that writes to FloatingCursorController's notifiers - and
        // all four of them are released by FloatingCursorController.dispose().
        //
        // EditorFloatingCursor re-resolves the controls scope in didChangeDependencies, so
        // the writes that follow the swap have to land on the *incoming* controller. If any
        // of them kept a reference to the outgoing one, this test reports
        // "A ValueNotifier<Rect?> was used after being disposed." (verified by deliberately
        // caching the notifier in _updateFloatingCursorGeometryForCurrentFloatingCursorFocalPoint
        // and re-running: takeException() catches it, and the geometry below stays null).
        final handleColor = ValueNotifier<Color>(const Color(0xFFFF0000));
        addTearDown(handleColor.dispose);

        SuperEditorIosControlsController? currentController;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _ThemedAppOwnedIosControlsScope(
                handleColor: handleColor,
                onControllerCreated: (controller) => currentController = controller,
              ),
            ),
          ),
        );

        await tester.placeCaretInParagraph("1", 0);

        // Start the floating cursor and move it, so cursorGeometryInDocument holds a rect
        // and EditorFloatingCursor's ValueListenableBuilder is subscribed to it.
        await tester.startFloatingCursorGesture();
        await tester.pump();
        await tester.updateFloatingCursorGesture(const Offset(50, 0));
        await tester.pump();
        expect(currentController!.floatingCursorController.cursorGeometryInDocument.value, isNotNull);

        // Replace the controller mid-gesture. The old one - and its floating cursor
        // controller - is disposed on the spot, while the editor beneath stays mounted.
        handleColor.value = const Color(0xFF0000FF);
        await tester.pump();

        // Keep moving the floating cursor. These writes must reach the replacement.
        await tester.updateFloatingCursorGesture(const Offset(100, 0));
        await tester.pump();
        expect(currentController!.floatingCursorController.cursorGeometryInDocument.value, isNotNull);

        // And releasing it must clear the replacement's geometry, not the dead one's.
        await tester.stopFloatingCursorGesture();
        await tester.pump();
        expect(currentController!.floatingCursorController.cursorGeometryInDocument.value, isNull);

        expect(tester.takeException(), isNull);
      });
    });

    group("controller lifecycle >", () {
      test("disposes every notifier it owns, and leaves the LeaderLinks alone", () {
        final controller = SuperEditorIosControlsController();
        controller.dispose();

        // Every ValueNotifier on the controller is released, plus the floating cursor
        // controller. Each is only ever subscribed to from the build phase by a widget that
        // also removes its listener, so releasing them can't strand a live client.
        expect(() => controller.shouldCaretBlink.addListener(() {}), throwsFlutterError);
        expect(() => controller.areSelectionHandlesAllowed.addListener(() {}), throwsFlutterError);
        expect(() => controller.handleBeingDragged.addListener(() {}), throwsFlutterError);
        expect(() => controller.shouldShowMagnifier.addListener(() {}), throwsFlutterError);
        expect(() => controller.shouldShowToolbar.addListener(() {}), throwsFlutterError);

        // All four of the floating cursor controller's notifiers, not just the three it
        // used to release. cursorGeometryInDocument is written by the same method that
        // writes cursorGeometryInViewport and read by a ValueListenableBuilder inside
        // EditorFloatingCursor, which drops its listener when the controller is swapped -
        // see FloatingCursorController.dispose.
        expect(() => controller.floatingCursorController.isActive.addListener(() {}), throwsFlutterError);
        expect(() => controller.floatingCursorController.isNearText.addListener(() {}), throwsFlutterError);
        expect(
          () => controller.floatingCursorController.cursorGeometryInViewport.addListener(() {}),
          throwsFlutterError,
        );
        expect(
          () => controller.floatingCursorController.cursorGeometryInDocument.addListener(() {}),
          throwsFlutterError,
        );

        // The LeaderLinks are deliberately NOT released. A RenderLeader writes to its link
        // during layout and paint, and LeaderLink defers those notifications to a
        // post-frame callback - so a disposed link asserts after the controller is already
        // gone. See SuperEditorIosControlsController.dispose.
        expect(() => controller.magnifierFocalPoint.addListener(() {}), returnsNormally);
        expect(() => controller.toolbarFocalPoint.addListener(() {}), returnsNormally);
      });
    });
  });
}

/// Displays a [SuperEditor] beneath an app-owned [SuperEditorIosControlsScope] whose
/// controller is thrown away and rebuilt whenever the ambient handle color changes.
///
/// This is MemNote's arrangement: the controller carries a color, so a theme change means a
/// new controller, disposed and replaced from `didChangeDependencies` while the editor below
/// it stays mounted.
class _ThemedAppOwnedIosControlsScope extends StatefulWidget {
  const _ThemedAppOwnedIosControlsScope({
    required this.handleColor,
    this.onControllerCreated,
  });

  final ValueListenable<Color> handleColor;

  /// Reports each controller this scope builds, so a test can assert against whichever
  /// one is current.
  final void Function(SuperEditorIosControlsController)? onControllerCreated;

  @override
  State<_ThemedAppOwnedIosControlsScope> createState() => _ThemedAppOwnedIosControlsScopeState();
}

class _ThemedAppOwnedIosControlsScopeState extends State<_ThemedAppOwnedIosControlsScope> {
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  SuperEditorIosControlsController? _controlsController;

  @override
  void initState() {
    super.initState();

    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: singleParagraphDoc(), composer: _composer);

    widget.handleColor.addListener(_onHandleColorChange);
    _rebuildControlsController();
  }

  @override
  void dispose() {
    widget.handleColor.removeListener(_onHandleColorChange);
    _controlsController?.dispose();

    super.dispose();
  }

  void _onHandleColorChange() {
    setState(_rebuildControlsController);
  }

  void _rebuildControlsController() {
    _controlsController?.dispose();
    _controlsController = SuperEditorIosControlsController(handleColor: widget.handleColor.value);
    widget.onControllerCreated?.call(_controlsController!);
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditorIosControlsScope(
      controller: _controlsController!,
      child: SuperEditor(editor: _editor),
    );
  }
}

Future<void> _pumpSingleParagraphApp(
  WidgetTester tester, {
  bool simulateSoftwareKeyboardAppearance = true,
}) async {
  await tester
      .createDocument()
      // Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor...
      .withSingleParagraph()
      .simulateSoftwareKeyboardInsets(simulateSoftwareKeyboardAppearance)
      .useIosSelectionHeuristics(true)
      .pump();
}
