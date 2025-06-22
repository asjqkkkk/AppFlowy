use std::sync::Arc;

use collab_database::fields::Field;
use collab_database::rows::RowId;
use flowy_error::FlowyResult;
use tracing::instrument;

use crate::entities::FieldType;
use crate::services::database_view::{
  CellOperations, FieldOperations, GroupOperations, LayoutOperations, RowOperations,
};
use crate::services::field::{RowSingleCellData, TypeOptionHandlerCache};
use crate::services::filter::FilterController;
use crate::services::group::{GroupController, make_group_controller};

#[allow(clippy::too_many_arguments)]
#[instrument(level = "debug", skip_all)]
pub async fn new_group_controller(
  view_id: String,
  field_ops: Arc<dyn FieldOperations>,
  row_ops: Arc<dyn RowOperations>,
  cell_ops: Arc<dyn CellOperations>,
  group_ops: Arc<dyn GroupOperations>,
  layout_ops: Arc<dyn LayoutOperations>,
  filter_controller: Arc<FilterController>,
  grouping_field: Option<Field>,
  type_option_handlers: Arc<TypeOptionHandlerCache>,
) -> FlowyResult<Option<Box<dyn GroupController>>> {
  if !layout_ops.get_layout_for_view(&view_id).await.is_board() {
    return Ok(None);
  }

  let grouping_field = match grouping_field {
    Some(field) => Some(field),
    None => {
      let mut settings = group_ops.get_group_setting(&view_id).await;
      let group_setting = if settings.is_empty() {
        None
      } else {
        Some(Arc::new(settings.remove(0)))
      };

      let fields = field_ops.get_multiple_fields(&view_id, None).await;
      group_setting
        .and_then(|setting| {
          fields
            .iter()
            .find(|field| field.id == setting.field_id)
            .cloned()
        })
        .or_else(|| find_suitable_grouping_field(&fields))
    },
  };

  let controller = match grouping_field {
    Some(field) => Some(
      make_group_controller(
        &view_id,
        field,
        row_ops,
        cell_ops,
        group_ops,
        field_ops,
        filter_controller,
        type_option_handlers,
      )
      .await?,
    ),
    None => None,
  };

  Ok(controller)
}

pub(crate) async fn get_cell_for_row(
  field_ops: Arc<dyn FieldOperations>,
  cell_ops: Arc<dyn CellOperations>,
  field_id: &str,
  row_id: &RowId,
  type_option_handlers: Arc<TypeOptionHandlerCache>,
) -> Option<RowSingleCellData> {
  let field = field_ops.get_field(field_id).await?;
  let row_cell = cell_ops.get_cell_in_row(field_id, row_id).await;
  let field_type = FieldType::from(field.field_type);
  let handler = field_ops
    .get_type_option_cell_handler(&field, type_option_handlers)
    .await?;

  let cell_data = match &row_cell.cell {
    None => None,
    Some(cell) => handler.handle_get_boxed_cell_data(cell, &field),
  };
  Some(RowSingleCellData {
    row_id: row_cell.row_id.clone(),
    field_id: field.id.clone(),
    field_type,
    cell_data,
  })
}

// Returns the list of cells corresponding to the given field.
pub async fn get_cells_for_field(
  field_ops: Arc<dyn FieldOperations>,
  cell_ops: Arc<dyn CellOperations>,
  view_id: &str,
  field_id: &str,
  type_option_handlers: Arc<TypeOptionHandlerCache>,
) -> Vec<RowSingleCellData> {
  if let Some(field) = field_ops.get_field(field_id).await {
    let field_type = FieldType::from(field.field_type);
    if let Some(handler) = field_ops
      .get_type_option_cell_handler(&field, type_option_handlers)
      .await
    {
      let cells = cell_ops.get_cells_for_field(view_id, field_id).await;
      return cells
        .iter()
        .map(|row_cell| {
          let cell_data = match &row_cell.cell {
            None => None,
            Some(cell) => handler.handle_get_boxed_cell_data(cell, &field),
          };
          RowSingleCellData {
            row_id: row_cell.row_id.clone(),
            field_id: field.id.clone(),
            field_type,
            cell_data,
          }
        })
        .collect();
    }
  }

  vec![]
}

fn find_suitable_grouping_field(fields: &[Field]) -> Option<Field> {
  let groupable_field = fields
    .iter()
    .find(|field| FieldType::from(field.field_type).can_be_group());

  if let Some(field) = groupable_field {
    Some(field.clone())
  } else {
    fields.iter().find(|field| field.is_primary).cloned()
  }
}
