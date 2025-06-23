use async_trait::async_trait;
use std::sync::Arc;

use crate::services::cell::CellCache;
use crate::services::database_view::{
  DatabaseViewChangedNotifier, FieldOperations, RowOperations, SortOperations, UtilityOperations,
};
use crate::services::field::TypeOptionHandlerCache;
use crate::services::filter::FilterController;
use crate::services::sort::{Sort, SortController, SortOperation, SortTaskHandler};
use collab_database::fields::Field;
use collab_database::rows::Row;
use tokio::sync::RwLock;
use tracing::instrument;
use uuid::Uuid;

#[allow(clippy::too_many_arguments)]
pub(crate) async fn make_sort_controller(
  view_id: &str,
  field_ops: Arc<dyn FieldOperations>,
  row_ops: Arc<dyn RowOperations>,
  sort_ops: Arc<dyn SortOperations>,
  utility_ops: Arc<dyn UtilityOperations>,
  notifier: DatabaseViewChangedNotifier,
  filter_controller: Arc<FilterController>,
  cell_cache: CellCache,
  type_option_handlers: Arc<TypeOptionHandlerCache>,
) -> Arc<RwLock<SortController>> {
  let handler_id = Uuid::new_v4().to_string();
  let sorts = sort_ops
    .get_all_sorts(view_id)
    .await
    .into_iter()
    .map(Arc::new)
    .collect();
  let task_scheduler = utility_ops.get_task_scheduler();
  let ops = SoreOperationImpl {
    field_ops,
    row_ops,
    sort_ops,
    filter_controller,
  };
  let sort_controller = Arc::new(RwLock::new(SortController::new(
    view_id,
    &handler_id,
    sorts,
    ops,
    task_scheduler.clone(),
    cell_cache,
    notifier,
    type_option_handlers,
  )));
  task_scheduler
    .write()
    .await
    .register_handler(SortTaskHandler::new(handler_id, sort_controller.clone()));

  sort_controller
}

struct SoreOperationImpl {
  field_ops: Arc<dyn FieldOperations>,
  row_ops: Arc<dyn RowOperations>,
  sort_ops: Arc<dyn SortOperations>,
  filter_controller: Arc<FilterController>,
}

#[async_trait]
impl SortOperation for SoreOperationImpl {
  async fn get_sort(&self, view_id: &str, sort_id: &str) -> Option<Arc<Sort>> {
    self.sort_ops.get_sort(view_id, sort_id).await.map(Arc::new)
  }

  async fn get_rows(&self, view_id: &str) -> Vec<Arc<Row>> {
    let view_id = view_id.to_string();
    let row_orders = self.row_ops.get_all_row_orders(&view_id).await;
    let rows = self.row_ops.get_all_rows(&view_id, row_orders, false).await;
    self.filter_controller.filter_rows(rows).await
  }

  async fn filter_row(&self, row: &Row) -> bool {
    let rows = vec![Arc::new(row.clone())];
    let rows = self.filter_controller.filter_rows(rows).await;
    !rows.is_empty()
  }

  async fn get_field(&self, field_id: &str) -> Option<Field> {
    self.field_ops.get_field(field_id).await
  }

  #[instrument(level = "debug", skip_all)]
  async fn get_fields(&self, view_id: &str, field_ids: Option<Vec<String>>) -> Vec<Field> {
    self.field_ops.get_multiple_fields(view_id, field_ids).await
  }
}
