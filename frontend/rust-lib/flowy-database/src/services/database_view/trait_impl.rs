use crate::entities::{CalendarSettingsParams, DatabaseViewSettingPB, LayoutSettingPB};
use crate::services::database_view::{get_cells_for_field, DatabaseViewData};
use crate::services::field::RowSingleCellData;
use crate::services::filter::{FilterController, FilterDelegate, FilterType};
use crate::services::group::{GroupConfigurationReader, GroupConfigurationWriter};
use crate::services::row::DatabaseBlockRowRevision;
use crate::services::sort::{SortDelegate, SortType};
use bytes::Bytes;
use database_model::{
  FieldRevision, FieldTypeRevision, FilterRevision, GroupConfigurationRevision, LayoutRevision,
  RowRevision, SortRevision,
};
use flowy_client_sync::client_database::{DatabaseViewRevisionChangeset, DatabaseViewRevisionPad};
use flowy_client_sync::make_operations_from_revisions;
use flowy_error::{FlowyError, FlowyResult};
use flowy_revision::{
  RevisionCloudService, RevisionManager, RevisionMergeable, RevisionObjectDeserializer,
  RevisionObjectSerializer,
};
use flowy_sqlite::ConnectionPool;
use lib_infra::future::{to_fut, Fut, FutureResult};
use lib_ot::core::EmptyAttributes;
use revision_model::Revision;
use std::sync::Arc;
use tokio::sync::RwLock;

pub(crate) struct DatabaseViewRevisionCloudService {
  #[allow(dead_code)]
  pub(crate) token: String,
}

impl RevisionCloudService for DatabaseViewRevisionCloudService {
  fn fetch_object(
    &self,
    _user_id: &str,
    _object_id: &str,
  ) -> FutureResult<Vec<Revision>, FlowyError> {
    FutureResult::new(async move { Ok(vec![]) })
  }
}

pub(crate) struct DatabaseViewRevisionSerde();
impl RevisionObjectDeserializer for DatabaseViewRevisionSerde {
  type Output = DatabaseViewRevisionPad;

  fn deserialize_revisions(
    _object_id: &str,
    revisions: Vec<Revision>,
  ) -> FlowyResult<Self::Output> {
    let pad = DatabaseViewRevisionPad::from_revisions(revisions)?;
    Ok(pad)
  }

  fn recover_from_revisions(_revisions: Vec<Revision>) -> Option<(Self::Output, i64)> {
    None
  }
}

impl RevisionObjectSerializer for DatabaseViewRevisionSerde {
  fn combine_revisions(revisions: Vec<Revision>) -> FlowyResult<Bytes> {
    let operations = make_operations_from_revisions::<EmptyAttributes>(revisions)?;
    Ok(operations.json_bytes())
  }
}

pub(crate) struct DatabaseViewRevisionMergeable();
impl RevisionMergeable for DatabaseViewRevisionMergeable {
  fn combine_revisions(&self, revisions: Vec<Revision>) -> FlowyResult<Bytes> {
    DatabaseViewRevisionSerde::combine_revisions(revisions)
  }
}

pub(crate) struct GroupConfigurationReaderImpl {
  pub(crate) pad: Arc<RwLock<DatabaseViewRevisionPad>>,
  pub(crate) view_editor_delegate: Arc<dyn DatabaseViewData>,
}

impl GroupConfigurationReader for GroupConfigurationReaderImpl {
  fn get_configuration(&self) -> Fut<Option<Arc<GroupConfigurationRevision>>> {
    let view_pad = self.pad.clone();
    to_fut(async move {
      let mut groups = view_pad.read().await.get_all_groups();
      if groups.is_empty() {
        None
      } else {
        debug_assert_eq!(groups.len(), 1);
        Some(groups.pop().unwrap())
      }
    })
  }

  fn get_configuration_cells(&self, field_id: &str) -> Fut<FlowyResult<Vec<RowSingleCellData>>> {
    let field_id = field_id.to_owned();
    let view_editor_delegate = self.view_editor_delegate.clone();
    to_fut(async move { get_cells_for_field(view_editor_delegate, &field_id).await })
  }
}

pub(crate) struct GroupConfigurationWriterImpl {
  pub(crate) user_id: String,
  pub(crate) rev_manager: Arc<RevisionManager<Arc<ConnectionPool>>>,
  pub(crate) view_pad: Arc<RwLock<DatabaseViewRevisionPad>>,
}

impl GroupConfigurationWriter for GroupConfigurationWriterImpl {
  fn save_configuration(
    &self,
    field_id: &str,
    field_type: FieldTypeRevision,
    group_configuration: GroupConfigurationRevision,
  ) -> Fut<FlowyResult<()>> {
    let user_id = self.user_id.clone();
    let rev_manager = self.rev_manager.clone();
    let view_pad = self.view_pad.clone();
    let field_id = field_id.to_owned();

    to_fut(async move {
      let changeset = view_pad
        .write()
        .await
        .insert_or_update_group_configuration(&field_id, &field_type, group_configuration)?;

      if let Some(changeset) = changeset {
        apply_change(&user_id, rev_manager, changeset).await?;
      }
      Ok(())
    })
  }
}

