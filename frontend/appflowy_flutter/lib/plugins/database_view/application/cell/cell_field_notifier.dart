import 'package:flutter/foundation.dart';
import '../field/field_controller.dart';
import 'cell_service.dart';

abstract class ICellFieldNotifier {
  void onCellFieldChanged(void Function(FieldInfo) callback);
  void onCellDispose();
}

/// DatabasePB's cell helper wrapper that enables each cell will get notified when the corresponding field was changed.
/// You Register an onFieldChanged callback to listen to the cell changes, and unregister if you don't want to listen.
class CellFieldNotifier {
  final ICellFieldNotifier notifier;

  /// fieldId: {objectId: callback}
  final Map<String, Map<String, List<VoidCallback>>> _fieldListenerByFieldId =
      {};

  CellFieldNotifier({required this.notifier}) {
    notifier.onCellFieldChanged(
      (field) {
        final map = _fieldListenerByFieldId[field.id];
        if (map != null) {
          for (final callbacks in map.values) {
            for (final callback in callbacks) {
              callback();
            }
          }
        }
      },
    );
  }

  ///
  void register(CellCacheKey cacheKey, VoidCallback onFieldChanged) {
    var map = _fieldListenerByFieldId[cacheKey.fieldId];
    if (map == null) {
      _fieldListenerByFieldId[cacheKey.fieldId] = {};
      map = _fieldListenerByFieldId[cacheKey.fieldId];
      map![cacheKey.rowId] = [onFieldChanged];
    } else {
      var objects = map[cacheKey.rowId];
      if (objects == null) {
        map[cacheKey.rowId] = [onFieldChanged];
      } else {
        objects.add(onFieldChanged);
      }
    }
  }

  void unregister(CellCacheKey cacheKey, VoidCallback fn) {
    var callbacks = _fieldListenerByFieldId[cacheKey.fieldId]?[cacheKey.rowId];
    final index = callbacks?.indexWhere((callback) => callback == fn);
    if (index != null && index != -1) {
      callbacks?.removeAt(index);
    }
  }

  Future<void> dispose() async {
    notifier.onCellDispose();
    _fieldListenerByFieldId.clear();
  }
}
