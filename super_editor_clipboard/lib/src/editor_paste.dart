import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:html2md/html2md.dart' as html2md;
import 'package:super_editor/super_editor.dart';

extension RichTextPaste on Editor {
  static const defaultIgnoredHtmlTags = {"style", "script"};

  void pasteHtml(
    Editor editor,
    String html, {
    Set<String> ignoredTags = defaultIgnoredHtmlTags,
  }) {
    // The ignored tags are removed from the parsed DOM rather than handed to
    // html2md's `ignore:` argument, because that argument leaks. Every
    // `convert(..., ignore: ...)` call runs `Rule.addIgnore`, which *inserts* a
    // new rule into html2md's package-level rule list, and nothing ever removes
    // it. Passing `ignore:` would therefore grow that list by one entry per
    // paste for the life of the process: each later conversion — anywhere in the
    // app, not just here — walks a longer list, and the tags ignored by one
    // paste stay ignored for every caller afterwards, including callers that
    // passed no `ignore:` at all.
    final document = html_parser.parse(html);
    _removeElements(document, ignoredTags.map((tag) => tag.toLowerCase()).toSet());

    final markdown = html2md.convert(
      // `html2md.convert` does exactly this to a String input
      // (`parse(input).getElementsByTagName('html').first`); doing it here lets
      // it take the tree we already sanitized.
      document.documentElement ?? document,
      styleOptions: {
        // Use "#" for headers instead of "======="
        'headingStyle': 'atx',
      },
    );
    pasteMarkdown(editor, markdown);
  }

  void pasteMarkdown(Editor editor, String markdown) {
    final contentToPaste = deserializeMarkdownToDocument(markdown);

    final composer = editor.composer;
    DocumentPosition? pastePosition = composer.selection!.extent;

    // Delete all currently selected content.
    if (!composer.selection!.isCollapsed) {
      pastePosition = CommonEditorOperations.getDocumentPositionAfterExpandedDeletion(
        document: editor.document,
        selection: composer.selection!,
      );

      if (pastePosition == null) {
        // There are no deletable nodes in the selection. Do nothing.
        return;
      }

      // Delete the selected content.
      editor.execute([
        DeleteContentRequest(documentRange: composer.selection!),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(position: pastePosition),
          SelectionChangeType.deleteContent,
          SelectionReason.userInteraction,
        ),
      ]);
    }

    editor.execute([
      PasteStructuredContentEditorRequest(
        content: contentToPaste,
        pastePosition: pastePosition,
      ),
    ]);
  }
}

/// Removes every element whose (lowercase) tag name is in [tagNames] from
/// [root]'s subtree.
///
/// Matches on the element's local name, the same way html2md's `ignore:` filter
/// does, rather than treating the tag as a CSS selector.
void _removeElements(dom.Node root, Set<String> tagNames) {
  if (tagNames.isEmpty) {
    return;
  }

  for (final node in root.nodes.toList(growable: false)) {
    if (node is! dom.Element) {
      continue;
    }
    if (tagNames.contains(node.localName?.toLowerCase())) {
      node.remove();
    } else {
      _removeElements(node, tagNames);
    }
  }
}
