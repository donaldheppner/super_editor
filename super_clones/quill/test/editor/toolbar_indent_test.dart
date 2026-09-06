import 'package:feather/editor/toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

/// Tests for the enabled/disabled state of the Feather toolbar's indent and
/// un-indent buttons.
///
/// The editor's indent commands each enforce a structural rule and return
/// without doing anything when the rule isn't met. The toolbar dispatches those
/// requests directly, so unless it asks the same question the commands ask, a
/// refused indent shows up as a button that does nothing at all. These tests
/// pin down that the toolbar asks.
void main() {
  group("Feather toolbar > indent button >", () {
    testWidgets("is disabled for a list item with no list item above it", (tester) async {
      final editor = _createEditor([
        ListItemNode.unordered(id: "1", text: AttributedText("first")),
        ListItemNode.unordered(id: "2", text: AttributedText("second")),
      ]);

      await _pumpToolbar(tester, editor);
      _placeCaretIn(editor, "1");
      await tester.pump();

      expect(_isEnabled(tester, Icons.format_indent_increase), isFalse);
    });

    testWidgets("is enabled for a list item that sits under another list item", (tester) async {
      final editor = _createEditor([
        ListItemNode.unordered(id: "1", text: AttributedText("first")),
        ListItemNode.unordered(id: "2", text: AttributedText("second")),
      ]);

      await _pumpToolbar(tester, editor);
      _placeCaretIn(editor, "2");
      await tester.pump();

      expect(_isEnabled(tester, Icons.format_indent_increase), isTrue);
    });

    testWidgets("indents a list item, then disables itself at the new depth", (tester) async {
      final editor = _createEditor([
        ListItemNode.unordered(id: "1", text: AttributedText("first")),
        ListItemNode.unordered(id: "2", text: AttributedText("second")),
      ]);

      await _pumpToolbar(tester, editor);
      _placeCaretIn(editor, "2");
      await tester.pump();

      await tester.tap(find.byIcon(Icons.format_indent_increase));
      await tester.pump();

      // The item moved one level in, which is as deep as the item above allows,
      // so the button that just worked is now disabled instead of being a
      // silent no-op.
      expect((editor.document.getNodeById("2") as ListItemNode).indent, 1);
      expect(_isEnabled(tester, Icons.format_indent_increase), isFalse);
    });

    testWidgets("is disabled for a task with no task above it", (tester) async {
      final editor = _createEditor([
        TaskNode(id: "1", text: AttributedText("first"), isComplete: false),
        TaskNode(id: "2", text: AttributedText("second"), isComplete: false),
      ]);

      await _pumpToolbar(tester, editor);
      _placeCaretIn(editor, "1");
      await tester.pump();

      expect(_isEnabled(tester, Icons.format_indent_increase), isFalse);
    });

    testWidgets("is enabled for a task that sits under another task", (tester) async {
      final editor = _createEditor([
        TaskNode(id: "1", text: AttributedText("first"), isComplete: false),
        TaskNode(id: "2", text: AttributedText("second"), isComplete: false),
      ]);

      await _pumpToolbar(tester, editor);
      _placeCaretIn(editor, "2");
      await tester.pump();

      expect(_isEnabled(tester, Icons.format_indent_increase), isTrue);
    });

    testWidgets("is enabled for a paragraph, which has no indent rule", (tester) async {
      final editor = _createEditor([
        ParagraphNode(id: "1", text: AttributedText("first")),
      ]);

      await _pumpToolbar(tester, editor);
      _placeCaretIn(editor, "1");
      await tester.pump();

      expect(_isEnabled(tester, Icons.format_indent_increase), isTrue);
    });

    testWidgets("is disabled when there's no selection", (tester) async {
      final editor = _createEditor([
        ListItemNode.unordered(id: "1", text: AttributedText("first")),
        ListItemNode.unordered(id: "2", text: AttributedText("second")),
      ]);

      await _pumpToolbar(tester, editor);

      expect(_isEnabled(tester, Icons.format_indent_increase), isFalse);
    });
  });

  group("Feather toolbar > un-indent button >", () {
    testWidgets("is enabled for a list item at indent 0, which becomes a paragraph", (tester) async {
      final editor = _createEditor([
        ListItemNode.unordered(id: "1", text: AttributedText("first")),
      ]);

      await _pumpToolbar(tester, editor);
      _placeCaretIn(editor, "1");
      await tester.pump();

      expect(_isEnabled(tester, Icons.format_indent_decrease), isTrue);
    });

    testWidgets("is disabled for a task at indent 0", (tester) async {
      final editor = _createEditor([
        TaskNode(id: "1", text: AttributedText("first"), isComplete: false),
      ]);

      await _pumpToolbar(tester, editor);
      _placeCaretIn(editor, "1");
      await tester.pump();

      expect(_isEnabled(tester, Icons.format_indent_decrease), isFalse);
    });

    testWidgets("is disabled for a paragraph at indent 0", (tester) async {
      final editor = _createEditor([
        ParagraphNode(id: "1", text: AttributedText("first")),
      ]);

      await _pumpToolbar(tester, editor);
      _placeCaretIn(editor, "1");
      await tester.pump();

      expect(_isEnabled(tester, Icons.format_indent_decrease), isFalse);
    });
  });
}

Editor _createEditor(List<DocumentNode> nodes) {
  return createDefaultDocumentEditor(
    document: MutableDocument(nodes: nodes),
    composer: MutableDocumentComposer(),
  );
}

Future<void> _pumpToolbar(WidgetTester tester, Editor editor) async {
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FormattingToolbar(
          editorFocusNode: focusNode,
          editor: editor,
          isShowingDeltas: false,
          onShowDeltasChange: (_) {},
        ),
      ),
    ),
  );
}

void _placeCaretIn(Editor editor, String nodeId) {
  editor.composer.setSelectionWithReason(
    DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeId,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    ),
  );
}

/// Whether the toolbar [IconButton] displaying [icon] is enabled.
bool _isEnabled(WidgetTester tester, IconData icon) {
  return tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon)).onPressed != null;
}
