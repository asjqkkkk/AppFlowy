use client_api::v2::{ObjectId, WorkspaceId};
use collab::core::collab::{CollabOptions, DataSource};
use collab::core::origin::CollabOrigin;
use collab::entity::EncodedCollab;
use collab::lock::RwLock;
use collab::preclude::Collab;
use collab_entity::CollabType;
use flowy_ai_pub::entities::{UnindexedCollab, UnindexedCollabMetadata};
use flowy_error::{FlowyError, FlowyResult};
use flowy_user::services::authenticate_user::AuthenticateUser;
use flowy_user_pub::workspace_collab::adaptor::{
  unindexed_data_form_collab, unindexed_data_from_object,
};
use flowy_user_pub::workspace_collab::adaptor_trait::{
  EditingCollabDataConsumer, WorkspaceCollabIndexer,
};
use lib_infra::async_trait::async_trait;
use std::collections::HashMap;
use std::sync::{Arc, Weak};
use std::time::Duration;
use tokio::runtime::Runtime;
use tokio::time::{interval, MissedTickBehavior};
use tracing::{debug, error, info, trace};
use uuid::Uuid;

pub struct EditingCollab {
  pub workspace_id: WorkspaceId,
  pub object_id: ObjectId,
  pub collab_type: CollabType,
}

pub struct EditingCollabDataProvider {
  collab_by_object: Arc<RwLock<HashMap<Uuid, EditingCollab>>>,
  consumers: Arc<RwLock<Vec<Box<dyn EditingCollabDataConsumer>>>>,
  authenticate_user: Weak<AuthenticateUser>,
}

impl EditingCollabDataProvider {
  pub fn new(authenticate_user: Weak<AuthenticateUser>) -> EditingCollabDataProvider {
    let collab_by_object = Arc::new(RwLock::new(HashMap::<Uuid, EditingCollab>::new()));
    let consumers = Arc::new(RwLock::new(Vec::<Box<dyn EditingCollabDataConsumer>>::new()));

    EditingCollabDataProvider {
      collab_by_object,
      consumers,
      authenticate_user,
    }
  }

  pub async fn num_consumers(&self) -> usize {
    let consumers = self.consumers.read().await;
    consumers.len()
  }

  pub async fn clear_consumers(&self) {
    let mut consumers = self.consumers.write().await;
    consumers.clear();
    info!("[Indexing] Cleared all instant index consumers");
  }

  pub async fn register_consumer(&self, consumer: Box<dyn EditingCollabDataConsumer>) {
    info!(
      "[Indexing] Registering instant index consumer: {}",
      consumer.consumer_id()
    );
    let mut guard = self.consumers.write().await;
    guard.push(consumer);
  }

  pub async fn spawn_instant_indexed_provider(&self, runtime: &Runtime) -> FlowyResult<()> {
    let weak_collab_by_object = Arc::downgrade(&self.collab_by_object);
    let consumers_weak = Arc::downgrade(&self.consumers);
    let interval_dur = Duration::from_secs(30);
    let authenticate_user = self.authenticate_user.clone();

    runtime.spawn(async move {
      let mut ticker = interval(interval_dur);
      ticker.set_missed_tick_behavior(MissedTickBehavior::Delay);
      ticker.tick().await;
      info!("[Indexing] Instant editing collab data provider started");

      loop {
        ticker.tick().await;
        let authenticate_user = match authenticate_user.upgrade() {
          Some(auth) => auth,
          None => {
            debug!("[Indexing] skip when no session");
            continue;
          },
        };

        let uid = match authenticate_user.get_session() {
          Ok(session) => session.user_id,
          Err(_) => {
            debug!("[Indexing] skip when no session");
            continue;
          },
        };

        let db = match authenticate_user
          .get_current_user_collab_db()
          .map(|v| v.upgrade())
        {
          Ok(Some(db)) => db,
          Ok(None) => {
            error!("[Indexing] collab db is empty");
            continue;
          },
          Err(err) => {
            error!("[Indexing] Failed to get collab db: {}", err);
            continue;
          },
        };

        let consumers = match consumers_weak.upgrade() {
          Some(c) => c,
          None => {
            info!("[Indexing] exiting editing collab data provider");
            break;
          },
        };

        let map = {
          match weak_collab_by_object.upgrade() {
            None => HashMap::new(),
            Some(collab_by_object) => {
              let mut guard = collab_by_object.write().await;
              std::mem::take(&mut *guard)
            },
          }
        };

        for (id, wo) in map {
          match unindexed_data_from_object(
            uid,
            &wo.workspace_id,
            &wo.object_id,
            wo.collab_type,
            db.as_ref(),
          ) {
            Ok(Some(data)) => {
              let consumers_guard = consumers.read().await;
              for consumer in consumers_guard.iter() {
                trace!("[Indexing] {} consumed {}", consumer.consumer_id(), id);
                match consumer
                  .consume_collab(
                    &wo.workspace_id,
                    data.clone(),
                    &wo.object_id,
                    wo.collab_type,
                  )
                  .await
                {
                  Ok(is_indexed) => {
                    if is_indexed {
                      trace!("[Indexing] {} consumed {}", consumer.consumer_id(), id);
                    }
                  },
                  Err(err) => {
                    error!(
                      "[Indexing] Consumer {} failed on {}: {}",
                      consumer.consumer_id(),
                      id,
                      err
                    );
                  },
                }
              }
              //
            },
            Ok(None) => {
              trace!("[Indexing] {} has no indexed data", id);
            },
            Err(err) => {
              trace!(
                "[Indexing] try to generate indexed data for:{}, got:{}",
                id,
                err
              );
            },
          }
        }
      }

      info!("[Indexing] Instant editing collab data provider stopped");
    });

    Ok(())
  }

