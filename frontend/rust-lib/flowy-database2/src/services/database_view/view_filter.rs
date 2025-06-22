use std::sync::Arc;

use crate::services::cell::CellCache;
use crate::services::database_view::{
  DatabaseViewChangedNotifier, FieldOperations, FilterOperations, RowOperations, UtilityOperations,
};
use crate::services::field::TypeOptionHandlerCache;
use crate::services::filter::{FilterController, FilterTaskHandler};
use uuid::Uuid;

#[allow(clippy::too_many_arguments)]
pub async fn make_filter_controller(
  view_id: &str,
  field_ops: Arc<dyn FieldOperations>,
  row_ops: Arc<dyn RowOperations>,
  filter_ops: Arc<dyn FilterOperations>,
  utility_ops: Arc<dyn UtilityOperations>,
  notifier: DatabaseViewChangedNotifier,
  cell_cache: CellCache,
  type_option_handlers: Arc<TypeOptionHandlerCache>,
) -> Arc<FilterController> {
  let task_scheduler = utility_ops.get_task_scheduler();

  let handler_id = Uuid::new_v4().to_string();
  let filter_controller = FilterController::new(
    view_id,
    &handler_id,
    task_scheduler.clone(),
    cell_cache,
    notifier,
    type_option_handlers,
    field_ops,
    row_ops,
    filter_ops,
  )
  .await;
  let filter_controller = Arc::new(filter_controller);
  task_scheduler
    .write()
    .await
    .register_handler(FilterTaskHandler::new(
      handler_id,
      filter_controller.clone(),
    ));
  filter_controller
}
