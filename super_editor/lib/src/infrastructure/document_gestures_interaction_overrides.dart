import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';

/// Delegate for mouse status and clicking on special types of content,
/// e.g., tapping on a link open the URL.
///
/// Each [ContentTapDelegate] notifies its listeners whenever an
/// internal policy changes, which might impact the mouse cursor
/// style. For example, a handler in a desktop app, when hovering
/// over a link, might initially show a text cursor, but when the
/// user pressed CMD (or CTL), the mouse cursor would change to a
/// click cursor. Only the individual handlers know when or if such
/// a change should occur. When such a change does occur, the
/// handler notifies its listeners, and the handler expects that
/// someone will ask it for the desired mouse cursor style.
abstract class ContentTapDelegate with ChangeNotifier {
  /// Returns the mouse cursor to show while the mouse hovers the document, or
  /// `null` to defer to the next delegate (and, after the last, to the text
  /// cursor).
  ///
  /// This is the method the document's mouse interactors call. [details]
  /// carries the pointer's own offset as well as the [DocumentPosition] nearest
  /// to it, so a delegate can tell whether the pointer is actually over some
  /// content — e.g., over a link's glyphs, see [getCharacterSelectionUnderOffset]
  /// — rather than merely nearest to it.
  ///
  /// By default, defers to [mouseCursorForContentHover] with
  /// [DocumentHoverDetails.documentPosition], so delegates that only override
  /// [mouseCursorForContentHover] keep working unchanged.
  MouseCursor? mouseCursorForHover(DocumentHoverDetails details) {
    return mouseCursorForContentHover(details.documentPosition);
  }

  /// Returns the mouse cursor to show while the mouse hovers near
  /// [hoverPosition], or `null` to defer.
  ///
  /// [hoverPosition] is the position *nearest* to the pointer, as reported by
  /// [DocumentLayout.getDocumentPositionNearestToOffset]. That snaps a pointer
  /// anywhere in the blank space after a line onto the line's last caret
  /// position, so a delegate that needs to know what is under the pointer
  /// should override [mouseCursorForHover] instead.
  ///
  /// Only called through the default implementation of [mouseCursorForHover].
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) {
    return null;
  }

  TapHandlingInstruction onTap(DocumentTapDetails details) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onDoubleTap(DocumentTapDetails details) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onTripleTap(DocumentTapDetails details) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onPanStart(DocumentTapDetails details) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onPanUpdate(DocumentTapDetails details) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onPanEnd(DocumentTapDetails details) {
    return TapHandlingInstruction.continueHandling;
  }

  TapHandlingInstruction onPanCancel() {
    return TapHandlingInstruction.continueHandling;
  }
}

/// Information about a gesture that occured within a [DocumentLayout].
class DocumentTapDetails {
  DocumentTapDetails({
    required this.documentLayout,
    required this.layoutOffset,
    required this.globalOffset,
  });

  /// The document layout.
  ///
  /// It can be used to pull information about the logical position
  /// where the tap occurred. For example, to find the [DocumentPosition]
  /// that is nearest to the tap, to find if the tap ocurred above
  /// the first node or below the last node, etc.
  final DocumentLayout documentLayout;

  /// The position of the gesture in [DocumentLayout]'s coordinate space.
  final Offset layoutOffset;

  /// The position of the gesture in global coordinates.
  final Offset globalOffset;
}

/// Information about a mouse hover within a [DocumentLayout].
class DocumentHoverDetails {
  DocumentHoverDetails({
    required this.documentLayout,
    required this.layoutOffset,
    required this.globalOffset,
    required this.documentPosition,
  });

  /// The document layout.
  final DocumentLayout documentLayout;

  /// The position of the pointer in [DocumentLayout]'s coordinate space.
  final Offset layoutOffset;

  /// The position of the pointer in global coordinates.
  final Offset globalOffset;

  /// The [DocumentPosition] nearest to [layoutOffset].
  ///
  /// This is a snapped position, not a hit test: a pointer in the blank space
  /// after a line reports the caret position at that line's end. Use
  /// [layoutOffset] to find out what is under the pointer.
  final DocumentPosition documentPosition;
}

enum TapHandlingInstruction {
  halt,
  continueHandling,
}
