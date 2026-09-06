import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

/// Tab arriving as an IME text delta, rather than as a key event.
///
/// `TextDeltasDocumentEditor` turns a `\t` delta into a list-item indent. That used to be
/// gated on iOS, so the same delta indented a bullet on an iPad and typed a tab character
/// into it everywhere else. The gate is gone; what stayed platform-specific is only what
/// happens when the indent is *refused* — see `_applyTabDelta` for why.
///
/// These tests pin both halves: the indent, on every platform, and the refusal, per
/// platform. The refusal cases are the regression net — they are what proves this change
/// added an indent off iOS without moving anything else on any platform.
void main() {
  group('IME input > tab >', () {
    group('insertion delta >', () {
      testWidgetsOnAllPlatforms('indents a list item that can nest', (tester) async {
        final context = await _pumpTwoListItems(tester);

        // The second bullet has a bullet above it, so it may nest under it.
        await tester.placeCaretInParagraph('2', 0);
        await tester.typeImeText('\t');

        expect(context.document.getNodeById('2')!.asListItem.indent, 1);
        // The tab indented the item; it must not also land in the item's text.
        expect(SuperEditorInspector.findTextInComponent('2').toPlainText(), 'List item 2');
      });

      testWidgetsOnIos('is swallowed in a paragraph', (tester) async {
        await _pumpParagraph(tester);

        await tester.placeCaretInParagraph('1', 0);
        await tester.typeImeText('\t');

        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), 'A paragraph.');
      });

      testWidgetsOnAndroid('types a tab character in a paragraph', (tester) async {
        await _pumpParagraph(tester);

        await tester.placeCaretInParagraph('1', 0);
        await tester.typeImeText('\t');

        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), '\tA paragraph.');
      });

      testWidgetsOnIos('is swallowed on a list item that has nothing to nest under', (tester) async {
        final context = await _pumpTwoListItems(tester);

        // The first bullet of a run can never indent (`canIndentListItem`).
        await tester.placeCaretInParagraph('1', 0);
        await tester.typeImeText('\t');

        expect(context.document.getNodeById('1')!.asListItem.indent, 0);
        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), 'List item 1');
      });

      testWidgetsOnAndroid('types a tab character on a list item that has nothing to nest under', (tester) async {
        final context = await _pumpTwoListItems(tester);

        await tester.placeCaretInParagraph('1', 0);
        await tester.typeImeText('\t');

        expect(context.document.getNodeById('1')!.asListItem.indent, 0);
        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), '\tList item 1');
      });
    });

    group('replacement delta >', () {
      testWidgetsOnAllPlatforms('indents a list item that can nest', (tester) async {
        final context = await _pumpTwoListItems(tester);

        await tester.placeCaretInParagraph('2', 0);
        await _sendTabReplacing(tester, 'List');

        expect(context.document.getNodeById('2')!.asListItem.indent, 1);
        expect(SuperEditorInspector.findTextInComponent('2').toPlainText(), 'List item 2');
      });

      testWidgetsOnIos('is swallowed in a paragraph', (tester) async {
        await _pumpParagraph(tester);

        await tester.placeCaretInParagraph('1', 0);
        await _sendTabReplacing(tester, 'A');

        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), 'A paragraph.');
      });

      testWidgetsOnAndroid('replaces the selection with a tab character in a paragraph', (tester) async {
        await _pumpParagraph(tester);

        await tester.placeCaretInParagraph('1', 0);
        await _sendTabReplacing(tester, 'A');

        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), '\t paragraph.');
      });

      testWidgetsOnIos('is swallowed on a list item that has nothing to nest under', (tester) async {
        final context = await _pumpTwoListItems(tester);

        await tester.placeCaretInParagraph('1', 0);
        await _sendTabReplacing(tester, 'List');

        expect(context.document.getNodeById('1')!.asListItem.indent, 0);
        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), 'List item 1');
      });
    });
  });
}

Future<TestDocumentContext> _pumpTwoListItems(WidgetTester tester) {
  // Built from nodes rather than markdown so the indents are stated outright.
  return tester
      .createDocument()
      .withCustomContent(
        MutableDocument(
          nodes: [
            ListItemNode.unordered(id: '1', text: AttributedText('List item 1')),
            ListItemNode.unordered(id: '2', text: AttributedText('List item 2')),
          ],
        ),
      )
      .withInputSource(TextInputSource.ime)
      .pump();
}

Future<TestDocumentContext> _pumpParagraph(WidgetTester tester) {
  return tester
      .createDocument()
      .withCustomContent(
        MutableDocument(
          nodes: [
            ParagraphNode(id: '1', text: AttributedText('A paragraph.')),
          ],
        ),
      )
      .withInputSource(TextInputSource.ime)
      .pump();
}

/// Sends the delta shape a Tab takes when it arrives over an expanded selection: a
/// replacement of [word] with `"\t"`.
///
/// The replaced range is located in the IME's own current value rather than written out by
/// hand, because the serialization prepends invisible characters in some selection states
/// and the offsets have to agree with whatever it actually sent.
Future<void> _sendTabReplacing(WidgetTester tester, String word) async {
  final imeValue = imeClientGetter().currentTextEditingValue!;
  final start = imeValue.text.indexOf(word);
  expect(start, isNonNegative, reason: 'Expected "$word" in the IME value "${imeValue.text}"');

  await tester.ime.sendDeltas(
    [
      TextEditingDeltaReplacement(
        oldText: imeValue.text,
        replacementText: '\t',
        replacedRange: TextRange(start: start, end: start + word.length),
        selection: TextSelection.collapsed(offset: start + 1),
        composing: const TextRange(start: -1, end: -1),
      ),
    ],
    getter: imeClientGetter,
  );
}
