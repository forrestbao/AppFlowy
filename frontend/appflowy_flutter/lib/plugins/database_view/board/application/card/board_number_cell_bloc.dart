import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:async';
import '../../../application/cell/cell_service.dart';

part 'board_number_cell_bloc.freezed.dart';

class BoardNumberCellBloc
    extends Bloc<BoardNumberCellEvent, BoardNumberCellState> {
  final NumberCellController cellController;
  void Function()? _onCellChangedFn;
  BoardNumberCellBloc({
    required this.cellController,
  }) : super(BoardNumberCellState.initial(cellController)) {
    on<BoardNumberCellEvent>(
      (event, emit) async {
        await event.when(
          initial: () async {
            _startListening();
          },
          didReceiveCellUpdate: (content) {
            emit(state.copyWith(content: content));
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
      onCellChanged: ((cellContent) {
        if (!isClosed) {
          add(BoardNumberCellEvent.didReceiveCellUpdate(cellContent ?? ""));
        }
      }),
    );
  }
}

@freezed
class BoardNumberCellEvent with _$BoardNumberCellEvent {
  const factory BoardNumberCellEvent.initial() = _InitialCell;
  const factory BoardNumberCellEvent.didReceiveCellUpdate(String cellContent) =
      _DidReceiveCellUpdate;
}

@freezed
class BoardNumberCellState with _$BoardNumberCellState {
  const factory BoardNumberCellState({
    required String content,
  }) = _BoardNumberCellState;

  factory BoardNumberCellState.initial(TextCellController context) =>
      BoardNumberCellState(
        content: context.getCellData() ?? "",
      );
}
