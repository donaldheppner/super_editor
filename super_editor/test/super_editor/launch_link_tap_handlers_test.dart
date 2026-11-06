import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/infrastructure/links.dart';
import 'package:super_editor/super_editor.dart';

import '../test_tools.dart';

/// The built-in launch-link handlers only treat a link's own glyphs as the
/// link — not the blank space after a link that ends a line, the padding before
/// a link that starts one, or the gap after the first visual line of a wrapped
/// link. All three used to be clickable, because the handlers resolved the
/// pointer with `getDocumentPositionNearestToOffset`, which snaps those points
/// onto the nearest caret position inside the link.
void main() {
  group('Launch link tap handlers >', () {
    late TestUrlLauncher urlLauncher;

    setUp(() {
      urlLauncher = TestUrlLauncher();
      UrlLauncher.instance = urlLauncher;
    });

    tearDown(() => UrlLauncher.instance = null);

    group('SuperEditor >', () {
      testWidgets('launches a link when tapping its text', (tester) async {
        await _pumpEditor(tester, _lineEndingLink());

        await _tapAtDocument(tester, _charRect(tester, 7).center);

        expect(urlLauncher.urlLaunchLog.map((uri) => uri.toString()), ['https://example.com']);
      });

      testWidgets('launches a link when tapping the right half of its last character', (tester) async {
        await _pumpEditor(tester, _lineEndingLink());

        final last = _charRect(tester, 10);
        await _tapAtDocument(tester, Offset(last.right - 1, last.center.dy));

        expect(urlLauncher.urlLaunchLog, hasLength(1));
      });

      testWidgets('launches a link when tapping in the leading above its glyphs', (tester) async {
        // The default stylesheet's line height is 1.4, so the line is taller
        // than the glyph box, and the whole line height over the link counts.
        await _pumpEditor(tester, _lineEndingLink());

        final line = _layout(tester).getRectForPosition(_at(7))!;
        final glyph = _charRect(tester, 7);
        expect(line.top, lessThan(glyph.top), reason: 'the fixture needs leading above the glyphs');
        await _tapAtDocument(tester, Offset(glyph.center.dx, line.top + 1));

        expect(urlLauncher.urlLaunchLog, hasLength(1));
      });

      testWidgets('does not launch a link when tapping the blank space after it', (tester) async {
        await _pumpEditor(tester, _lineEndingLink());

        final last = _charRect(tester, 10);
        await _tapAtDocument(tester, Offset(last.right + 200, last.center.dy));
        await _tapAtDocument(tester, Offset(last.right + 2, last.center.dy));

        expect(urlLauncher.urlLaunchLog, isEmpty);
      });

      testWidgets('does not launch a link when tapping the padding before it', (tester) async {
        await _pumpEditor(tester, _paragraphWithLink('example see', 0, 6));

        final first = _charRect(tester, 0);
        await _tapAtDocument(tester, Offset(first.left - 4, first.center.dy));
        expect(urlLauncher.urlLaunchLog, isEmpty);

        await _tapAtDocument(tester, first.center);
        expect(urlLauncher.urlLaunchLog, hasLength(1));
      });

      testWidgets('does not launch a wrapped link when tapping after its first visual line', (tester) async {
        // The test font draws every glyph 18px wide, so at this width a line
        // holds 25 characters: the 21-letter word fits on a line of its own but
        // cannot join "go to the ", so the link wraps after "the " and its
        // first line ends far short of the edge.
        const text = 'go to the incomprehensibilities site';
        await _pumpEditor(tester, _paragraphWithLink(text, 6, text.length - 1), width: 500);

        final the = _charRect(tester, 6);
        final incomprehensible = _charRect(tester, 10);
        expect(incomprehensible.top, greaterThan(the.bottom - 1), reason: 'the link must wrap after "the "');

        await _tapAtDocument(tester, Offset(_charRect(tester, 9).right + 100, the.center.dy));
        expect(urlLauncher.urlLaunchLog, isEmpty);

        await _tapAtDocument(tester, the.center);
        await _tapAtDocument(tester, incomprehensible.center);
        expect(urlLauncher.urlLaunchLog, hasLength(2));
      });

      testWidgets('launches a link whose text is a surrogate pair', (tester) async {
        // Half of a surrogate pair has no glyph box of its own, so the hit test
        // must measure whole grapheme clusters.
        await _pumpEditor(tester, _paragraphWithLink('see 🔗', 4, 5));

        final glyph = _layout(tester).getRectForSelection(_at(4), _at(6))!;
        await _tapAtDocument(tester, glyph.center);

        expect(urlLauncher.urlLaunchLog, hasLength(1));
      });

      testWidgets('does not launch a link outside interaction mode', (tester) async {
        await _pumpEditor(tester, _lineEndingLink(), interactionMode: false);

        await _tapAtDocument(tester, _charRect(tester, 7).center);

        expect(urlLauncher.urlLaunchLog, isEmpty);
      });

      group('hover cursor >', () {
        testWidgets('is the click cursor over the link text', (tester) async {
          await _pumpEditor(tester, _lineEndingLink());

          await _hoverAtDocument(tester, _charRect(tester, 7).center);

          expect(_activeCursor(), SystemMouseCursors.click);
        });

        testWidgets('is the text cursor over the blank space after a line-ending link', (tester) async {
          await _pumpEditor(tester, _lineEndingLink());

          final last = _charRect(tester, 10);
          await _hoverAtDocument(tester, Offset(last.right + 200, last.center.dy));

          expect(_activeCursor(), SystemMouseCursors.text);
        });

        testWidgets('follows the pointer off the link and back on', (tester) async {
          await _pumpEditor(tester, _lineEndingLink());

          final last = _charRect(tester, 10);
          final gesture = await _hoverAtDocument(tester, _charRect(tester, 7).center);
          expect(_activeCursor(), SystemMouseCursors.click);

          await gesture.moveTo(_toGlobal(tester, Offset(last.right + 200, last.center.dy)));
          await tester.pump();
          expect(_activeCursor(), SystemMouseCursors.text);

          await gesture.moveTo(_toGlobal(tester, _charRect(tester, 5).center));
          await tester.pump();
          expect(_activeCursor(), SystemMouseCursors.click);
        });

        testWidgets('is the text cursor over the link outside interaction mode', (tester) async {
          await _pumpEditor(tester, _lineEndingLink(), interactionMode: false);

          await _hoverAtDocument(tester, _charRect(tester, 7).center);

          expect(_activeCursor(), SystemMouseCursors.text);
        });
      });
    });

    group('SuperReader >', () {
      testWidgets('launches a link when tapping its text, and not the blank space after it', (tester) async {
        await _pumpReader(tester, _lineEndingLink());

        final last = _charRect(tester, 10);
        await _tapAtDocument(tester, Offset(last.right + 200, last.center.dy));
        expect(urlLauncher.urlLaunchLog, isEmpty);

        await _tapAtDocument(tester, _charRect(tester, 7).center);
        expect(urlLauncher.urlLaunchLog.map((uri) => uri.toString()), ['https://example.com']);
      });

      testWidgets('shows the click cursor only over the link text', (tester) async {
        await _pumpReader(tester, _lineEndingLink());

        final last = _charRect(tester, 10);
        final gesture = await _hoverAtDocument(tester, _charRect(tester, 7).center);
        expect(_activeCursor(), SystemMouseCursors.click);

        await gesture.moveTo(_toGlobal(tester, Offset(last.right + 200, last.center.dy)));
        await tester.pump();
        expect(_activeCursor(), SystemMouseCursors.text);
      });
    });

    group('SuperMessage >', () {
      testWidgets('launches a link when tapping its text, and not the blank space after it', (tester) async {
        await _pumpMessage(tester, _lineEndingLink());

        final last = _charRect(tester, 10);
        await _tapAtDocument(tester, Offset(last.right + 200, last.center.dy));
        expect(urlLauncher.urlLaunchLog, isEmpty);

        await _tapAtDocument(tester, _charRect(tester, 7).center);
        expect(urlLauncher.urlLaunchLog.map((uri) => uri.toString()), ['https://example.com']);
      });

      testWidgets('shows the click cursor only over the link text', (tester) async {
        await _pumpMessage(tester, _lineEndingLink());

        final last = _charRect(tester, 10);
        final gesture = await _hoverAtDocument(tester, _charRect(tester, 7).center);
        expect(_activeCursor(), SystemMouseCursors.click);

        await gesture.moveTo(_toGlobal(tester, Offset(last.right + 200, last.center.dy)));
        await tester.pump();
        expect(_activeCursor(), SystemMouseCursors.text);
      });
    });
  });

  group('ContentTapDelegate hover cursor >', () {
    testWidgets('still asks a delegate that only overrides mouseCursorForContentHover', (tester) async {
      final delegate = _LegacyHoverDelegate();
      await _pumpEditor(tester, _lineEndingLink(), delegate: delegate);

      final last = _charRect(tester, 10);
      await _hoverAtDocument(tester, Offset(last.right + 200, last.center.dy));

      // The legacy callback still receives the snapped position: the caret at
      // the end of the line, even though the pointer is far to its right.
      expect(_activeCursor(), SystemMouseCursors.grab);
      expect(delegate.hoverPositions.last.nodeId, 'p1');
      expect(_textOffset(delegate.hoverPositions.last), 11);
    });

    testWidgets('hands mouseCursorForHover the pointer offset along with the nearest position', (tester) async {
      final delegate = _OffsetHoverDelegate();
      await _pumpEditor(tester, _lineEndingLink(), delegate: delegate);

      final last = _charRect(tester, 10);
      final pointer = Offset(last.right + 200, last.center.dy);
      await _hoverAtDocument(tester, pointer);

      final details = delegate.hovers.last;
      expect(details.layoutOffset.dx, moreOrLessEquals(pointer.dx));
      expect(details.layoutOffset.dy, moreOrLessEquals(pointer.dy));
      expect(details.globalOffset, _toGlobal(tester, pointer));
      expect(details.documentPosition.nodeId, 'p1');
      expect(_textOffset(details.documentPosition), 11);
      expect(identical(details.documentLayout, _layout(tester)), isTrue);
    });
  });

  group('getCharacterSelectionUnderOffset >', () {
    testWidgets('selects the character under the point', (tester) async {
      await _pumpReader(tester, _lineEndingLink());

      final selection = _characterAt(tester, _charRect(tester, 7).center);

      expect(selection, DocumentSelection(base: _at(7), extent: _at(8)));
    });

    testWidgets('selects a whole grapheme cluster', (tester) async {
      await _pumpReader(tester, _paragraphWithLink('see 🔗', 4, 5));

      final glyph = _layout(tester).getRectForSelection(_at(4), _at(6))!;

      expect(_characterAt(tester, glyph.center), DocumentSelection(base: _at(4), extent: _at(6)));
    });

    testWidgets('returns null for the blank space after a line and the padding before it', (tester) async {
      await _pumpReader(tester, _lineEndingLink());

      final first = _charRect(tester, 0);
      final last = _charRect(tester, 10);

      expect(_characterAt(tester, Offset(last.right + 2, last.center.dy)), isNull);
      expect(_characterAt(tester, Offset(first.left - 4, first.center.dy)), isNull);
    });

    testWidgets('returns null below the line', (tester) async {
      await _pumpReader(tester, _lineEndingLink());

      final line = _layout(tester).getRectForPosition(_at(7))!;

      expect(_characterAt(tester, Offset(_charRect(tester, 7).center.dx, line.bottom + 2)), isNull);
    });
  });
}

