use crate::entities::{FieldSettingsChangesetPB, FieldSettingsPB, FieldType};
use crate::notification::{DatabaseNotification, database_notification_builder};
use crate::services::calculations::Calculation;
use crate::services::cell::CellCache;
use crate::services::database::{DatabaseViewEditorEntry, update_field_type_option_fn};
use crate::services::database_view::{
  CalculationOperations, CellOperations, DatabaseOperations, FieldOperations, FilterOperations,
  GroupOperations, LayoutOperations, RowOperations, SortOperations, UtilityOperations,
  ViewOperations,
};
use crate::services::field::{
  TypeOptionCellDataHandler, TypeOptionCellExt, TypeOptionHandlerCache,
};
use crate::services::field_settings::{FieldSettings, default_field_settings_by_layout_map};
use crate::services::filter::Filter;
use crate::services::group::GroupSetting;
use crate::services::sort::Sort;
use async_trait::async_trait;
use collab::lock::RwLock;
use collab_database::database::Database;
use collab_database::entity::DatabaseView;
use collab_database::fields::{Field, TypeOptionData};
use collab_database::rows::{Row, RowCell, RowDetail, RowId};
use collab_database::views::{DatabaseLayout, FilterMap, LayoutSetting, RowOrder};
use dashmap::DashMap;
use flowy_error::{FlowyError, FlowyResult};
use futures::{StreamExt, pin_mut};
use lib_infra::priority_task::TaskDispatcher;
use std::collections::HashMap;
use std::sync::{Arc, Weak};
use std::time::Duration;
use tokio::sync::RwLock as TokioRwLock;
use tracing::{error, instrument, trace};

pub(crate) struct UtilityOperationImpl {
  pub(crate) task_scheduler: Weak<TokioRwLock<TaskDispatcher>>,
}

pub(crate) struct DatabaseOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
}

impl DatabaseOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }
}

// Implement DatabaseOperations
impl DatabaseOperations for DatabaseOperationImpl {
  fn get_database(&self) -> Arc<RwLock<Database>> {
    self.database().expect("Database has been dropped")
  }
}

pub(crate) struct ViewOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
}
impl ViewOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }
}

// Implement ViewOperations
#[async_trait]
impl ViewOperations for ViewOperationImpl {
  async fn get_view(&self, view_id: &str) -> Option<DatabaseView> {
    let database = self.database().ok()?;
    let read_guard = database.read().await;
    read_guard.get_view(view_id)
  }
}

pub(crate) struct FieldOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
  pub(crate) cell_cache: CellCache,
  pub(crate) database_view_editors: Weak<DashMap<String, DatabaseViewEditorEntry>>,
  pub(crate) type_option_handler: Arc<TypeOptionHandlerCache>,
}

impl FieldOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }

  fn database_view_editors(
    &self,
  ) -> Result<Arc<DashMap<String, DatabaseViewEditorEntry>>, FlowyError> {
    self
      .database_view_editors
      .upgrade()
      .ok_or_else(FlowyError::ref_drop)
  }
}

