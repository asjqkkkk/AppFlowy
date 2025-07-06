use client_api::entity::billing_dto::{PersonalPlan, PersonalSubscriptionStatus};
use flowy_derive::{ProtoBuf, ProtoBuf_Enum};
use flowy_server_pub::billing_dto::{
  Currency, RecurringInterval, SubscriptionPlan, SubscriptionPlanDetail,
  WorkspaceSubscriptionStatus,
};
use lib_infra::validator_fn::required_not_empty_str;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use validator::Validate;

#[derive(Debug, ProtoBuf, Default, Clone)]
pub struct WorkspaceSubscriptionInfoPB {
  #[pb(index = 1)]
  pub plan: SubscriptionPlanPB,
  #[pb(index = 2)]
  pub subscription: WorkspaceSubscriptionPB, // valid if plan is not WorkspacePlanFree
  #[pb(index = 3)]
  pub add_ons: Vec<WorkspaceAddOnPB>,
}

impl WorkspaceSubscriptionInfoPB {
  pub fn default_from_workspace_id(workspace_id: Uuid) -> Self {
    Self {
      plan: SubscriptionPlanPB::Pro,
      subscription: WorkspaceSubscriptionPB {
        workspace_id: workspace_id.to_string(),
        subscription_plan: SubscriptionPlanPB::Free,
        status: SubscriptionStatusPB::Active,
        end_date: 0,
        interval: RecurringIntervalPB::Month,
      },
      add_ons: Vec::new(),
    }
  }
}

impl From<Vec<WorkspaceSubscriptionStatus>> for WorkspaceSubscriptionInfoPB {
  fn from(subs: Vec<WorkspaceSubscriptionStatus>) -> Self {
    let mut plan = SubscriptionPlanPB::Free;
    let mut plan_subscription = WorkspaceSubscriptionPB::default();
    let mut add_ons = Vec::new();
    for sub in subs {
      match sub.workspace_plan {
        SubscriptionPlan::Free => {
          plan = SubscriptionPlanPB::Free;
        },
        SubscriptionPlan::Pro => {
          plan = SubscriptionPlanPB::Pro;
          plan_subscription = sub.into();
        },
        SubscriptionPlan::Team => {
          plan = SubscriptionPlanPB::Team;
        },
        SubscriptionPlan::AiMax => {
          if plan_subscription.workspace_id.is_empty() {
            plan_subscription =
              WorkspaceSubscriptionPB::default_with_workspace_id(sub.workspace_id.clone());
          }

          add_ons.push(WorkspaceAddOnPB {
            type_: WorkspaceAddOnPBType::AddOnAiMax,
            add_on_subscription: sub.into(),
          });
        },
        SubscriptionPlan::AiLocal => {
          if plan_subscription.workspace_id.is_empty() {
            plan_subscription =
              WorkspaceSubscriptionPB::default_with_workspace_id(sub.workspace_id.clone());
          }

          add_ons.push(WorkspaceAddOnPB {
            type_: WorkspaceAddOnPBType::AddOnAiLocal,
            add_on_subscription: sub.into(),
          });
        },
      }
    }

    WorkspaceSubscriptionInfoPB {
      plan,
      subscription: plan_subscription,
      add_ons,
    }
  }
}

#[derive(Debug, ProtoBuf, Default, Clone, Serialize, Deserialize)]
pub struct WorkspaceAddOnPB {
  #[pb(index = 1)]
  type_: WorkspaceAddOnPBType,
  #[pb(index = 2)]
  add_on_subscription: WorkspaceSubscriptionPB,
}

#[derive(ProtoBuf_Enum, Debug, Clone, Eq, PartialEq, Default, Serialize, Deserialize)]
pub enum WorkspaceAddOnPBType {
  #[default]
  AddOnAiLocal = 0,
  AddOnAiMax = 1,
}

#[derive(Debug, ProtoBuf, Default, Clone, Serialize, Deserialize)]
pub struct WorkspaceSubscriptionPB {
  #[pb(index = 1)]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub subscription_plan: SubscriptionPlanPB,

  #[pb(index = 3)]
  pub status: SubscriptionStatusPB,

  #[pb(index = 4)]
  pub end_date: i64, // Unix timestamp of when this subscription cycle ends

  #[pb(index = 5)]
  pub interval: RecurringIntervalPB,
}

