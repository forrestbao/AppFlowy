import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../application/cell/cell_service.dart';
import '../../application/card/board_number_cell_bloc.dart';
import 'define.dart';

class BoardNumberCell extends StatefulWidget {
  final String groupId;
  final CellControllerBuilder cellControllerBuilder;

  const BoardNumberCell({
    required this.groupId,
    required this.cellControllerBuilder,
    Key? key,
  }) : super(key: key);

  @override
  State<BoardNumberCell> createState() => _BoardNumberCellState();
}

class _BoardNumberCellState extends State<BoardNumberCell> {
  late BoardNumberCellBloc _cellBloc;

  @override
  void initState() {
    final cellController =
        widget.cellControllerBuilder.build() as NumberCellController;

    _cellBloc = BoardNumberCellBloc(cellController: cellController)
      ..add(const BoardNumberCellEvent.initial());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cellBloc,
      child: BlocBuilder<BoardNumberCellBloc, BoardNumberCellState>(
        buildWhen: (previous, current) => previous.content != current.content,
        builder: (context, state) {
          if (state.content.isEmpty) {
            return const SizedBox();
          } else {
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: BoardSizes.cardCellVPadding,
                ),
                child: FlowyText.medium(
                  state.content,
                  fontSize: 14,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _cellBloc.close();
    super.dispose();
  }
}
