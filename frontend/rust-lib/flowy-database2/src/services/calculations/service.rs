use std::sync::Arc;

use collab_database::fields::Field;
use collab_database::rows::Cell;

use crate::entities::{CalculationType, FieldType};
use crate::services::field::{TypeOptionCellExt, TypeOptionHandlerCache};
use rayon::prelude::*;

pub struct CalculationsService {
  type_option_handlers: Arc<TypeOptionHandlerCache>,
}
impl CalculationsService {
  pub fn new(type_option_handlers: Arc<TypeOptionHandlerCache>) -> Self {
    Self {
      type_option_handlers,
    }
  }

  pub async fn calculate(
    &self,
    field: &Field,
    calculation_type: i64,
    cells: Vec<Arc<Cell>>,
  ) -> String {
    let ty: CalculationType = calculation_type.into();

    match ty {
      CalculationType::Average => self.calculate_average(field, cells).await,
      CalculationType::Max => self.calculate_max(field, cells).await,
      CalculationType::Median => self.calculate_median(field, cells).await,
      CalculationType::Min => self.calculate_min(field, cells).await,
      CalculationType::Sum => self.calculate_sum(field, cells).await,
      CalculationType::Count => self.calculate_count(cells).await,
      CalculationType::CountEmpty => self.calculate_count_empty(field, cells).await,
      CalculationType::CountNonEmpty => self.calculate_count_non_empty(field, cells).await,
    }
  }

  async fn calculate_average(&self, field: &Field, cells: Vec<Arc<Cell>>) -> String {
    if let Some(handler) = TypeOptionCellExt::new(field, None, self.type_option_handlers.clone())
      .get_type_option_cell_data_handler(FieldType::from(field.field_type))
    {
      let (sum, len): (f64, usize) = cells
        .par_iter()
        .filter_map(|cell| handler.handle_numeric_cell(cell))
        .map(|value| (value, 1))
        .reduce(
          || (0.0, 0),
          |(sum1, len1), (sum2, len2)| (sum1 + sum2, len1 + len2),
        );

      if len > 0 {
        format!("{:.2}", sum / len as f64)
      } else {
        String::new()
      }
    } else {
      String::new()
    }
  }

  async fn calculate_median(&self, field: &Field, cells: Vec<Arc<Cell>>) -> String {
    let mut values = self.reduce_values_f64(field, cells).await;
    values.par_sort_by(|a, b| a.partial_cmp(b).unwrap());

    if !values.is_empty() {
      format!("{:.2}", Self::median(&values))
    } else {
      String::new()
    }
  }

  async fn calculate_min(&self, field: &Field, cells: Vec<Arc<Cell>>) -> String {
    let values = self.reduce_values_f64(field, cells).await;
    if let Some(min) = values.par_iter().min_by(|a, b| a.total_cmp(b)) {
      format!("{:.2}", min)
    } else {
      String::new()
    }
  }

  async fn calculate_max(&self, field: &Field, cells: Vec<Arc<Cell>>) -> String {
    let values = self.reduce_values_f64(field, cells).await;
    if let Some(max) = values.par_iter().max_by(|a, b| a.total_cmp(b)) {
      format!("{:.2}", max)
    } else {
      String::new()
    }
  }

  async fn calculate_sum(&self, field: &Field, cells: Vec<Arc<Cell>>) -> String {
    let values = self.reduce_values_f64(field, cells).await;
    if !values.is_empty() {
      format!("{:.2}", values.par_iter().sum::<f64>())
    } else {
      String::new()
    }
  }

  async fn calculate_count(&self, cells: Vec<Arc<Cell>>) -> String {
    format!("{}", cells.len())
  }

  async fn calculate_count_empty(&self, field: &Field, cells: Vec<Arc<Cell>>) -> String {
    if let Some(handler) = TypeOptionCellExt::new(field, None, self.type_option_handlers.clone())
      .get_type_option_cell_data_handler(FieldType::from(field.field_type))
    {
      let empty_count = cells
        .par_iter()
        .filter(|cell| handler.handle_is_empty(cell, field))
        .count();
      empty_count.to_string()
    } else {
      "".to_string()
    }
  }

  async fn calculate_count_non_empty(&self, field: &Field, cells: Vec<Arc<Cell>>) -> String {
    let field_type = FieldType::from(field.field_type);
    if let Some(handler) = TypeOptionCellExt::new(field, None, self.type_option_handlers.clone())
      .get_type_option_cell_data_handler(field_type)
    {
      let non_empty_count = cells
        .par_iter()
        .filter(|cell| !handler.handle_is_empty(cell, field))
        .count();
      non_empty_count.to_string()
    } else {
      "".to_string()
    }
  }

  async fn reduce_values_f64(&self, field: &Field, row_cells: Vec<Arc<Cell>>) -> Vec<f64> {
    if let Some(handler) = TypeOptionCellExt::new(field, None, self.type_option_handlers.clone())
      .get_type_option_cell_data_handler(FieldType::from(field.field_type))
    {
      row_cells
        .par_iter()
        .filter_map(|cell| handler.handle_numeric_cell(cell))
        .collect::<Vec<_>>()
    } else {
      vec![]
    }
  }

  fn median(array: &[f64]) -> f64 {
    if array.len() % 2 == 0 {
      let left = array.len() / 2 - 1;
      let right = array.len() / 2;
      (array[left] + array[right]) / 2.0
    } else {
      array[array.len() / 2]
    }
  }
}