impl WorkspaceSubscriptionPB {
  pub fn default_with_workspace_id(workspace_id: String) -> Self {
    Self {
      workspace_id,
      subscription_plan: SubscriptionPlanPB::Free,
      status: SubscriptionStatusPB::Active,
      end_date: 0,
      interval: RecurringIntervalPB::Month,
    }
  }
}

impl From<WorkspaceSubscriptionStatus> for WorkspaceSubscriptionPB {
  fn from(sub: WorkspaceSubscriptionStatus) -> Self {
    Self {
      workspace_id: sub.workspace_id,
      subscription_plan: sub.workspace_plan.clone().into(),
      status: if sub.cancel_at.is_some() {
        SubscriptionStatusPB::Canceled
      } else {
        SubscriptionStatusPB::Active
      },
      interval: sub.recurring_interval.into(),
      end_date: sub.current_period_end,
    }
  }
}

#[derive(ProtoBuf_Enum, Debug, Clone, Eq, PartialEq, Default, Serialize, Deserialize)]
pub enum SubscriptionStatusPB {
  #[default]
  Active = 0,
  Canceled = 1,
}

impl From<SubscriptionStatusPB> for i64 {
  fn from(val: SubscriptionStatusPB) -> Self {
    val as i64
  }
}

impl From<i64> for SubscriptionStatusPB {
  fn from(value: i64) -> Self {
    match value {
      0 => SubscriptionStatusPB::Active,
      _ => SubscriptionStatusPB::Canceled,
    }
  }
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct UpdateWorkspaceSubscriptionPaymentPeriodPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub plan: SubscriptionPlanPB,

  #[pb(index = 3)]
  pub recurring_interval: RecurringIntervalPB,
}

#[derive(ProtoBuf, Default, Clone)]
pub struct SubscriptionPlanDetailPB {
  #[pb(index = 1)]
  pub currency: CurrencyPB,
  #[pb(index = 2)]
  pub price_cents: i64,
  #[pb(index = 3)]
  pub recurring_interval: RecurringIntervalPB,
  #[pb(index = 4)]
  pub plan: SubscriptionPlanPB,
}

impl From<SubscriptionPlanDetail> for SubscriptionPlanDetailPB {
  fn from(value: SubscriptionPlanDetail) -> Self {
    Self {
      currency: value.currency.into(),
      price_cents: value.price_cents,
      recurring_interval: value.recurring_interval.into(),
      plan: value.plan.into(),
    }
  }
}

#[derive(ProtoBuf_Enum, Clone, Default)]
pub enum CurrencyPB {
  #[default]
  USD = 0,
}

impl From<Currency> for CurrencyPB {
  fn from(value: Currency) -> Self {
    match value {
      Currency::USD => CurrencyPB::USD,
    }
  }
}

#[derive(ProtoBuf, Default, Clone, Validate, Debug)]
pub struct SubscribeWorkspacePB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub recurring_interval: RecurringIntervalPB,

  #[pb(index = 3)]
  pub plan: SubscriptionPlanPB,

  #[pb(index = 4)]
  pub success_url: String,
}

#[derive(ProtoBuf_Enum, Clone, Default, Debug, Serialize, Deserialize)]
pub enum RecurringIntervalPB {
  #[default]
  Month = 0,
  Year = 1,
}

impl From<RecurringIntervalPB> for RecurringInterval {
  fn from(r: RecurringIntervalPB) -> Self {
    match r {
      RecurringIntervalPB::Month => RecurringInterval::Month,
      RecurringIntervalPB::Year => RecurringInterval::Year,
    }
  }
}

impl From<RecurringInterval> for RecurringIntervalPB {
  fn from(r: RecurringInterval) -> Self {
    match r {
      RecurringInterval::Month => RecurringIntervalPB::Month,
      RecurringInterval::Year => RecurringIntervalPB::Year,
    }
  }
}

#[derive(ProtoBuf_Enum, Clone, Default, Debug, Serialize, Deserialize)]
pub enum SubscriptionPlanPB {
  #[default]
  Free = 0,
  Pro = 1,
  Team = 2,

  // Add-ons
  AiMax = 3,
  AiLocal = 4,
}

impl From<SubscriptionPlanPB> for SubscriptionPlan {
  fn from(value: SubscriptionPlanPB) -> Self {
    match value {
      SubscriptionPlanPB::Pro => SubscriptionPlan::Pro,
      SubscriptionPlanPB::Team => SubscriptionPlan::Team,
      SubscriptionPlanPB::Free => SubscriptionPlan::Free,
      SubscriptionPlanPB::AiMax => SubscriptionPlan::AiMax,
      SubscriptionPlanPB::AiLocal => SubscriptionPlan::AiLocal,
    }
  }
}