  pub fn support_collab_type(&self, t: &CollabType) -> bool {
    matches!(t, CollabType::Document)
  }

  pub async fn index_encoded_collab(
    &self,
    workspace_id: Uuid,
    object_id: Uuid,
    data: EncodedCollab,
    collab_type: CollabType,
  ) -> FlowyResult<()> {
    match unindexed_collab_from_encoded_collab(workspace_id, object_id, data, collab_type) {
      None => Err(FlowyError::internal().with_context("Failed to create unindexed collab")),
      Some(data) => {
        self.index_unindexed_collab(data).await?;
        Ok(())
      },
    }
  }

  pub async fn index_unindexed_collab(&self, data: UnindexedCollab) -> FlowyResult<()> {
    let consumers_guard = self.consumers.read().await;
    for consumer in consumers_guard.iter() {
      match consumer
        .consume_collab(
          &data.workspace_id,
          data.data.clone(),
          &data.object_id,
          data.collab_type,
        )
        .await
      {
        Ok(is_indexed) => {
          if is_indexed {
            trace!(
              "[Indexing] {} consumed {}",
              consumer.consumer_id(),
              data.object_id
            );
          }
        },
        Err(err) => {
          error!(
            "Consumer {} failed on {}: {}",
            consumer.consumer_id(),
            data.object_id,
            err
          );
        },
      }
    }
    Ok(())
  }
}

#[async_trait]
impl WorkspaceCollabIndexer for EditingCollabDataProvider {
  async fn index_opened_collab(
    &self,
    workspace_id: WorkspaceId,
    object_id: ObjectId,
    collab_type: CollabType,
  ) {
    if !self.support_collab_type(&collab_type) {
      return;
    }

    if self.collab_by_object.read().await.contains_key(&object_id) {
      return;
    }

    trace!(
      "[Indexing] queue changed collab: workspace_id: {}, object_id: {}, collab_type: {}",
      workspace_id,
      object_id,
      collab_type
    );
    let mut map = self.collab_by_object.write().await;
    map.insert(
      object_id,
      EditingCollab {
        workspace_id,
        object_id,
        collab_type,
      },
    );
  }
}

pub fn unindexed_collab_from_encoded_collab(
  workspace_id: Uuid,
  object_id: Uuid,
  encoded_collab: EncodedCollab,
  collab_type: CollabType,
) -> Option<UnindexedCollab> {
  match collab_type {
    CollabType::Document => {
      let options = CollabOptions::new(object_id.to_string())
        .with_data_source(DataSource::DocStateV1(encoded_collab.doc_state.to_vec()));
      let collab = Collab::new_with_options(CollabOrigin::Empty, options).ok()?;
      let data = unindexed_data_form_collab(&collab, &collab_type)?;
      Some(UnindexedCollab {
        workspace_id,
        object_id,
        collab_type,
        data,
        metadata: UnindexedCollabMetadata::default(), // default means do not update metadata
      })
    },
    _ => None,
  }
}
