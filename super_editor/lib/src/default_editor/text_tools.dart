import 'dart:math';

import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/composable_text.dart';
import 'package:super_editor/src/infrastructure/strings.dart';

/// Collection of generic text inspection behavior that does not belong
/// to any particular `DocumentNode` or `Component`.

final _log = Logger(scope: 'text_tools.dart');

/// Returns the word of text that contains the given `docPosition`, or `null` if
/// no text exists at the given `docPosition`.
///
/// A word is defined by `TextComposable#getWordSelectionAt()`.
DocumentSelection? getWordSelection({
  required DocumentPosition docPosition,
  required DocumentLayout docLayout,
}) {
  _log.log('getWordSelection', '_getWordSelection()');
  _log.log('getWordSelection', ' - doc position: $docPosition');

  final component = docLayout.getComponentByNodeId(docPosition.nodeId);
  if (component is! TextComposable) {
    return null;
  }

  final nodePosition = docPosition.nodePosition;
  if (nodePosition is! TextNodePosition) {
    return null;
  }

  // Create a new TextNodePosition to ensure that we're searching with downstream affinity, for consistent results.
  final searchPosition = TextNodePosition(offset: nodePosition.offset);
  final TextSelection wordTextSelection = (component as TextComposable).getWordSelectionAt(searchPosition);
  final wordNodeSelection = TextNodeSelection.fromTextSelection(wordTextSelection);

  _log.log('getWordSelection', ' - word selection: $wordNodeSelection');
  return DocumentSelection(
    base: DocumentPosition(
      nodeId: docPosition.nodeId,
      nodePosition: wordNodeSelection.base,
    ),
    extent: DocumentPosition(
      nodeId: docPosition.nodeId,
      nodePosition: wordNodeSelection.extent,
    ),
  );
}

/// Expands a selection in both directions starting at [textPosition] until
/// the selection reaches a space, or the end of the available text.
TextSelection expandPositionToWord({
  required String text,
  required TextPosition textPosition,
}) {
  if (text.isEmpty) {
    return const TextSelection.collapsed(offset: -1);
  }

  int start = min(textPosition.offset, text.length);
  int end = min(textPosition.offset, text.length);

  // We're checking for the character before the start index because
  // TextPosition's offset indexes the character after the caret
  while (start > 0 && text[start - 1] != ' ') {
    start -= 1;
  }
  while (end < text.length && text[end] != ' ') {
    end += 1;
  }
  return TextSelection(
    baseOffset: start,
    extentOffset: end,
  );
}

/// Returns the paragraph of text that contains the given `docPosition`, or `null`
/// if there is no text at the given `docPosition`.
///
/// A paragraph is defined as all text within the given document node, bounded by
/// newlines or the beginning/end of the node's text.
DocumentSelection? getParagraphSelection({
  required DocumentPosition docPosition,
  required DocumentLayout docLayout,
}) {
  _log.log('getParagraphSelection', '_getWordSelection()');
  _log.log('getParagraphSelection', ' - doc position: $docPosition');

  final component = docLayout.getComponentByNodeId(docPosition.nodeId);
  if (component is! TextComposable) {
    return null;
  }

  final nodePosition = docPosition.nodePosition;
  if (nodePosition is! TextNodePosition) {
    return null;
  }

  final paragraphNodeSelection = (component as TextComposable).getContiguousTextSelectionAt(nodePosition);

  return DocumentSelection(
    base: DocumentPosition(
      nodeId: docPosition.nodeId,
      nodePosition: paragraphNodeSelection.base,
    ),
    extent: DocumentPosition(
      nodeId: docPosition.nodeId,
      nodePosition: paragraphNodeSelection.extent,
    ),
  );
}

/// Expands a selection in both directions starting at [textPosition] until
/// the selection reaches a newline, or the end of the available text.
TextSelection expandPositionToParagraph({
  required String text,
  required TextPosition textPosition,
}) {
  if (text.isEmpty) {
    return const TextSelection.collapsed(offset: -1);
  }

  int start = min(textPosition.offset, text.length - 1);
  int end = min(textPosition.offset, text.length - 1);
  while (start > 0 && text[start - 1] != '\n') {
    start -= 1;
  }
  while (end < text.length && text[end] != '\n') {
    end += 1;
  }
  return TextSelection(
    baseOffset: start,
    extentOffset: end,
  );
}