impl From<SubscriptionPlan> for SubscriptionPlanPB {
  fn from(value: SubscriptionPlan) -> Self {
    match value {
      SubscriptionPlan::Pro => SubscriptionPlanPB::Pro,
      SubscriptionPlan::Team => SubscriptionPlanPB::Team,
      SubscriptionPlan::Free => SubscriptionPlanPB::Free,
      SubscriptionPlan::AiMax => SubscriptionPlanPB::AiMax,
      SubscriptionPlan::AiLocal => SubscriptionPlanPB::AiLocal,
    }
  }
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct CancelWorkspaceSubscriptionPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2)]
  pub plan: SubscriptionPlanPB,

  #[pb(index = 3)]
  pub reason: String,
}

#[derive(ProtoBuf, Default, Clone, Validate)]
pub struct SuccessWorkspaceSubscriptionPB {
  #[pb(index = 1)]
  #[validate(custom(function = "required_not_empty_str"))]
  pub workspace_id: String,

  #[pb(index = 2, one_of)]
  pub plan: Option<SubscriptionPlanPB>,
}

#[derive(ProtoBuf, Default, Clone, Validate, Debug)]
pub struct SubscribePersonalPB {
  #[pb(index = 1)]
  pub recurring_interval: RecurringIntervalPB,

  #[pb(index = 2)]
  pub plan: PersonalPlanPB,

  #[pb(index = 3)]
  pub success_url: String,
}

#[derive(ProtoBuf_Enum, Clone, Default, Debug, Serialize, Deserialize)]
pub enum PersonalPlanPB {
  #[default]
  VaultWorkspace = 0,
}

impl From<PersonalPlanPB> for PersonalPlan {
  fn from(value: PersonalPlanPB) -> Self {
    match value {
      PersonalPlanPB::VaultWorkspace => PersonalPlan::VaultWorkspace,
    }
  }
}

impl From<PersonalPlan> for PersonalPlanPB {
  fn from(value: PersonalPlan) -> Self {
    match value {
      PersonalPlan::VaultWorkspace => PersonalPlanPB::VaultWorkspace,
    }
  }
}

#[derive(ProtoBuf, Default, Clone)]
pub struct CancelPersonalSubscriptionPB {
  #[pb(index = 1)]
  pub plan: PersonalPlanPB,

  #[pb(index = 3)]
  pub reason: String,
}

#[derive(Debug, ProtoBuf, Default, Clone, Serialize, Deserialize)]
pub struct PersonalSubscriptionInfoPB {
  #[pb(index = 1)]
  pub subscriptions: Vec<PersonalSubscriptionPB>,
}

impl From<Vec<PersonalSubscriptionStatus>> for PersonalSubscriptionInfoPB {
  fn from(subs: Vec<PersonalSubscriptionStatus>) -> Self {
    let subscriptions = subs.into_iter().map(|s| s.into()).collect();
    PersonalSubscriptionInfoPB { subscriptions }
  }
}

#[derive(Debug, ProtoBuf, Default, Clone, Serialize, Deserialize)]
pub struct PersonalSubscriptionPB {
  #[pb(index = 1)]
  pub plan: PersonalPlanPB,

  #[pb(index = 3)]
  pub status: SubscriptionStatusPB,

  #[pb(index = 4)]
  pub end_date: i64, // Unix timestamp of when this subscription cycle ends

  #[pb(index = 5)]
  pub interval: RecurringIntervalPB,
}

impl PersonalSubscriptionPB {
  pub fn is_vault_active(&self) -> bool {
    matches!(self.plan, PersonalPlanPB::VaultWorkspace)
      && matches!(self.status, SubscriptionStatusPB::Active)
  }
}

impl From<PersonalSubscriptionStatus> for PersonalSubscriptionPB {
  fn from(status: PersonalSubscriptionStatus) -> Self {
    Self {
      plan: status.plan.into(),
      status: match status.subscription_status {
        flowy_server_pub::billing_dto::SubscriptionStatus::Active => SubscriptionStatusPB::Active,
        _ => SubscriptionStatusPB::Canceled,
      },
      end_date: status.current_period_end,
      interval: status.recurring_interval.into(),
    }
  }
}
