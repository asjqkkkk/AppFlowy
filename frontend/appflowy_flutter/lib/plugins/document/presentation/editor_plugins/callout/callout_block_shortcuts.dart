import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';

/// Pressing Enter in a callout block will insert a newline (\n) within the callout,
/// while pressing Shift+Enter in a callout will insert a new paragraph next to the callout.
///
/// - support
///   - desktop
///   - mobile
///   - web
///
final CharacterShortcutEvent insertNewLineInCalloutBlock =
    CharacterShortcutEvent(
  key: 'insert a new line in callout block',
  character: '\n',
  handler: _insertNewLineHandler,
);

CharacterShortcutEventHandler _insertNewLineHandler = (editorState) async {
  Selection? selection = editorState.selection?.normalized;
  if (selection == null) {
    return false;
  }

  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null || node.type != CalloutBlockKeys.type) {
    return false;
  }

  // delete the selection
  await editorState.deleteSelection(selection);

  selection = editorState.selection;

  if (HardwareKeyboard.instance.isShiftPressed) {
    // ignore the shift+enter event, fallback to the default behavior
    return false;
  } else if (selection != null && selection.isCollapsed) {
    // insert a new paragraph with sliced delta within the callout block
    final length = node.delta?.length ?? selection.start.offset;
    final slicedDelta = node.delta?.slice(selection.start.offset, length);
    final newNode = paragraphNode(delta: slicedDelta);
    final path = node.path.child(0);
    final transaction = editorState.transaction;
    transaction.insertNode(
      path,
      newNode,
    );
    transaction.deleteText(
      node,
      selection.start.offset,
      length - selection.start.offset,
    );
    transaction.afterSelection = Selection.collapsed(
      Position(
        path: path,
      ),
    );
    await editorState.apply(transaction);
    return true;
  }

  return false;
};
