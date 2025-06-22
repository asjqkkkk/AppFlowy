use async_trait::async_trait;
use collab::lock::RwLock;
use collab_database::database::Database;
use collab_database::entity::DatabaseView;
use collab_database::fields::{Field, TypeOptionData};
use collab_database::rows::{Row, RowCell, RowDetail, RowId};
use collab_database::views::{DatabaseLayout, LayoutSetting, RowOrder};
use flowy_error::{FlowyError, FlowyResult};
use lib_infra::priority_task::TaskDispatcher;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock as TokioRwLock;

use crate::entities::FieldSettingsChangesetPB;
use crate::services::calculations::Calculation;
use crate::services::field::{TypeOptionCellDataHandler, TypeOptionHandlerCache};
use crate::services::field_settings::FieldSettings;
use crate::services::filter::Filter;
use crate::services::group::GroupSetting;
use crate::services::sort::Sort;

// The DatabaseViewOperation composite trait is defined in view_operation.rs
// to maintain backward compatibility

/// Operations related to database access
///
/// This trait provides access to the underlying database instance.
/// Use this when you need direct database access.
#[async_trait]
pub trait DatabaseOperations: Send + Sync + 'static {
  /// Get the database that the view belongs to
  fn get_database(&self) -> Arc<RwLock<Database>>;
}

/// Operations related to database views
///
/// This trait handles view-specific operations.
/// Use this when working specifically with database views.
#[async_trait]
pub trait ViewOperations: Send + Sync + 'static {
  /// Get the view of the database with the view_id
  async fn get_view(&self, view_id: &str) -> Option<DatabaseView>;
}

/// Operations related to database fields
///
/// This trait handles all field-related operations including CRUD operations,
/// field settings, and type option handling.
/// Use this when working with database columns/fields.
#[async_trait]
pub trait FieldOperations: Send + Sync + 'static {
  /// If the field_ids is None, then it will return all the field revisions
  async fn get_multiple_fields(&self, view_id: &str, field_ids: Option<Vec<String>>) -> Vec<Field>;

  /// Returns the field with the field_id
  async fn get_field(&self, field_id: &str) -> Option<Field>;

  async fn update_field(
    &self,
    type_option_data: TypeOptionData,
    old_field: Field,
  ) -> Result<(), FlowyError>;

  async fn get_primary_field(&self) -> Option<Arc<Field>>;

  async fn get_type_option_cell_handler(
    &self,
    field: &Field,
    type_option_handlers: Arc<TypeOptionHandlerCache>,
  ) -> Option<Arc<dyn TypeOptionCellDataHandler>>;

  async fn get_field_settings(
    &self,
    view_id: &str,
    field_ids: &[String],
  ) -> HashMap<String, FieldSettings>;

  async fn update_field_settings(
    &self,
    params: FieldSettingsChangesetPB,
    layout_type: DatabaseLayout,
  ) -> FlowyResult<()>;
}

/// Operations related to database rows
///
/// This trait handles row-level operations including retrieval, ordering, and deletion.
/// Use this when working with database records/rows.
#[async_trait]
pub trait RowOperations: Send + Sync + 'static {
  /// Returns the index of the row with row_id
  async fn index_of_row(&self, view_id: &str, row_id: &RowId) -> Option<usize>;

  /// Returns the `index` and `RowRevision` with row_id
  async fn get_row_detail(&self, view_id: &str, row_id: &RowId) -> Option<(usize, Arc<RowDetail>)>;

  /// Returns all the rows in the view
  async fn get_all_rows(&self, view_id: &str, row_orders: Vec<RowOrder>) -> Vec<Arc<Row>>;

  async fn get_all_row_orders(&self, view_id: &str) -> Vec<RowOrder>;

  async fn remove_row(&self, row_id: &RowId);
}

/// Operations related to database cells
///
/// This trait handles individual cell operations.
/// Use this when working with specific cell values within rows and fields.
#[async_trait]
pub trait CellOperations: Send + Sync + 'static {
  async fn get_cells_for_field(&self, view_id: &str, field_id: &str) -> Vec<RowCell>;

  async fn get_cell_in_row(&self, field_id: &str, row_id: &RowId) -> Arc<RowCell>;
}

/// Operations related to database groups
///
/// This trait handles grouping functionality (like grouping by select options).
/// Use this when implementing board/kanban views or other grouped displays.
#[async_trait]
pub trait GroupOperations: Send + Sync + 'static {
  async fn get_group_setting(&self, view_id: &str) -> Vec<GroupSetting>;

  async fn insert_group_setting(&self, view_id: &str, setting: GroupSetting);
}

/// Operations related to database sorting
///
/// This trait handles all sorting operations for database views.
/// Use this when implementing sort functionality.
#[async_trait]
pub trait SortOperations: Send + Sync + 'static {
  async fn get_sort(&self, view_id: &str, sort_id: &str) -> Option<Sort>;

  async fn insert_sort(&self, view_id: &str, sort: Sort);

  async fn move_sort(&self, view_id: &str, from_sort_id: &str, to_sort_id: &str);

  async fn remove_sort(&self, view_id: &str, sort_id: &str);

  async fn get_all_sorts(&self, view_id: &str) -> Vec<Sort>;

  async fn remove_all_sorts(&self, view_id: &str);
}

/// Operations related to database filtering
///
/// This trait handles all filtering operations for database views.
/// Use this when implementing filter functionality.
#[async_trait]
pub trait FilterOperations: Send + Sync + 'static {
  async fn get_all_filters(&self, view_id: &str) -> Vec<Filter>;

  async fn get_filter(&self, view_id: &str, filter_id: &str) -> Option<Filter>;

  async fn delete_filter(&self, view_id: &str, filter_id: &str);

  async fn insert_filter(&self, view_id: &str, filter: Filter);

  async fn save_filters(&self, view_id: &str, filters: &[Filter]);
}

/// Operations related to database calculations
///
/// This trait handles calculation operations (sum, average, etc.) for database views.
/// Use this when implementing calculation functionality in footers or summaries.
#[async_trait]
pub trait CalculationOperations: Send + Sync + 'static {
  async fn get_all_calculations(&self, view_id: &str) -> Vec<Arc<Calculation>>;

  async fn get_calculation(&self, view_id: &str, field_id: &str) -> Option<Calculation>;

  async fn update_calculation(&self, view_id: &str, calculation: Calculation);

  async fn remove_calculation(&self, view_id: &str, calculation_id: &str);
}

/// Operations related to database layout
///
/// This trait handles layout-specific settings and configurations.
/// Use this when working with different view layouts (Grid, Board, Calendar).
#[async_trait]
pub trait LayoutOperations: Send + Sync + 'static {
  /// Return the database layout type for the view with given view_id
  /// The default layout type is [DatabaseLayout::Grid]
  async fn get_layout_for_view(&self, view_id: &str) -> DatabaseLayout;

  async fn get_layout_setting(
    &self,
    view_id: &str,
    layout_ty: &DatabaseLayout,
  ) -> Option<LayoutSetting>;

  async fn insert_layout_setting(
    &self,
    view_id: &str,
    layout_ty: &DatabaseLayout,
    layout_setting: LayoutSetting,
  );

  async fn update_layout_type(&self, view_id: &str, layout_type: &DatabaseLayout);
}

/// Utility operations for database views
///
/// This trait provides utility operations like task scheduling.
/// Use this when you need access to background task scheduling.
pub trait UtilityOperations: Send + Sync + 'static {
  /// Returns a `TaskDispatcher` used to poll a `Task`
  fn get_task_scheduler(&self) -> Arc<TokioRwLock<TaskDispatcher>>;
}