/// Returns a selection around the single character whose rendered glyph lies
/// under [layoutOffset], a point in [docLayout]'s coordinate space, or `null`
/// if the point isn't over a character of text.
///
/// Use this to hit-test inline content, such as a link, where
/// [DocumentLayout.getDocumentPositionNearestToOffset] alone is too generous:
/// it snaps a point anywhere in the blank space after a line onto the caret
/// position at that line's end, so text that ends a line would claim the rest
/// of the line out to the document's edge — and likewise the padding before a
/// line's first character, and the gap after the first visual line of a
/// wrapped span.
///
/// So the nearest caret position only nominates candidates: the characters
/// (grapheme clusters, so an emoji counts as one) on either side of it. A
/// candidate is hit only if the point lies inside that character's own box —
/// its glyph width, stretched to the full height of its line so that the
/// leading above and below the glyphs still counts.
///
/// The returned selection's base is the character's upstream edge and its
/// extent is the character's downstream edge, both in the same [TextNode].
/// The base's offset is the one to query attributions at, e.g., with
/// [AttributedText.getAllAttributionsAt].
DocumentSelection? getCharacterSelectionUnderOffset({
  required Document document,
  required DocumentLayout docLayout,
  required Offset layoutOffset,
}) {
  final position = docLayout.getDocumentPositionNearestToOffset(layoutOffset);
  if (position == null) {
    return null;
  }
  final nodePosition = position.nodePosition;
  if (nodePosition is! TextNodePosition) {
    return null;
  }
  final node = document.getNodeById(position.nodeId);
  if (node is! TextNode) {
    return null;
  }

  final plainText = node.text.toPlainText();
  final caret = nodePosition.offset;
  final candidates = [
    (plainText.moveOffsetUpstreamByCharacter(caret), caret),
    (caret, plainText.moveOffsetDownstreamByCharacter(caret)),
  ];
  for (final (start, end) in candidates) {
    if (start == null || end == null) {
      continue;
    }

    final hitRect = _characterHitRect(docLayout, node.id, start, end);
    if (hitRect != null && hitRect.contains(layoutOffset)) {
      return DocumentSelection(
        base: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: start)),
        extent: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: end)),
      );
    }
  }
  return null;
}

/// The box a pointer must fall in to be "on" the character spanning [start] to
/// [end] in the text node with [nodeId]: the glyph's horizontal extent, and the
/// full height of its line.
///
/// The glyph box alone is too short whenever the line height is above 1, and
/// the caret rect alone has no width. The caret at [start], with downstream
/// affinity, sits on the character's own line, even for the first character
/// after a soft wrap.
Rect? _characterHitRect(DocumentLayout docLayout, String nodeId, int start, int end) {
  DocumentPosition at(int textOffset) => DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(offset: textOffset),
      );

  final glyph = docLayout.getRectForSelection(at(start), at(end));
  if (glyph == null || glyph.width <= 0) {
    return null;
  }
  final line = docLayout.getRectForPosition(at(start));
  if (line == null) {
    return glyph;
  }
  return Rect.fromLTRB(glyph.left, min(glyph.top, line.top), glyph.right, max(glyph.bottom, line.bottom));
}

// copied from: flutter/lib/src/widgets/editable_text.dart
// RTL covers Arabic, Hebrew, and other RTL languages such as Urdu,
// Aramic, Farsi, Dhivehi.
final RegExp _rtlRegExp = RegExp(r'[\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC]');

/// Returns the [TextDirection] of the text based on its first non-whitespace character.
///
/// The default value is [TextDirection.ltr] for any character that is not from an RTL language.
TextDirection getParagraphDirection(String text) {
  text = text.trim();

  if (text.isNotEmpty && _rtlRegExp.hasMatch(String.fromCharCode(text.runes.first))) {
    return TextDirection.rtl;
  } else {
    return TextDirection.ltr;
  }
}
