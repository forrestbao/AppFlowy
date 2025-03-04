import 'package:appflowy_backend/protobuf/flowy-database/url_type_option_entities.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:async';

import '../../../application/cell/cell_service.dart';

part 'board_url_cell_bloc.freezed.dart';

class BoardURLCellBloc extends Bloc<BoardURLCellEvent, BoardURLCellState> {
  final URLCellController cellController;
  void Function()? _onCellChangedFn;
  BoardURLCellBloc({
    required this.cellController,
  }) : super(BoardURLCellState.initial(cellController)) {
    on<BoardURLCellEvent>(
      (event, emit) async {
        event.when(
          initial: () {
            _startListening();
          },
          didReceiveCellUpdate: (cellData) {
            emit(state.copyWith(
              content: cellData?.content ?? "",
              url: cellData?.url ?? "",
            ));
          },
          updateURL: (String url) {
            cellController.saveCellData(url, deduplicate: true);
          },
        );
      },
    );
  }

  @override
  Future<void> close() async {
    if (_onCellChangedFn != null) {
      cellController.removeListener(_onCellChangedFn!);
      _onCellChangedFn = null;
    }
    await cellController.dispose();
    return super.close();
  }

  void _startListening() {
    _onCellChangedFn = cellController.startListening(
      onCellChanged: ((cellData) {
        if (!isClosed) {
          add(BoardURLCellEvent.didReceiveCellUpdate(cellData));
        }
      }),
    );
  }
}

@freezed
class BoardURLCellEvent with _$BoardURLCellEvent {
  const factory BoardURLCellEvent.initial() = _InitialCell;
  const factory BoardURLCellEvent.updateURL(String url) = _UpdateURL;
  const factory BoardURLCellEvent.didReceiveCellUpdate(URLCellDataPB? cell) =
      _DidReceiveCellUpdate;
}

@freezed
class BoardURLCellState with _$BoardURLCellState {
  const factory BoardURLCellState({
    required String content,
    required String url,
  }) = _BoardURLCellState;

  factory BoardURLCellState.initial(URLCellController context) {
    final cellData = context.getCellData();
    return BoardURLCellState(
      content: cellData?.content ?? "",
      url: cellData?.url ?? "",
    );
  }
}