pub(crate) async fn apply_change(
  _user_id: &str,
  rev_manager: Arc<RevisionManager<Arc<ConnectionPool>>>,
  change: DatabaseViewRevisionChangeset,
) -> FlowyResult<()> {
  let DatabaseViewRevisionChangeset {
    operations: delta,
    md5,
  } = change;
  let data = delta.json_bytes();
  let _ = rev_manager.add_local_revision(data, md5).await?;
  Ok(())
}

pub fn make_database_view_setting(
  view_pad: &DatabaseViewRevisionPad,
  field_revs: &[Arc<FieldRevision>],
) -> DatabaseViewSettingPB {
  let layout_type: LayoutRevision = view_pad.layout.clone();
  let mut layout_settings = LayoutSettingPB::new();
  match layout_type {
    LayoutRevision::Grid => {},
    LayoutRevision::Board => {},
    LayoutRevision::Calendar => {
      layout_settings.calendar = view_pad
        .get_layout_setting::<CalendarSettingsParams>(&layout_type)
        .map(|params| params.into());
    },
  }

  let filters = view_pad.get_all_filters(field_revs);
  let group_configurations = view_pad.get_groups_by_field_revs(field_revs);
  let sorts = view_pad.get_all_sorts(field_revs);
  DatabaseViewSettingPB {
    current_layout: layout_type.into(),
    layout_setting: layout_settings,
    filters: filters.into(),
    sorts: sorts.into(),
    group_configurations: group_configurations.into(),
  }
}

pub(crate) struct DatabaseViewFilterDelegateImpl {
  pub(crate) editor_delegate: Arc<dyn DatabaseViewData>,
  pub(crate) view_revision_pad: Arc<RwLock<DatabaseViewRevisionPad>>,
}

impl FilterDelegate for DatabaseViewFilterDelegateImpl {
  fn get_filter_rev(&self, filter_type: FilterType) -> Fut<Option<Arc<FilterRevision>>> {
    let pad = self.view_revision_pad.clone();
    to_fut(async move {
      let field_type_rev: FieldTypeRevision = filter_type.field_type.into();
      let mut filters = pad
        .read()
        .await
        .get_filters(&filter_type.field_id, &field_type_rev);
      if filters.is_empty() {
        None
      } else {
        debug_assert_eq!(filters.len(), 1);
        filters.pop()
      }
    })
  }

  fn get_field_rev(&self, field_id: &str) -> Fut<Option<Arc<FieldRevision>>> {
    self.editor_delegate.get_field_rev(field_id)
  }

  fn get_field_revs(&self, field_ids: Option<Vec<String>>) -> Fut<Vec<Arc<FieldRevision>>> {
    self.editor_delegate.get_field_revs(field_ids)
  }

  fn get_blocks(&self) -> Fut<Vec<DatabaseBlockRowRevision>> {
    self.editor_delegate.get_blocks()
  }

  fn get_row_rev(&self, row_id: &str) -> Fut<Option<(usize, Arc<RowRevision>)>> {
    self.editor_delegate.get_row_rev(row_id)
  }
}

pub(crate) struct DatabaseViewSortDelegateImpl {
  pub(crate) editor_delegate: Arc<dyn DatabaseViewData>,
  pub(crate) view_revision_pad: Arc<RwLock<DatabaseViewRevisionPad>>,
  pub(crate) filter_controller: Arc<FilterController>,
}

impl SortDelegate for DatabaseViewSortDelegateImpl {
  fn get_sort_rev(&self, sort_type: SortType) -> Fut<Option<Arc<SortRevision>>> {
    let pad = self.view_revision_pad.clone();
    to_fut(async move {
      let field_type_rev: FieldTypeRevision = sort_type.field_type.into();
      let mut sorts = pad
        .read()
        .await
        .get_sorts(&sort_type.field_id, &field_type_rev);
      if sorts.is_empty() {
        None
      } else {
        // Currently, one sort_type should have one sort.
        debug_assert_eq!(sorts.len(), 1);
        sorts.pop()
      }
    })
  }

  fn get_row_revs(&self) -> Fut<Vec<Arc<RowRevision>>> {
    let filter_controller = self.filter_controller.clone();
    let editor_delegate = self.editor_delegate.clone();
    to_fut(async move {
      let mut row_revs = editor_delegate.get_row_revs(None).await;
      filter_controller.filter_row_revs(&mut row_revs).await;
      row_revs
    })
  }

  fn get_field_rev(&self, field_id: &str) -> Fut<Option<Arc<FieldRevision>>> {
    self.editor_delegate.get_field_rev(field_id)
  }

  fn get_field_revs(&self, field_ids: Option<Vec<String>>) -> Fut<Vec<Arc<FieldRevision>>> {
    self.editor_delegate.get_field_revs(field_ids)
  }
}
