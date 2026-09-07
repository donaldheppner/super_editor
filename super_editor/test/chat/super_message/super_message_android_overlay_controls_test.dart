import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/test/flutter_extensions/test_documents.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group("Chat > SuperMessage > Android > overlay controls >", () {
    group("selection handles allowed >", () {
      // SuperMessage splits an Android handle the same way SuperEditor does, and had the same
      // gap until MemNote NOTE-176: SuperMessageAndroidHandlesDocumentLayer reads (and listens
      // to) areSelectionHandlesAllowed, but all it can do with it is stop building its Leaders,
      // and SuperMessageAndroidControlsOverlayManager - which builds the handle widgets - never
      // consulted the notifier at all. A message has no collapsed handle, so only the expanded
      // pair is at stake here.

      testWidgetsOnAndroid("hides the expanded handles with no other trigger", (tester) async {
        final controlsController = SuperMessageAndroidControlsController();
        addTearDown(controlsController.dispose);
        await _pumpAppOwnedControls(tester, controlsController);

        await tester.doubleTapInParagraph("1", 0);
        await tester.pump();
        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsExactly(2));

        controlsController.preventSelectionHandles();
        await tester.pump();

        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);
      });

      testWidgetsOnAndroid("brings the expanded handles back with no other trigger", (tester) async {
        final controlsController = SuperMessageAndroidControlsController();
        addTearDown(controlsController.dispose);
        await _pumpAppOwnedControls(tester, controlsController);

        await tester.doubleTapInParagraph("1", 0);
        await tester.pump();

        controlsController.preventSelectionHandles();
        await tester.pump();
        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);

        controlsController.allowSelectionHandles();
        await tester.pump();

        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsExactly(2));
      });

      testWidgetsOnAndroid("hides handles built by a client's expandedHandlesBuilder", (tester) async {
        // The case the Leaders don't cover. Measured against unpatched code: two handles, both
        // hit-testable, before *and* after preventSelectionHandles().
        final controlsController = SuperMessageAndroidControlsController(
          expandedHandlesBuilder: (
            context, {
            required upstreamHandleKey,
            required upstreamFocalPoint,
            required upstreamGestureDelegate,
            required downstreamHandleKey,
            required downstreamFocalPoint,
            required downstreamGestureDelegate,
            required shouldShow,
          }) {
            if (!shouldShow) {
              return const SizedBox();
            }

            // Deliberately not Followers: handles painted at a fixed spot, which is what makes
            // this test see the notifier rather than the Leaders.
            return Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 10,
                  child: SizedBox(
                    key: upstreamHandleKey,
                    width: 20,
                    height: 20,
                    child: const ColoredBox(color: Color(0xFFFF0000)),
                  ),
                ),
                Positioned(
                  left: 40,
                  top: 10,
                  child: SizedBox(
                    key: downstreamHandleKey,
                    width: 20,
                    height: 20,
                    child: const ColoredBox(color: Color(0xFF00FF00)),
                  ),
                ),
              ],
            );
          },
        );
        addTearDown(controlsController.dispose);
        await _pumpAppOwnedControls(tester, controlsController);

        await tester.doubleTapInParagraph("1", 0);
        await tester.pump();
        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsExactly(2));
        expect(SuperEditorInspector.findMobileExpandedDragHandles().hitTestable(), findsExactly(2));

        controlsController.preventSelectionHandles();
        await tester.pump();

        expect(SuperEditorInspector.findMobileExpandedDragHandles(), findsNothing);
      });
    });
  });
}

/// Pumps a [SuperMessage] beneath an app-owned [SuperMessageAndroidControlsScope], so a test can
/// drive the very controller the message's layer and overlay resolve.
///
/// [SuperMessageAndroidControlsScope.rootOf] takes the root-most scope, so hanging the scope above
/// [SuperMessage] is what makes [controlsController] the one that matters.
Future<void> _pumpAppOwnedControls(
  WidgetTester tester,
  SuperMessageAndroidControlsController controlsController,
) async {
  final editor = createDefaultAiMessageEditor(document: singleParagraphDoc());

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              SuperMessageAndroidControlsScope(
                controller: controlsController,
                child: SuperMessage(editor: editor),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