// Implement FieldOperations
#[async_trait]
impl FieldOperations for FieldOperationImpl {
  #[instrument(level = "debug", skip_all)]
  async fn get_multiple_fields(&self, view_id: &str, field_ids: Option<Vec<String>>) -> Vec<Field> {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => return vec![],
    };
    let result = database
      .try_read_for_duration(Duration::from_millis(300))
      .await;
    match result {
      Ok(read_guard) => read_guard.get_fields_in_view(view_id, field_ids),
      Err(err) => {
        error!("Failed to acquire read lock on database: {}", err);
        vec![]
      },
    }
  }

  async fn get_field(&self, field_id: &str) -> Option<Field> {
    let database = self.database().ok()?;
    let read_guard = database
      .try_read_for_duration(Duration::from_millis(300))
      .await
      .ok()?;
    read_guard.get_field(field_id)
  }

  async fn update_field(
    &self,
    type_option_data: TypeOptionData,
    old_field: Field,
  ) -> Result<(), FlowyError> {
    let database_view_editors = self.database_view_editors()?;
    let database = self.database()?;

    let mut view_editors = vec![];
    for entry in database_view_editors.as_ref() {
      if let Some(editor) = entry.get_resource().await {
        view_editors.push(editor);
      }
    }

    {
      let mut database = database.write_with_reason("update filed type").await;
      let _ = update_field_type_option_fn(
        &mut database,
        type_option_data,
        &old_field,
        &self.type_option_handler,
      )
      .await;
      drop(database);
    }

    for view_editor in view_editors {
      view_editor
        .v_did_update_field_type_option(&old_field)
        .await?;
    }
    Ok(())
  }

  async fn get_primary_field(&self) -> Option<Arc<Field>> {
    let database = self.database().ok()?;
    let read_guard = database
      .try_read_for_duration(Duration::from_millis(300))
      .await
      .ok()?;
    read_guard.get_primary_field().map(Arc::new)
  }

  async fn get_type_option_cell_handler(
    &self,
    field: &Field,
    type_option_handlers: Arc<TypeOptionHandlerCache>,
  ) -> Option<Arc<dyn TypeOptionCellDataHandler>> {
    let field_type = FieldType::from(field.field_type);
    TypeOptionCellExt::new(field, Some(self.cell_cache.clone()), type_option_handlers)
      .get_type_option_cell_data_handler(field_type)
  }

  async fn get_field_settings(
    &self,
    view_id: &str,
    field_ids: &[String],
  ) -> HashMap<String, FieldSettings> {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => return HashMap::new(),
    };

    let (layout_type, field_settings_map) = {
      let database = database.read().await;
      let layout_type = database.get_database_view_layout(view_id);
      let field_settings_map = database.get_field_settings(view_id, Some(field_ids));
      (layout_type, field_settings_map)
    };

    let default_field_settings = default_field_settings_by_layout_map()
      .get(&layout_type)
      .unwrap()
      .to_owned();

    let field_settings = field_ids
      .iter()
      .map(|field_id| {
        if !field_settings_map.contains_key(field_id) {
          let field_settings =
            FieldSettings::from_any_map(field_id, layout_type, &default_field_settings);
          (field_id.clone(), field_settings)
        } else {
          let field_settings = FieldSettings::from_any_map(
            field_id,
            layout_type,
            field_settings_map.get(field_id).unwrap(),
          );
          (field_id.clone(), field_settings)
        }
      })
      .collect();

    field_settings
  }

  async fn update_field_settings(
    &self,
    params: FieldSettingsChangesetPB,
    layout_type: DatabaseLayout,
  ) -> FlowyResult<()> {
    let field_settings_map = self
      .get_field_settings(&params.view_id, &[params.field_id.clone()])
      .await;

    let field_settings = match field_settings_map.get(&params.field_id).cloned() {
      Some(field_settings) => field_settings,
      None => {
        let default_field_settings = default_field_settings_by_layout_map();
        let default_field_settings = default_field_settings.get(&layout_type).unwrap();
        FieldSettings::from_any_map(&params.field_id, layout_type, default_field_settings)
      },
    };

    let new_field_settings = FieldSettings {
      visibility: params
        .visibility
        .unwrap_or_else(|| field_settings.visibility.clone()),
      width: params.width.unwrap_or(field_settings.width),
      wrap_cell_content: params
        .wrap_cell_content
        .unwrap_or(field_settings.wrap_cell_content),
      ..field_settings
    };

    self
      .database()?
      .write_with_reason("update field setting")
      .await
      .update_field_settings(
        &params.view_id,
        Some(vec![params.field_id]),
        new_field_settings.clone(),
      );

    database_notification_builder(
      &params.view_id,
      DatabaseNotification::DidUpdateFieldSettings,
    )
    .payload(FieldSettingsPB::from(new_field_settings))
    .send();
    Ok(())
  }
}

impl RowOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }
}
pub(crate) struct RowOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
}

// Implement RowOperations
#[async_trait]
impl RowOperations for RowOperationImpl {
  async fn index_of_row(&self, view_id: &str, row_id: &RowId) -> Option<usize> {
    let database = self.database().ok()?;
    let read_guard = database
      .try_read_for_duration(Duration::from_millis(300))
      .await
      .ok()?;
    read_guard.index_of_row(view_id, row_id)
  }

  async fn get_row_detail(&self, view_id: &str, row_id: &RowId) -> Option<(usize, Arc<RowDetail>)> {
    let database = self.database().ok()?;

    let read_guard = database
      .try_read_for_duration(Duration::from_millis(300))
      .await
      .ok()?;
    let index = read_guard.index_of_row(view_id, row_id);
    let row_detail = read_guard.get_row_detail(row_id).await;
    match (index, row_detail) {
      (Some(index), Some(row_detail)) => Some((index, Arc::new(row_detail))),
      _ => None,
    }
  }

