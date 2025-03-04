import 'package:appflowy_backend/protobuf/flowy-database/field_entities.pb.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import '../../../../application/cell/cell_service.dart';
import 'cell_accessory.dart';
import 'cell_shortcuts.dart';
import 'checkbox_cell.dart';
import 'checklist_cell/checklist_cell.dart';
import 'date_cell/date_cell.dart';
import 'number_cell.dart';
import 'select_option_cell/select_option_cell.dart';
import 'text_cell.dart';
import 'url_cell/url_cell.dart';

abstract class GridCellBuilderDelegate extends CellControllerBuilderDelegate {
  CellCache get cellCache;
}

class GridCellBuilder {
  final GridCellBuilderDelegate delegate;
  GridCellBuilder({
    required this.delegate,
  });

  GridCellWidget build(CellIdentifier cellId, {GridCellStyle? style}) {
    final cellControllerBuilder = CellControllerBuilder(
      cellId: cellId,
      cellCache: delegate.cellCache,
      delegate: delegate,
    );

    final key = cellId.key();
    switch (cellId.fieldType) {
      case FieldType.Checkbox:
        return GridCheckboxCell(
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.DateTime:
        return GridDateCell(
          cellControllerBuilder: cellControllerBuilder,
          key: key,
          style: style,
        );
      case FieldType.SingleSelect:
        return GridSingleSelectCell(
          cellControllerBuilder: cellControllerBuilder,
          style: style,
          key: key,
        );
      case FieldType.MultiSelect:
        return GridMultiSelectCell(
          cellControllerBuilder: cellControllerBuilder,
          style: style,
          key: key,
        );
      case FieldType.Checklist:
        return GridChecklistCell(
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.Number:
        return GridNumberCell(
          cellControllerBuilder: cellControllerBuilder,
          key: key,
        );
      case FieldType.RichText:
        return GridTextCell(
          cellControllerBuilder: cellControllerBuilder,
          style: style,
          key: key,
        );
      case FieldType.URL:
        return GridURLCell(
          cellControllerBuilder: cellControllerBuilder,
          style: style,
          key: key,
        );
    }
    throw UnimplementedError;
  }
}

class BlankCell extends StatelessWidget {
  const BlankCell({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

abstract class CellEditable {
  GridCellFocusListener get beginFocus;

  ValueNotifier<bool> get onCellFocus;

  ValueNotifier<bool> get onCellEditing;
}

typedef AccessoryBuilder = List<GridCellAccessoryBuilder> Function(
    GridCellAccessoryBuildContext buildContext);

abstract class CellAccessory extends Widget {
  const CellAccessory({Key? key}) : super(key: key);

  // The hover will show if the isHover's value is true
  ValueNotifier<bool>? get onAccessoryHover;

  AccessoryBuilder? get accessoryBuilder;
}

abstract class GridCellWidget extends StatefulWidget
    implements CellAccessory, CellEditable, CellShortcuts {
  GridCellWidget({Key? key}) : super(key: key) {
    onCellEditing.addListener(() {
      onCellFocus.value = onCellEditing.value;
    });
  }

  @override
  final ValueNotifier<bool> onCellFocus = ValueNotifier<bool>(false);

  // When the cell is focused, we assume that the accessory also be hovered.
  @override
  ValueNotifier<bool> get onAccessoryHover => onCellFocus;

  @override
  final ValueNotifier<bool> onCellEditing = ValueNotifier<bool>(false);

  @override
  List<GridCellAccessoryBuilder> Function(
      GridCellAccessoryBuildContext buildContext)? get accessoryBuilder => null;

  @override
  final GridCellFocusListener beginFocus = GridCellFocusListener();

  @override
  final Map<CellKeyboardKey, CellKeyboardAction> shortcutHandlers = {};
}

abstract class GridCellState<T extends GridCellWidget> extends State<T> {
  @override
  void initState() {
    widget.beginFocus.setListener(() => requestBeginFocus());
    widget.shortcutHandlers[CellKeyboardKey.onCopy] = () => onCopy();
    widget.shortcutHandlers[CellKeyboardKey.onInsert] = () {
      Clipboard.getData("text/plain").then((data) {
        final s = data?.text;
        if (s is String) {
          onInsert(s);
        }
      });
    };
    super.initState();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    if (oldWidget != this) {
      widget.beginFocus.setListener(() => requestBeginFocus());
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.beginFocus.removeAllListener();
    super.dispose();
  }

  void requestBeginFocus();

  String? onCopy() => null;

  void onInsert(String value) {}
}

abstract class GridFocusNodeCellState<T extends GridCellWidget>
    extends GridCellState<T> {
  SingleListenerFocusNode focusNode = SingleListenerFocusNode();

  @override
  void initState() {
    widget.shortcutHandlers[CellKeyboardKey.onEnter] =
        () => focusNode.unfocus();
    _listenOnFocusNodeChanged();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    if (oldWidget != this) {
      _listenOnFocusNodeChanged();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.shortcutHandlers.clear();
    focusNode.removeAllListener();
    focusNode.dispose();
    super.dispose();
  }

  @override
  void requestBeginFocus() {
    if (focusNode.hasFocus == false && focusNode.canRequestFocus) {
      FocusScope.of(context).requestFocus(focusNode);
    }
  }

  void _listenOnFocusNodeChanged() {
    widget.onCellEditing.value = focusNode.hasFocus;
    focusNode.setListener(() {
      widget.onCellEditing.value = focusNode.hasFocus;
      focusChanged();
    });
  }

  Future<void> focusChanged() async {}
}

class GridCellFocusListener extends ChangeNotifier {
  VoidCallback? _listener;

  void setListener(VoidCallback listener) {
    if (_listener != null) {
      removeListener(_listener!);
    }

    _listener = listener;
    addListener(listener);
  }

  void removeAllListener() {
    if (_listener != null) {
      removeListener(_listener!);
    }
  }

  void notify() {
    notifyListeners();
  }
}

abstract class GridCellStyle {}

class SingleListenerFocusNode extends FocusNode {
  VoidCallback? _listener;

  void setListener(VoidCallback listener) {
    if (_listener != null) {
      removeListener(_listener!);
    }

    _listener = listener;
    super.addListener(listener);
  }

  void removeAllListener() {
    if (_listener != null) {
      removeListener(_listener!);
    }
  }
}
