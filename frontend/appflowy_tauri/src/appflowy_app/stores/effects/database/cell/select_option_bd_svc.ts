import { CellIdentifier } from './cell_bd_svc';
import {
  CellIdPB,
  CreateSelectOptionPayloadPB,
  SelectOptionCellChangesetPB,
  SelectOptionChangesetPB,
  SelectOptionPB,
} from '../../../../../services/backend';
import {
  DatabaseEventCreateSelectOption,
  DatabaseEventGetSelectOptionCellData,
  DatabaseEventUpdateSelectOption,
  DatabaseEventUpdateSelectOptionCell,
} from '../../../../../services/backend/events/flowy-database';

export class SelectOptionBackendService {
  constructor(public readonly cellIdentifier: CellIdentifier) {}

  createOption = async (params: { name: string; isSelect?: boolean }) => {
    const payload = CreateSelectOptionPayloadPB.fromObject({
      option_name: params.name,
      view_id: this.cellIdentifier.viewId,
      field_id: this.cellIdentifier.fieldId,
    });

    const result = await DatabaseEventCreateSelectOption(payload);
    if (result.ok) {
      return this._insertOption(result.val, params.isSelect || true);
    } else {
      return result;
    }
  };

  updateOption = (option: SelectOptionPB) => {
    const payload = SelectOptionChangesetPB.fromObject({ cell_identifier: this._cellIdentifier() });
    payload.update_options.push(option);
    return DatabaseEventUpdateSelectOption(payload);
  };

  deleteOption = (options: SelectOptionPB[]) => {
    const payload = SelectOptionChangesetPB.fromObject({ cell_identifier: this._cellIdentifier() });
    payload.delete_options.push(...options);
    return DatabaseEventUpdateSelectOption(payload);
  };

  getOptionCellData = () => {
    return DatabaseEventGetSelectOptionCellData(this._cellIdentifier());
  };

  selectOption = (optionIds: string[]) => {
    const payload = SelectOptionCellChangesetPB.fromObject({ cell_identifier: this._cellIdentifier() });
    payload.insert_option_ids.push(...optionIds);
    return DatabaseEventUpdateSelectOptionCell(payload);
  };

  unselectOption = (optionIds: string[]) => {
    const payload = SelectOptionCellChangesetPB.fromObject({ cell_identifier: this._cellIdentifier() });
    payload.delete_option_ids.push(...optionIds);
    return DatabaseEventUpdateSelectOptionCell(payload);
  };

  private _insertOption = (option: SelectOptionPB, isSelect: boolean) => {
    const payload = SelectOptionChangesetPB.fromObject({ cell_identifier: this._cellIdentifier() });
    if (isSelect) {
      payload.insert_options.push(option);
    } else {
      payload.update_options.push(option);
    }
    return DatabaseEventUpdateSelectOption(payload);
  };

  private _cellIdentifier = () => {
    return CellIdPB.fromObject({
      view_id: this.cellIdentifier.viewId,
      field_id: this.cellIdentifier.fieldId,
      row_id: this.cellIdentifier.rowId,
    });
  };
}