  async fn get_all_rows(&self, view_id: &str, row_orders: Vec<RowOrder>) -> Vec<Arc<Row>> {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => return vec![],
    };

    let view_id = view_id.to_string();
    trace!("{} has total row orders: {}", view_id, row_orders.len());
    let mut all_rows = vec![];
    let read_guard = database.read().await;
    let rows_stream = read_guard
      .get_rows_from_row_orders(row_orders, 10, None)
      .await;
    pin_mut!(rows_stream);

    while let Some(result) = rows_stream.next().await {
      match result {
        Ok(row) => {
          all_rows.push(row);
        },
        Err(err) => error!("Error while loading rows: {}", err),
      }
    }

    trace!("total row details: {}", all_rows.len());
    all_rows.into_iter().map(Arc::new).collect()
  }

  async fn get_all_row_orders(&self, view_id: &str) -> Vec<RowOrder> {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => return vec![],
    };
    let read_guard = database.read().await;
    read_guard.get_row_orders_for_view(view_id)
  }

  async fn remove_row(&self, row_id: &RowId) {
    if let Ok(database) = self.database() {
      if let Ok(mut database) = database.try_write() {
        database.remove_row(row_id).await;
      } else {
        error!("Failed to acquire write lock on database");
      }
    }
  }
}

pub(crate) struct CellOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
  pub(crate) database_view_editors: Weak<DashMap<String, DatabaseViewEditorEntry>>,
}
impl CellOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }

  fn database_view_editors(
    &self,
  ) -> Result<Arc<DashMap<String, DatabaseViewEditorEntry>>, FlowyError> {
    self
      .database_view_editors
      .upgrade()
      .ok_or_else(FlowyError::ref_drop)
  }
}

// Implement CellOperations
#[async_trait]
impl CellOperations for CellOperationImpl {
  async fn get_cells_for_field(&self, view_id: &str, field_id: &str) -> Vec<RowCell> {
    let database_view_editors = match self.database_view_editors() {
      Ok(editors) => editors,
      Err(_) => return vec![],
    };

    let editor = database_view_editors.get(view_id);
    match editor {
      None => vec![],
      Some(editor) => {
        if let Some(editor) = editor.get_resource().await {
          editor.v_get_cells_for_field(field_id).await
        } else {
          vec![]
        }
      },
    }
  }

  async fn get_cell_in_row(&self, field_id: &str, row_id: &RowId) -> Arc<RowCell> {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => {
        return Arc::new(RowCell {
          row_id: row_id.clone(),
          cell: None,
        });
      },
    };
    let cell = database.read().await.get_cell(field_id, row_id).await;
    cell.into()
  }
}

pub(crate) struct GroupOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
}

impl GroupOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }
}

// Implement GroupOperations
#[async_trait]
impl GroupOperations for GroupOperationImpl {
  async fn get_group_setting(&self, view_id: &str) -> Vec<GroupSetting> {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => return vec![],
    };
    let read_guard = database.read().await;
    read_guard.get_all_group_setting(view_id)
  }

  async fn insert_group_setting(&self, view_id: &str, setting: GroupSetting) {
    if let Ok(database) = self.database() {
      database
        .write()
        .await
        .insert_group_setting(view_id, setting);
    }
  }
}

pub(crate) struct SortOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
}

impl SortOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }
}

// Implement SortOperations
#[async_trait]
impl SortOperations for SortOperationImpl {
  async fn get_sort(&self, view_id: &str, sort_id: &str) -> Option<Sort> {
    let database = self.database().ok()?;
    let read_guard = database.read().await;
    read_guard.get_sort::<Sort>(view_id, sort_id)
  }

  async fn insert_sort(&self, view_id: &str, sort: Sort) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("insert sort").await;
      write_guard.insert_sort(view_id, sort);
    }
  }

  async fn move_sort(&self, view_id: &str, from_sort_id: &str, to_sort_id: &str) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("move sort").await;
      write_guard.move_sort(view_id, from_sort_id, to_sort_id);
    }
  }

  async fn remove_sort(&self, view_id: &str, sort_id: &str) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("remove sort").await;
      write_guard.remove_sort(view_id, sort_id);
    }
  }

  async fn get_all_sorts(&self, view_id: &str) -> Vec<Sort> {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => return vec![],
    };
    let read_guard = database.read().await;
    read_guard.get_all_sorts::<Sort>(view_id)
  }

  async fn remove_all_sorts(&self, view_id: &str) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("remove all sort").await;
      write_guard.remove_all_sorts(view_id);
    }
  }
}