/// "see example", with "example" (offsets 4 to 10) linked — the last thing on its line.
ParagraphNode _lineEndingLink() => _paragraphWithLink('see example', 4, 10);

ParagraphNode _paragraphWithLink(String text, int start, int endInclusive) {
  final attributed = AttributedText(text);
  attributed.addAttribution(const LinkAttribution('https://example.com'), SpanRange(start, endInclusive));
  return ParagraphNode(id: 'p1', text: attributed);
}

DocumentPosition _at(int offset) => DocumentPosition(
      nodeId: 'p1',
      nodePosition: TextNodePosition(offset: offset),
    );

DocumentLayout _layout(WidgetTester tester) => tester.state(find.byType(SingleColumnDocumentLayout)) as DocumentLayout;

/// The document most recently pumped by one of the `_pump*` functions.
Document? _pumpedDocument;

int _textOffset(DocumentPosition position) => (position.nodePosition as TextNodePosition).offset;

/// Layout-space rect of the single character at [offset] in node `p1`.
Rect _charRect(WidgetTester tester, int offset) => _layout(tester).getRectForSelection(_at(offset), _at(offset + 1))!;

Offset _toGlobal(WidgetTester tester, Offset layoutOffset) =>
    _layout(tester).getGlobalOffsetFromDocumentOffset(layoutOffset);

