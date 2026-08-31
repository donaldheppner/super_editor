import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../../../test_runners.dart';

void main() {
  group('IME input > typing >', () {
    group('types characters >', () {
      testWidgetsOnAllPlatforms('at the beginning of existing text', (tester) async {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText("<- text here")),
          ],
        );

        await tester //
            .createDocument()
            .withCustomContent(document)
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place caret at the beginning of the paragraph content.
        await tester.placeCaretInParagraph("1", 0);

        // Type some text.
        await tester.typeImeText("Hello");

        // Ensure the text was typed.
        expect((document.first as ParagraphNode).text.toPlainText(), "Hello<- text here");
      });

      testWidgetsOnAllPlatforms('in the middle of existing text', (tester) async {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText("text here -><---")),
          ],
        );

        await tester //
            .createDocument()
            .withCustomContent(document)
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place caret at the beginning of the paragraph content.
        await tester.placeCaretInParagraph("1", 12);

        // Type some text.
        await tester.typeImeText("Hello");

        // Ensure the text was typed.
        expect((document.first as ParagraphNode).text.toPlainText(), "text here ->Hello<---");
      });

      testWidgetsOnAllPlatforms('at the end of existing text', (tester) async {
        final document = MutableDocument(
          nodes: [
            ParagraphNode(id: "1", text: AttributedText("text here ->")),
          ],
        );

        await tester //
            .createDocument()
            .withCustomContent(document)
            .withInputSource(TextInputSource.ime)
            .pump();

        // Place caret at the beginning of the paragraph content.
        await tester.placeCaretInParagraph("1", 12);

        // Type some text.
        await tester.typeImeText("Hello");

        // Ensure the text was typed.
        expect((document.first as ParagraphNode).text.toPlainText(), "text here ->Hello");
      });

      test('can handle an auto-inserted period', () {
        // On iOS, adding 2 spaces causes the two spaces to be replaced by a
        // period and a space. This test applies the same type and order of deltas
        // that were observed on iOS.
        //
        // Previously, we had a bug where the period was appearing after the
        // 2nd space, instead of between the two spaces. This test prevents
        // that regression.
        final document = MutableDocument(nodes: [
          ParagraphNode(
            id: "1",
            text: AttributedText("This is a sentence"),
          ),
        ]);
        final composer = MutableDocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 18),
            ),
          ),
        );
        final editor = createDefaultDocumentEditor(document: document, composer: composer);
        final commonOps = CommonEditorOperations(
          editor: editor,
          document: document,
          composer: composer,
          documentLayoutResolver: () => FakeDocumentLayout(),
        );
        final softwareKeyboardHandler = TextDeltasDocumentEditor(
          editor: editor,
          document: document,
          documentLayoutResolver: () => FakeDocumentLayout(),
          selection: composer.selectionNotifier,
          composerPreferences: composer.preferences,
          composingRegion: composer.composingRegion,
          commonOps: commonOps,
          onPerformAction: (_) {},
        );

        softwareKeyboardHandler.applyDeltas([
          const TextEditingDeltaInsertion(
            textInserted: ' ',
            insertionOffset: 20,
            selection: TextSelection.collapsed(offset: 21),
            composing: TextRange(start: -1, end: -1),
            oldText: '. This is a sentence',
          ),
        ]);
        softwareKeyboardHandler.applyDeltas([
          const TextEditingDeltaReplacement(
            oldText: '. This is a sentence ',
            replacementText: '.',
            replacedRange: TextRange(start: 20, end: 21),
            selection: TextSelection.collapsed(offset: 21),
            composing: TextRange(start: -1, end: -1),
          ),
        ]);
        softwareKeyboardHandler.applyDeltas([
          const TextEditingDeltaInsertion(
            textInserted: ' ',
            insertionOffset: 21,
            selection: TextSelection.collapsed(offset: 22),
            composing: TextRange(start: -1, end: -1),
            oldText: '. This is a sentence.',
          ),
        ]);

        expect((document.first as ParagraphNode).text.toPlainText(), "This is a sentence. ");
      });

      testWidgets('can type compound character in an empty paragraph', (tester) async {
        final editContext = await tester //
            .createDocument()
            .withTwoEmptyParagraphs()
            .withInputSource(TextInputSource.ime)
            .withGestureMode(DocumentGestureMode.mouse)
            .autoFocus(true)
            .pump();

        // Start the caret in the 2nd paragraph so that we send a
        // hidden placeholder to the IME to report backspaces.
        await tester.placeCaretInParagraph("2", 0);

        // Send the deltas that should produce a ü.
        //
        // We have to use implementation details to send the simulated IME deltas
        // because Flutter doesn't have any testing tools for IME deltas.
        final imeInteractor = find.byType(SuperEditorImeInteractor).evaluate().first;
        final deltaClient = ((imeInteractor as StatefulElement).state as ImeInputOwner).imeClient;

        // Ensure that the delta client starts with the expected invisible placeholder
        // characters.
        expect(deltaClient.currentTextEditingValue!.text, ". ");
        expect(deltaClient.currentTextEditingValue!.selection, const TextSelection.collapsed(offset: 2));
        expect(deltaClient.currentTextEditingValue!.composing, const TextRange(start: -1, end: -1));

        // Insert the "opt+u" character.
        deltaClient.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: ". ",
            textInserted: "¨",
            insertionOffset: 2,
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 2, end: 3),
          ),
        ]);
        await tester.pumpAndSettle();

        // Ensure that the empty paragraph now reads "¨".
        expect((editContext.document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "¨");

        // Ensure that the IME still has the invisible characters.
        expect(deltaClient.currentTextEditingValue!.text, ". ¨");
        expect(deltaClient.currentTextEditingValue!.composing, const TextRange(start: 2, end: 3));

        // Insert the "u" character to create the compound character.
        deltaClient.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: ". ¨",
            replacementText: "ü",
            replacedRange: TextRange(start: 2, end: 3),
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: -1, end: -1),
          ),
        ]);

        // We need a final pump and settle to propagate selection changes while we still
        // have access to the document layout. Otherwise, the selection change callback
        // will execute after the end of this test, and the layout isn't available any
        // more.
        // TODO: trace the selection change call stack and adjust it so that we don't need this pump
        await tester.pumpAndSettle();

        // Ensure that the empty paragraph now reads "ü".
        expect((editContext.document.getNodeAt(1)! as ParagraphNode).text.toPlainText(), "ü");
      });
    });

    group('deletion >', () {
      testWidgetsOnWebDesktop('merges paragraphs backspace at the beginning of a paragraph', (tester) async {
        await tester //
            .createDocument()
            .fromMarkdown('''
Paragraph one

Paragraph two
''')
            .withInputSource(TextInputSource.ime)
            .pump();

        final doc = SuperEditorInspector.findDocument()!;

        // Place caret at the start of the second paragraph.
        await tester.placeCaretInParagraph(doc.getNodeAt(1)!.id, 0);

        // Simulates the user pressing BACKSPACE, which generates a deletion delta.
        // This deletion will cause the two paragraphs to be merged.
        await tester.ime.sendDeltas(
          const [
            TextEditingDeltaNonTextUpdate(
              oldText: '. Paragraph two',
              selection: TextSelection.collapsed(offset: 2),
              composing: TextRange(start: -1, end: -1),
            ),
            TextEditingDeltaDeletion(
              oldText: '. Paragraph two',
              deletedRange: TextRange(start: 1, end: 2),
              selection: TextSelection.collapsed(offset: 1),
              composing: TextRange(start: -1, end: -1),
            ),
          ],
          getter: imeClientGetter,
        );

        // Ensure the paragraph was merged.
        expect(
          (doc.getNodeAt(0)! as ParagraphNode).text.toPlainText(),
          'Paragraph oneParagraph two',
        );
      });
    });

    group('after an exception while applying deltas >', () {
      testWidgetsOnAllPlatforms('the IME is re-synced and the next keystroke still lands', (tester) async {
        // `DocumentImeInputClient` raises `_isApplyingDeltas` while it hands a batch of deltas
        // to `TextDeltasDocumentEditor`, and lowers it afterwards. That flag gates every path
        // that re-syncs the IME with our document. If applying the deltas throws - and
        // `applyDeltas()` deliberately rethrows unknown errors - the flag used to stay raised
        // forever, and the client could never push our document to the IME again. The editor
        // kept running, but our document and the platform IME drifted apart with no way back.
        //
        // Send a batch where the first delta applies and the second one blows up, then check
        // that the client still re-synced, and that the next keystroke lands where the user
        // expects instead of at a stale IME offset.

        await tester //
            .createDocument()
            .withSingleEmptyParagraph()
            .withInputSource(TextInputSource.ime)
            .withAddedRequestHandlers([
              (editor, request) {
                if (request is InsertTextRequest && request.textToInsert == _explodingText) {
                  throw _DeltaApplicationException();
                }
                return null;
              },
            ])
            .pump();

        await tester.placeCaretInParagraph('1', 0);
        await tester.typeImeText('Hello');

        // Grab the IME's view of the world before the doomed batch. We read the offsets from
        // the client instead of hard-coding them, because the serialization may or may not
        // carry an invisible prefix, depending on the platform and the caret position.
        final imeClient = imeClientGetter();
        final imeValueBeforeBatch = imeClient.currentTextEditingValue!;
        final caretBeforeBatch = imeValueBeforeBatch.selection.baseOffset;

        Object? thrownError;
        try {
          await tester.ime.sendDeltas(
            [
              // This delta applies cleanly.
              TextEditingDeltaInsertion(
                oldText: imeValueBeforeBatch.text,
                textInserted: ' World',
                insertionOffset: caretBeforeBatch,
                selection: TextSelection.collapsed(offset: caretBeforeBatch + 6),
                composing: TextRange.empty,
              ),
              // This one throws from inside the delta loop.
              TextEditingDeltaInsertion(
                oldText: '${imeValueBeforeBatch.text} World',
                textInserted: _explodingText,
                insertionOffset: caretBeforeBatch + 6,
                selection: TextSelection.collapsed(offset: caretBeforeBatch + 7),
                composing: TextRange.empty,
              ),
            ],
            getter: imeClientGetter,
          );
        } catch (error) {
          thrownError = error;
        }
        await tester.pump();

        // Ensure the exception wasn't swallowed. `applyDeltas()` rethrows unknown errors on
        // purpose, so that apps can report them, and the recovery must not change that.
        expect(thrownError, isA<_DeltaApplicationException>());

        // Ensure the first delta landed and the exploding one didn't.
        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), 'Hello World');

        // Ensure the client re-synced the IME with our document, despite the exception.
        expect(imeClient.currentTextEditingValue!.text, endsWith('Hello World'));

        // Ensure the very next keystroke lands at the caret, rather than at whatever offset
        // the IME was stuck at when the exception was thrown.
        await tester.typeImeText('!');
        expect(SuperEditorInspector.findTextInComponent('1').toPlainText(), 'Hello World!');
      });

      test('the original error survives a recovery that also throws', () {
        // The re-sync above runs while the exception from `applyDeltas()` is unwinding. If the
        // re-sync throws too, Dart replaces the in-flight exception with the new one, and the
        // error that `applyDeltas()` deliberately rethrew - the one the app reports - is lost.
        // The recovery must never displace a real error.
        //
        // This isn't hypothetical on this path: a batch that fails part way through can leave
        // the selection pointing at content the document no longer has, and serializing that
        // selection for the IME throws.

        final document = MutableDocument(nodes: [
          ParagraphNode(id: "1", text: AttributedText("Hello")),
        ]);
        const validSelection = DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 5)),
        );
        final composer = MutableDocumentComposer(initialSelection: validSelection);
        final editor = createDefaultDocumentEditor(document: document, composer: composer);

        // The client and the delta editor share these notifiers. `_sendDocumentToIme()`
        // serializes whatever the selection notifier holds, so driving it directly is how this
        // test puts the client into the state that a half-applied batch would leave behind.
        final selection = ValueNotifier<DocumentSelection?>(validSelection);
        final composingRegion = ValueNotifier<DocumentRange?>(null);

        var shouldExplode = true;
        final deltasDocumentEditor = _ExplodingDeltasDocumentEditor(
          editor: editor,
          document: document,
          documentLayoutResolver: () => FakeDocumentLayout(),
          selection: selection,
          composerPreferences: composer.preferences,
          composingRegion: composingRegion,
          commonOps: CommonEditorOperations(
            editor: editor,
            document: document,
            composer: composer,
            documentLayoutResolver: () => FakeDocumentLayout(),
          ),
          onPerformAction: (_) {},
          onApplyDeltas: () {
            if (!shouldExplode) {
              return;
            }

            // Leave the selection pointing at a node that the document doesn't have - the way
            // a batch that removed content and then failed would - and then fail. Serializing
            // this selection for the IME throws, which is what makes the recovery throw.
            selection.value = const DocumentSelection.collapsed(
              position: DocumentPosition(nodeId: "no-such-node", nodePosition: TextNodePosition(offset: 0)),
            );
            throw _DeltaApplicationException();
          },
        );

        final imeClient = DocumentImeInputClient(
          selection: selection,
          composingRegion: composingRegion,
          textDeltasDocumentEditor: deltasDocumentEditor,
          imeConnection: ValueNotifier(null),
          onPerformSelector: (_) {},
          onImeConnectionClosed: () {},
        );
        addTearDown(imeClient.dispose);

        // The client hasn't sent anything to the IME yet.
        expect(imeClient.currentTextEditingValue, const TextEditingValue());

        Object? thrownError;
        try {
          imeClient.updateEditingValueWithDeltas(const [
            TextEditingDeltaInsertion(
              oldText: ". Hello",
              textInserted: "!",
              insertionOffset: 7,
              selection: TextSelection.collapsed(offset: 8),
              composing: TextRange.empty,
            ),
          ]);
        } catch (error) {
          thrownError = error;
        }

        // The caller must see the delta error, not the recovery's error.
        expect(thrownError, isA<_DeltaApplicationException>());

        // Confirm the recovery really did fail, so this test can't quietly pass by never
        // exercising the window where one error can displace another. If the re-sync had
        // succeeded, it would have pushed a value to the IME.
        expect(imeClient.currentTextEditingValue, const TextEditingValue());

        // Put the selection back where a real recovery would leave it, then send a batch that
        // succeeds. This only reaches the IME if `_isApplyingDeltas` and `_isSendingToIme` were
        // both cleared - either one still raised makes `_sendDocumentToIme()` return at its
        // guard, and the IME value would stay empty.
        selection.value = validSelection;
        shouldExplode = false;
        imeClient.updateEditingValueWithDeltas(const [
          TextEditingDeltaNonTextUpdate(
            oldText: ". Hello",
            selection: TextSelection.collapsed(offset: 7),
            composing: TextRange.empty,
          ),
        ]);

        expect(imeClient.currentTextEditingValue.text, ". Hello");
      });
    });
  });
}

/// A [TextDeltasDocumentEditor] that hands control of `applyDeltas` to the test, so that a batch
/// can fail, and choose what state it leaves behind when it does.
class _ExplodingDeltasDocumentEditor extends TextDeltasDocumentEditor {
  _ExplodingDeltasDocumentEditor({
    required super.editor,
    required super.document,
    required super.documentLayoutResolver,
    required super.selection,
    required super.composerPreferences,
    required super.composingRegion,
    required super.commonOps,
    required super.onPerformAction,
    required this.onApplyDeltas,
  });

  /// Runs in place of the real delta loop.
  final VoidCallback onApplyDeltas;

  @override
  void applyDeltas(List<TextEditingDelta> textEditingDeltas) => onApplyDeltas();
}

/// Text that a test [EditRequestHandler] refuses to insert, by throwing.
const _explodingText = '<boom>';

/// The exception thrown when a test tries to insert [_explodingText].
class _DeltaApplicationException implements Exception {}
