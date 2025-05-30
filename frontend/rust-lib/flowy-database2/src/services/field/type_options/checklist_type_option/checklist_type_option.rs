use crate::entities::{ChecklistCellDataPB, ChecklistFilterPB, SelectOptionPB};
use crate::services::cell::{CellDataChangeset, CellDataDecoder};
use crate::services::field::checklist_filter::{ChecklistCellChangeset, checklist_from_options};
use crate::services::field::{
  CellDataProtobufEncoder, TypeOption, TypeOptionCellDataCompare, TypeOptionCellDataFilter,
  TypeOptionTransform,
};
use crate::services::sort::SortCondition;
use collab_database::fields::checklist_type_option::ChecklistTypeOption;
use collab_database::fields::select_type_option::{SELECTION_IDS_SEPARATOR, SelectOption};
use collab_database::rows::Cell;
use collab_database::template::check_list_parse::ChecklistCellData;
use collab_database::template::util::TypeOptionCellData;
use flowy_error::FlowyResult;
use std::cmp::Ordering;

impl TypeOption for ChecklistTypeOption {
  type CellData = ChecklistCellData;
  type CellChangeset = ChecklistCellChangeset;
  type CellProtobufType = ChecklistCellDataPB;
  type CellFilter = ChecklistFilterPB;
}

impl CellDataProtobufEncoder for ChecklistTypeOption {
  fn protobuf_encode(
    &self,
    cell_data: <Self as TypeOption>::CellData,
  ) -> <Self as TypeOption>::CellProtobufType {
    let percentage = cell_data.percentage_complete();
    let selected_options = cell_data
      .options
      .iter()
      .filter(|option| cell_data.selected_option_ids.contains(&option.id))
      .map(|option| SelectOptionPB::from(option.clone()))
      .collect();

    let options = cell_data
      .options
      .into_iter()
      .map(SelectOptionPB::from)
      .collect();

    ChecklistCellDataPB {
      options,
      selected_options,
      percentage,
    }
  }
}

impl CellDataChangeset for ChecklistTypeOption {
  fn apply_changeset(
    &self,
    changeset: <Self as TypeOption>::CellChangeset,
    cell: Option<Cell>,
  ) -> FlowyResult<(Cell, <Self as TypeOption>::CellData)> {
    match cell {
      Some(cell) => {
        let mut cell_data = self.decode_cell(&cell)?;
        update_cell_data_with_changeset(&mut cell_data, changeset);
        Ok((Cell::from(cell_data.clone()), cell_data))
      },
      None => {
        let cell_data = checklist_from_options(changeset.insert_tasks);
        Ok((Cell::from(cell_data.clone()), cell_data))
      },
    }
  }
}

#[inline]
fn update_cell_data_with_changeset(
  cell_data: &mut ChecklistCellData,
  changeset: ChecklistCellChangeset,
) {
  // Delete the options
  cell_data
    .options
    .retain(|option| !changeset.delete_tasks.contains(&option.id));
  cell_data
    .selected_option_ids
    .retain(|option_id| !changeset.delete_tasks.contains(option_id));

  // Insert new options
  changeset.insert_tasks.into_iter().for_each(|new_task| {
    let option = SelectOption::new(&new_task.name);
    if new_task.is_complete {
      cell_data.selected_option_ids.push(option.id.clone())
    }
    match new_task.index {
      Some(index) => cell_data.options.insert(index as usize, option),
      None => cell_data.options.push(option),
    };
  });

  // Update options
  changeset
    .update_tasks
    .into_iter()
    .for_each(|updated_option| {
      if let Some(option) = cell_data
        .options
        .iter_mut()
        .find(|option| option.id == updated_option.id)
      {
        option.name = updated_option.name;
      }
    });

  // Select the options
  changeset
    .completed_task_ids
    .into_iter()
    .for_each(|option_id| {
      if let Some(index) = cell_data
        .selected_option_ids
        .iter()
        .position(|id| **id == option_id)
      {
        cell_data.selected_option_ids.remove(index);
      } else {
        cell_data.selected_option_ids.push(option_id);
      }
    });

  // Reorder
  let mut split = changeset.reorder.split(' ').take(2);
  if let (Some(from), Some(to)) = (split.next(), split.next()) {
    if let (Some(from_index), Some(to_index)) = (
      cell_data
        .options
        .iter()
        .position(|option| option.id == from),
      cell_data.options.iter().position(|option| option.id == to),
    ) {
      let option = cell_data.options.remove(from_index);
      cell_data.options.insert(to_index, option);
    }
  }
}

impl CellDataDecoder for ChecklistTypeOption {
  fn stringify_cell_data(&self, cell_data: <Self as TypeOption>::CellData) -> String {
    cell_data
      .options
      .into_iter()
      .map(|option| option.name)
      .collect::<Vec<_>>()
      .join(SELECTION_IDS_SEPARATOR)
  }
}

impl TypeOptionCellDataFilter for ChecklistTypeOption {
  fn apply_filter(
    &self,
    filter: &<Self as TypeOption>::CellFilter,
    cell_data: &<Self as TypeOption>::CellData,
  ) -> bool {
    let selected_options = cell_data.selected_options();
    filter.is_visible(&cell_data.options, &selected_options)
  }
}

impl TypeOptionCellDataCompare for ChecklistTypeOption {
  fn apply_cmp(
    &self,
    cell_data: &<Self as TypeOption>::CellData,
    other_cell_data: &<Self as TypeOption>::CellData,
    sort_condition: SortCondition,
  ) -> Ordering {
    match (cell_data.is_cell_empty(), other_cell_data.is_cell_empty()) {
      (true, true) => Ordering::Equal,
      (true, false) => Ordering::Greater,
      (false, true) => Ordering::Less,
      (false, false) => {
        let left = cell_data.percentage_complete();
        let right = other_cell_data.percentage_complete();
        // safe to unwrap because the two floats won't be NaN
        let order = left.partial_cmp(&right).unwrap();
        sort_condition.evaluate_order(order)
      },
    }
  }
}

impl TypeOptionTransform for ChecklistTypeOption {}