pub(crate) struct FilterOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
}

impl FilterOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }
}

// Implement FilterOperations
#[async_trait]
impl FilterOperations for FilterOperationImpl {
  async fn get_all_filters(&self, view_id: &str) -> Vec<Filter> {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => return vec![],
    };
    let read_guard = database.read().await;
    read_guard.get_all_filters(view_id).into_iter().collect()
  }

  async fn get_filter(&self, view_id: &str, filter_id: &str) -> Option<Filter> {
    let database = self.database().ok()?;
    let read_guard = database.read().await;
    read_guard.get_filter::<Filter>(view_id, filter_id)
  }

  async fn delete_filter(&self, view_id: &str, filter_id: &str) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("delete filter").await;
      write_guard.remove_filter(view_id, filter_id);
    }
  }

  async fn insert_filter(&self, view_id: &str, filter: Filter) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("insert filter").await;
      write_guard.insert_filter(view_id, &filter);
    }
  }

  async fn save_filters(&self, view_id: &str, filters: &[Filter]) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("save filters").await;
      write_guard.save_filters::<Filter, FilterMap>(view_id, filters);
    }
  }
}

pub(crate) struct CalculationOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
}

impl CalculationOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }
}

// Implement CalculationOperations
#[async_trait]
impl CalculationOperations for CalculationOperationImpl {
  async fn get_all_calculations(&self, view_id: &str) -> Vec<Arc<Calculation>> {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => return vec![],
    };
    let read_guard = database.read().await;
    read_guard
      .get_all_calculations(view_id)
      .into_iter()
      .map(Arc::new)
      .collect()
  }

  async fn get_calculation(&self, view_id: &str, field_id: &str) -> Option<Calculation> {
    let database = self.database().ok()?;
    let read_guard = database.read().await;
    read_guard.get_calculation::<Calculation>(view_id, field_id)
  }

  async fn update_calculation(&self, view_id: &str, calculation: Calculation) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("update calculation").await;
      write_guard.update_calculation(view_id, calculation)
    }
  }

  async fn remove_calculation(&self, view_id: &str, field_id: &str) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("remove calculation").await;
      write_guard.remove_calculation(view_id, field_id)
    }
  }
}

pub(crate) struct LayoutOperationImpl {
  pub(crate) database: Weak<RwLock<Database>>,
}

impl LayoutOperationImpl {
  fn database(&self) -> Result<Arc<RwLock<Database>>, FlowyError> {
    self.database.upgrade().ok_or_else(FlowyError::ref_drop)
  }
}

// Implement LayoutOperations
#[async_trait]
impl LayoutOperations for LayoutOperationImpl {
  async fn get_layout_for_view(&self, view_id: &str) -> DatabaseLayout {
    let database = match self.database() {
      Ok(db) => db,
      Err(_) => return DatabaseLayout::Grid,
    };
    let read_guard = database.read().await;
    read_guard.get_database_view_layout(view_id)
  }

  async fn get_layout_setting(
    &self,
    view_id: &str,
    layout_ty: &DatabaseLayout,
  ) -> Option<LayoutSetting> {
    let database = self.database().ok()?;
    let read_guard = database.read().await;
    read_guard.get_layout_setting(view_id, layout_ty)
  }

  async fn insert_layout_setting(
    &self,
    view_id: &str,
    layout_ty: &DatabaseLayout,
    layout_setting: LayoutSetting,
  ) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("insert layout setting").await;
      write_guard.insert_layout_setting(view_id, layout_ty, layout_setting);
    }
  }

  async fn update_layout_type(&self, view_id: &str, layout_type: &DatabaseLayout) {
    if let Ok(database) = self.database() {
      let mut write_guard = database.write_with_reason("update layout type").await;
      write_guard.update_layout_type(view_id, layout_type);
    }
  }
}

impl UtilityOperationImpl {
  fn task_scheduler(&self) -> Result<Arc<TokioRwLock<TaskDispatcher>>, FlowyError> {
    self
      .task_scheduler
      .upgrade()
      .ok_or_else(FlowyError::ref_drop)
  }
}

// Implement UtilityOperations
impl UtilityOperations for UtilityOperationImpl {
  fn get_task_scheduler(&self) -> Arc<TokioRwLock<TaskDispatcher>> {
    self
      .task_scheduler()
      .expect("Task scheduler has been dropped")
  }
}