DocumentSelection? _characterAt(WidgetTester tester, Offset layoutOffset) => getCharacterSelectionUnderOffset(
      document: _pumpedDocument!,
      docLayout: _layout(tester),
      layoutOffset: layoutOffset,
    );

Future<void> _tapAtDocument(WidgetTester tester, Offset layoutOffset) async {
  await tester.tapAt(_toGlobal(tester, layoutOffset));
  // Past the double-tap timeout, so a single tap is fully resolved.
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
}

Future<TestGesture> _hoverAtDocument(WidgetTester tester, Offset layoutOffset) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(_toGlobal(tester, layoutOffset));
  await tester.pump();
  return gesture;
}

MouseCursor? _activeCursor() => RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);

Widget _frame(Widget child, {double width = 800}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

Future<void> _pumpEditor(
  WidgetTester tester,
  ParagraphNode paragraph, {
  double width = 800,
  bool interactionMode = true,
  ContentTapDelegate? delegate,
}) async {
  final document = MutableDocument(nodes: [paragraph]);
  _pumpedDocument = document;
  final composer = MutableDocumentComposer();
  final editor = createDefaultDocumentEditor(document: document, composer: composer);
  if (interactionMode) {
    editor.execute([const ChangeInteractionModeRequest(isInteractionModeDesired: true)]);
  }

  await tester.pumpWidget(
    _frame(
      SuperEditor(
        editor: editor,
        gestureMode: DocumentGestureMode.mouse,
        contentTapDelegateFactories: [
          if (delegate != null) (_) => delegate else superEditorLaunchLinkTapHandlerFactory,
        ],
      ),
      width: width,
    ),
  );
  await tester.pump();
}

Future<void> _pumpReader(WidgetTester tester, ParagraphNode paragraph) async {
  final document = MutableDocument(nodes: [paragraph]);
  _pumpedDocument = document;
  final editor = createDefaultDocumentEditor(document: document, composer: MutableDocumentComposer());

  await tester.pumpWidget(
    _frame(
      SuperReader(
        editor: editor,
        gestureMode: DocumentGestureMode.mouse,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpMessage(WidgetTester tester, ParagraphNode paragraph) async {
  final document = MutableDocument(nodes: [paragraph]);
  _pumpedDocument = document;

  await tester.pumpWidget(
    _frame(
      SuperMessage(
        editor: createDefaultAiMessageEditor(document: document),
        gestureMode: DocumentGestureMode.mouse,
      ),
    ),
  );
  await tester.pump();
}

/// Overrides only the original, position-only hover callback.
class _LegacyHoverDelegate extends ContentTapDelegate {
  final hoverPositions = <DocumentPosition>[];

  @override
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) {
    hoverPositions.add(hoverPosition);
    return SystemMouseCursors.grab;
  }
}

/// Overrides the hover callback that receives the pointer offset.
class _OffsetHoverDelegate extends ContentTapDelegate {
  final hovers = <DocumentHoverDetails>[];

  @override
  MouseCursor? mouseCursorForHover(DocumentHoverDetails details) {
    hovers.add(details);
    return null;
  }
}
