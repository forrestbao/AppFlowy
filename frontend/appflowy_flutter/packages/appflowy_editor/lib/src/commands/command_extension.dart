import 'dart:async';

import 'package:appflowy_editor/src/core/document/node.dart';
import 'package:appflowy_editor/src/core/document/path.dart';
import 'package:appflowy_editor/src/core/location/selection.dart';
import 'package:appflowy_editor/src/editor_state.dart';
import 'package:flutter/widgets.dart';

extension CommandExtension on EditorState {
  Future<void> futureCommand(void Function() fn) async {
    final completer = Completer<void>();
    fn();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      completer.complete();
    });
    return completer.future;
  }

  Node getNode({
    Path? path,
    Node? node,
  }) {
    if (node != null) {
      return node;
    } else if (path != null) {
      return document.nodeAtPath(path)!;
    }
    throw Exception('path and node cannot be null at the same time');
  }

  TextNode getTextNode({
    Path? path,
    TextNode? textNode,
  }) {
    if (textNode != null) {
      return textNode;
    } else if (path != null) {
      return document.nodeAtPath(path)! as TextNode;
    }
    throw Exception('path and node cannot be null at the same time');
  }

  Selection getSelection(
    Selection? selection,
  ) {
    final currentSelection = service.selectionService.currentSelection.value;
    if (selection != null) {
      return selection;
    } else if (currentSelection != null) {
      return currentSelection;
    }
    throw Exception('path and textNode cannot be null at the same time');
  }

  String getTextInSelection(
    List<TextNode> textNodes,
    Selection selection,
  ) {
    List<String> res = [];
    if (!selection.isCollapsed) {
      for (var i = 0; i < textNodes.length; i++) {
        if (i == 0) {
          res.add(textNodes[i].toPlainText().substring(selection.startIndex));
        } else if (i == textNodes.length - 1) {
          res.add(textNodes[i].toPlainText().substring(0, selection.endIndex));
        } else {
          res.add(textNodes[i].toPlainText());
        }
      }
    }
    return res.join('\n');
  }
}
