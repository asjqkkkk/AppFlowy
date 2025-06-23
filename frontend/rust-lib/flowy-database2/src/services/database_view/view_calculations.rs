use async_trait::async_trait;
use collab_database::fields::Field;
use std::sync::Arc;

use crate::services::{
  calculations::{
    Calculation, CalculationsController, CalculationsDelegate, CalculationsTaskHandler,
  },
  field::TypeOptionHandlerCache,
};
use collab_database::rows::Cell;
use uuid::Uuid;

use crate::services::database_view::{
  CalculationOperations, CellOperations, DatabaseViewChangedNotifier, FieldOperations,
  UtilityOperations,
};

pub async fn make_calculations_controller(
  view_id: &str,
  field_ops: Arc<dyn FieldOperations>,
  cell_ops: Arc<dyn CellOperations>,
  calculation_ops: Arc<dyn CalculationOperations>,
  utility_ops: Arc<dyn UtilityOperations>,
  notifier: DatabaseViewChangedNotifier,
  type_option_handlers: Arc<TypeOptionHandlerCache>,
) -> Arc<CalculationsController> {
  let calculations = calculation_ops.get_all_calculations(view_id).await;
  let task_scheduler = utility_ops.get_task_scheduler();
  let calculations_delegate = DatabaseViewCalculationsDelegateImpl {
    field_ops,
    cell_ops,
    calculation_ops,
  };
  let handler_id = Uuid::new_v4().to_string();

  let calculations_controller = CalculationsController::new(
    view_id,
    &handler_id,
    calculations_delegate,
    calculations,
    task_scheduler.clone(),
    notifier,
    type_option_handlers,
  );

  let calculations_controller = Arc::new(calculations_controller);
  task_scheduler
    .write()
    .await
    .register_handler(CalculationsTaskHandler::new(
      handler_id,
      calculations_controller.clone(),
    ));
  calculations_controller
}

struct DatabaseViewCalculationsDelegateImpl {
  field_ops: Arc<dyn FieldOperations>,
  cell_ops: Arc<dyn CellOperations>,
  calculation_ops: Arc<dyn CalculationOperations>,
}

#[async_trait]
impl CalculationsDelegate for DatabaseViewCalculationsDelegateImpl {
  async fn get_cells_for_field(&self, view_id: &str, field_id: &str) -> Vec<Arc<Cell>> {
    self
      .cell_ops
      .get_cells_for_field(view_id, field_id, false)
      .await
      .into_iter()
      .filter_map(|row_cell| row_cell.cell.map(Arc::new))
      .collect()
  }

  async fn get_field(&self, field_id: &str) -> Option<Field> {
    self.field_ops.get_field(field_id).await
  }

  async fn get_calculation(&self, view_id: &str, field_id: &str) -> Option<Arc<Calculation>> {
    self
      .calculation_ops
      .get_calculation(view_id, field_id)
      .await
      .map(Arc::new)
  }

  async fn update_calculation(&self, view_id: &str, calculation: Calculation) {
    self
      .calculation_ops
      .update_calculation(view_id, calculation)
      .await
  }

  async fn remove_calculation(&self, view_id: &str, calculation_id: &str) {
    self
      .calculation_ops
      .remove_calculation(view_id, calculation_id)
      .await
  }

  async fn get_all_calculations(&self, view_id: &str) -> Vec<Arc<Calculation>> {
    self.calculation_ops.get_all_calculations(view_id).await
  }
}
