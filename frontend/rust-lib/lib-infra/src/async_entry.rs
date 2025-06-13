use std::sync::Arc;
use std::time::Instant;
use tokio::sync::{broadcast, RwLock};
use tracing::debug;

#[derive(Clone, Debug)]
pub enum ResourceState {
  Initializing,
  Active,
  Failed,
  PendingRemoval { removal_time: Instant },
}

// Internal mutable state wrapped in RwLock
#[derive(Debug)]
struct AsyncEntryState<T> {
  resource: Option<T>,
  state: ResourceState,
  last_access: Instant,
  initialization_sender: Option<broadcast::Sender<Result<T, String>>>,
  initialization_claimed: bool,
}

impl<T> AsyncEntryState<T>
where
  T: Clone,
{
  fn new() -> Self {
    let (sender, _) = broadcast::channel(1);
    Self {
      resource: None,
      state: ResourceState::Initializing,
      last_access: Instant::now(),
      initialization_sender: Some(sender),
      initialization_claimed: false,
    }
  }
}

pub struct AsyncEntry<T, Id> {
  id: Id,
  state: Arc<RwLock<AsyncEntryState<T>>>,
}

impl<T, Id> AsyncEntry<T, Id>
where
  Id: Clone + std::fmt::Display + std::fmt::Debug,
  T: Clone,
{
  pub fn new_initializing(id: Id) -> Self {
    Self {
      id,
      state: Arc::new(RwLock::new(AsyncEntryState::new())),
    }
  }

  pub async fn mark_for_removal(&self) {
    debug!("[ResourceEntry]: mark resource as removal {}", self.id);
    let mut state = self.state.write().await;
    match state.state {
      ResourceState::Active => {
        state.state = ResourceState::PendingRemoval {
          removal_time: Instant::now(),
        };
      },
      _ => {
        debug!(
          "[ResourceEntry]: Resource {} not active, will be cleaned up immediately",
          self.id
        );
      },
    }
  }

  pub async fn reactivate(&self) {
    debug!("[ResourceEntry]: Reactivating resource {}", self.id);
    let mut state = self.state.write().await;
    state.last_access = Instant::now();

    match state.state {
      ResourceState::PendingRemoval { .. } => {
        if state.resource.is_some() {
          state.state = ResourceState::Active;
        } else {
          // This shouldn't happen, but if it does, mark as failed
          state.state = ResourceState::Failed;
        }
      },
      ResourceState::Failed => {
        // Restart initialization from failed state
        state.state = ResourceState::Initializing;
        state.initialization_claimed = false;
        let (sender, _) = broadcast::channel(1);
        state.initialization_sender = Some(sender);
      },
      ResourceState::Initializing | ResourceState::Active => {
        // Keep current state but update access time
      },
    }
  }

  pub async fn removal_time(&self) -> Option<Instant> {
    let state = self.state.read().await;
    match state.state {
      ResourceState::PendingRemoval { removal_time } => Some(removal_time),
      _ => None,
    }
  }

  pub async fn get_resource(&self) -> Option<T> {
    let state = self.state.read().await;
    // Only return resource if in active state
    match state.state {
      ResourceState::Active => state.resource.clone(),
      _ => None,
    }
  }

  pub async fn set_resource(&self, resource: T) {
    let mut state = self.state.write().await;
    let resource_clone = resource.clone();
    state.resource = Some(resource);
    state.state = ResourceState::Active;
    state.initialization_claimed = false;
    state.last_access = Instant::now();

    // Send the successful result to all waiters
    if let Some(sender) = &state.initialization_sender {
      let _ = sender.send(Ok(resource_clone));
    }
    // Clear the sender as initialization is complete
    state.initialization_sender = None;
  }

  /// Mark the start of initialization. Returns true if initialization was started, false if already in progress or not needed.
  pub async fn try_mark_initialization_start(&self) -> bool {
    let mut state = self.state.write().await;
    match state.state {
      ResourceState::Initializing => {
        if !state.initialization_claimed {
          state.initialization_claimed = true;
          state.last_access = Instant::now();
          true
        } else {
          false // Already claimed by someone else
        }
      },
      ResourceState::Active => {
        // Don't reinitialize if we already have a valid resource
        if state.resource.is_some() {
          return false;
        }
        // Start initialization if no resource
        state.state = ResourceState::Initializing;
        state.initialization_claimed = true;
        state.last_access = Instant::now();
        let (sender, _) = broadcast::channel(1);
        state.initialization_sender = Some(sender);
        true
      },
      ResourceState::Failed | ResourceState::PendingRemoval { .. } => {
        // Clear any existing resource on retry
        state.resource = None;
        state.state = ResourceState::Initializing;
        state.initialization_claimed = true;
        state.last_access = Instant::now();
        // Create a new sender for the retry
        let (sender, _) = broadcast::channel(1);
        state.initialization_sender = Some(sender);
        true
      },
    }
  }

  pub async fn mark_initialization_failed(&self, error: String) {
    let mut state = self.state.write().await;
    if let ResourceState::Initializing = state.state {
      state.resource = None; // Ensure no resource is set
      state.state = ResourceState::Failed;
      state.initialization_claimed = false;

      // Send the error result to all waiters
      if let Some(sender) = &state.initialization_sender {
        let _ = sender.send(Err(error));
      }
      // Clear the sender as initialization is complete (failed)
      state.initialization_sender = None;
    }
  }

  /// Check if the entry is in a state that can be cleaned up
  pub async fn can_be_removed(&self) -> bool {
    let state = self.state.read().await;
    matches!(
      state.state,
      ResourceState::Failed | ResourceState::PendingRemoval { .. }
    )
  }

  /// Get the last access time for cleanup purposes
  #[allow(dead_code)]
  pub async fn last_access(&self) -> Instant {
    let state = self.state.read().await;
    state.last_access
  }

  /// Get the current state for inspection
  #[allow(dead_code)]
  pub async fn state(&self) -> ResourceState {
    let state = self.state.read().await;
    state.state.clone()
  }

  /// Get the resource ID
  #[allow(dead_code)]
  pub fn id(&self) -> &Id {
    &self.id
  }

  /// Check if the entry has a resource available
  #[allow(dead_code)]
  pub async fn has_resource(&self) -> bool {
    let state = self.state.read().await;
    state.resource.is_some()
  }

  /// Check if the entry is in active state
  #[allow(dead_code)]
  pub async fn is_active(&self) -> bool {
    let state = self.state.read().await;
    matches!(state.state, ResourceState::Active)
  }

  /// Check if the entry is initializing
  #[allow(dead_code)]
  pub async fn is_initializing(&self) -> bool {
    let state = self.state.read().await;
    matches!(state.state, ResourceState::Initializing)
  }

  /// Check if the entry has failed
  #[allow(dead_code)]
  pub async fn is_failed(&self) -> bool {
    let state = self.state.read().await;
    matches!(state.state, ResourceState::Failed)
  }

  /// Wait for initialization to complete with a timeout
  /// Returns the resource if successful, or an error if failed/timed out
  pub async fn wait_for_initialization(&self, timeout: std::time::Duration) -> Result<T, String> {
    // First, read the current state
    let receiver = {
      let state = self.state.read().await;

      // If already active, return immediately
      if let ResourceState::Active = state.state {
        if let Some(resource) = &state.resource {
          return Ok(resource.clone());
        }
      }

      // If already failed, return immediately
      if let ResourceState::Failed = state.state {
        return Err("Resource initialization previously failed".to_string());
      }

      // If not initializing, return error
      if !matches!(state.state, ResourceState::Initializing) {
        return Err("Resource is not being initialized".to_string());
      }

      // Get a receiver for the initialization result
      if let Some(sender) = &state.initialization_sender {
        sender.subscribe()
      } else {
        return Err("No initialization in progress".to_string());
      }
    };

    // Wait for the result with timeout
    let mut receiver = receiver;
    tokio::select! {
      result = receiver.recv() => {
        match result {
          Ok(resource_result) => resource_result,
          Err(_) => Err("Initialization channel closed unexpectedly".to_string()),
        }
      }
      _ = tokio::time::sleep(timeout) => {
        Err("Initialization timed out".to_string())
      }
    }
  }
}

// Implement Clone for AsyncEntry
impl<T, Id> Clone for AsyncEntry<T, Id>
where
  T: Clone,
  Id: Clone + std::fmt::Display + std::fmt::Debug,
{
  fn clone(&self) -> Self {
    // Clone that shares the same internal state (Arc<RwLock<AsyncEntryState<T>>>)
    // This allows multiple references to the same AsyncEntry with shared state
    Self {
      id: self.id.clone(),
      state: Arc::clone(&self.state),
    }
  }
}

// AsyncEntry is now Send + Sync since RwLock<T> is Send + Sync when T is Send + Sync
unsafe impl<T, Id> Send for AsyncEntry<T, Id>
where
  T: Send,
  Id: Send,
{
}

unsafe impl<T, Id> Sync for AsyncEntry<T, Id>
where
  T: Send + Sync,
  Id: Send + Sync,
{
}

#[cfg(test)]
mod tests {
  use super::*;
  use std::time::Duration;
  use tokio::time::timeout;

  #[derive(Clone, Debug, PartialEq)]
  struct TestResource {
    data: String,
  }

  impl TestResource {
    fn new(data: &str) -> Self {
      Self {
        data: data.to_string(),
      }
    }
  }

  // Helper function to create a test error
  fn test_error() -> String {
    "Test error".to_string()
  }

  #[tokio::test]
  async fn test_new_initializing() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);

    assert_eq!(entry.id(), &42);
    assert!(entry.is_initializing().await);
    assert!(!entry.is_active().await);
    assert!(!entry.is_failed().await);
    assert!(!entry.has_resource().await);
    assert_eq!(entry.get_resource().await, None);
    assert!(!entry.can_be_removed().await);
    assert_eq!(entry.removal_time().await, None);
  }

  #[tokio::test]
  async fn test_set_resource() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");

    entry.set_resource(resource.clone()).await;

    assert!(entry.is_active().await);
    assert!(!entry.is_initializing().await);
    assert!(!entry.is_failed().await);
    assert!(entry.has_resource().await);
    assert_eq!(entry.get_resource().await, Some(resource));
    assert!(!entry.can_be_removed().await);
  }

  #[tokio::test]
  async fn test_mark_initialization_failed() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let error = test_error();

    entry.mark_initialization_failed(error).await;

    assert!(entry.is_failed().await);
    assert!(!entry.is_initializing().await);
    assert!(!entry.is_active().await);
    assert!(!entry.has_resource().await);
    assert_eq!(entry.get_resource().await, None);
    assert!(entry.can_be_removed().await);
  }

  #[tokio::test]
  async fn test_mark_for_removal_active() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource).await;

    entry.mark_for_removal().await;

    assert!(!entry.is_active().await);
    assert!(!entry.is_initializing().await);
    assert!(!entry.is_failed().await);
    assert!(entry.can_be_removed().await);
    assert!(entry.removal_time().await.is_some());
  }

  #[tokio::test]
  async fn test_mark_for_removal_non_active() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);

    entry.mark_for_removal().await;

    // Should remain in initializing state, not become pending removal
    assert!(entry.is_initializing().await);
    assert!(!entry.can_be_removed().await);
    assert!(entry.removal_time().await.is_none());
  }

  #[tokio::test]
  async fn test_reactivate_from_pending_removal() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource.clone()).await;
    entry.mark_for_removal().await;

    entry.reactivate().await;

    assert!(entry.is_active().await);
    assert!(!entry.can_be_removed().await);
    assert!(entry.removal_time().await.is_none());
    assert_eq!(entry.get_resource().await, Some(resource));
  }

  #[tokio::test]
  async fn test_reactivate_from_failed() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    entry.mark_initialization_failed(test_error()).await;

    entry.reactivate().await;

    assert!(entry.is_initializing().await);
    assert!(!entry.is_failed().await);
    assert!(!entry.can_be_removed().await);
  }

  #[tokio::test]
  async fn test_reactivate_from_pending_removal_without_resource() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource).await;
    entry.mark_for_removal().await;

    // Manually clear the resource to simulate edge case
    {
      let mut state = entry.state.write().await;
      state.resource = None;
    }

    entry.reactivate().await;

    assert!(entry.is_failed().await);
    assert!(entry.can_be_removed().await);
  }

  #[tokio::test]
  async fn test_mark_initialization_start_from_initializing() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);

    let result = entry.try_mark_initialization_start().await;

    assert!(result); // Should return true on first call
    assert!(entry.is_initializing().await);
    
    // Second call should return false as already claimed
    let result2 = entry.try_mark_initialization_start().await;
    assert!(!result2);
    assert!(entry.is_initializing().await);
  }

  #[tokio::test]
  async fn test_mark_initialization_start_from_active_with_resource() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource).await;

    let result = entry.try_mark_initialization_start().await;

    assert!(!result); // Should return false as resource already exists
    assert!(entry.is_active().await);
  }

  #[tokio::test]
  async fn test_mark_initialization_start_from_active_without_resource() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    // Manually set to active without resource
    {
      let mut state = entry.state.write().await;
      state.state = ResourceState::Active;
    }

    let result = entry.try_mark_initialization_start().await;

    assert!(result); // Should return true and start initialization
    assert!(entry.is_initializing().await);
  }

  #[tokio::test]
  async fn test_mark_initialization_start_from_failed() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    entry.mark_initialization_failed(test_error()).await;

    let result = entry.try_mark_initialization_start().await;

    assert!(result); // Should return true and restart initialization
    assert!(entry.is_initializing().await);
    assert!(!entry.has_resource().await);
  }

  #[tokio::test]
  async fn test_mark_initialization_start_from_pending_removal() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource).await;
    entry.mark_for_removal().await;

    let result = entry.try_mark_initialization_start().await;

    assert!(result); // Should return true and restart initialization
    assert!(entry.is_initializing().await);
    assert!(!entry.has_resource().await);
  }

  #[tokio::test]
  async fn test_mark_initialization_failed_when_not_initializing() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource.clone()).await;

    // Try to mark as failed when active - should not change state
    entry.mark_initialization_failed(test_error()).await;

    assert!(entry.is_active().await);
    assert_eq!(entry.get_resource().await, Some(resource));
  }

  #[tokio::test]
  async fn test_last_access_updates() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let initial_time = entry.last_access().await;

    // Sleep a small amount to ensure time difference
    tokio::time::sleep(Duration::from_millis(10)).await;

    entry.reactivate().await;
    let after_reactivate = entry.last_access().await;

    assert!(after_reactivate > initial_time);
  }

  #[tokio::test]
  async fn test_wait_for_initialization_already_active() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource.clone()).await;

    let result = entry
      .wait_for_initialization(Duration::from_millis(100))
      .await;

    assert!(result.is_ok());
    assert_eq!(result.unwrap(), resource);
  }

  #[tokio::test]
  async fn test_wait_for_initialization_already_failed() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    entry.mark_initialization_failed(test_error()).await;

    let result = entry
      .wait_for_initialization(Duration::from_millis(100))
      .await;

    assert!(result.is_err());
    assert!(result.unwrap_err().contains("previously failed"));
  }

  #[tokio::test]
  async fn test_wait_for_initialization_not_initializing() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource).await;
    entry.mark_for_removal().await;

    let result = entry
      .wait_for_initialization(Duration::from_millis(100))
      .await;

    assert!(result.is_err());
    assert!(result.unwrap_err().contains("not being initialized"));
  }

  #[tokio::test]
  async fn test_wait_for_initialization_success() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");

    // Get the sender to manually trigger success
    let sender = {
      let state = entry.state.read().await;
      state.initialization_sender.as_ref().unwrap().clone()
    };

    // Spawn a task to send success after a delay
    let resource_clone = resource.clone();
    tokio::spawn(async move {
      tokio::time::sleep(Duration::from_millis(50)).await;
      let _ = sender.send(Ok(resource_clone));
    });

    let result = entry
      .wait_for_initialization(Duration::from_millis(200))
      .await;

    assert!(result.is_ok());
    assert_eq!(result.unwrap(), resource);
  }

  #[tokio::test]
  async fn test_wait_for_initialization_timeout() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);

    let result = entry
      .wait_for_initialization(Duration::from_millis(10))
      .await;

    assert!(result.is_err());
    assert!(result.unwrap_err().contains("timed out"));
  }

  #[tokio::test]
  async fn test_wait_for_initialization_channel_closed() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);

    // Drop the sender to simulate channel closing
    {
      let mut state = entry.state.write().await;
      state.initialization_sender = None;
    }

    let result = entry
      .wait_for_initialization(Duration::from_millis(100))
      .await;

    assert!(result.is_err());
    assert!(result
      .unwrap_err()
      .contains("No initialization in progress"));
  }

  #[tokio::test]
  async fn test_concurrent_initialization_broadcast() {
    use std::sync::Arc;

    let entry = Arc::new(AsyncEntry::<TestResource, u32>::new_initializing(42));
    let resource = TestResource::new("test data");

    // Get the sender before we move entry
    let sender = {
      let state = entry.state.read().await;
      state.initialization_sender.as_ref().unwrap().clone()
    };

    // Spawn multiple waiters
    let waiter1 = tokio::spawn({
      let entry = Arc::clone(&entry);
      async move {
        entry
          .wait_for_initialization(Duration::from_millis(1000))
          .await
      }
    });

    let waiter2 = tokio::spawn({
      let entry = Arc::clone(&entry);
      async move {
        entry
          .wait_for_initialization(Duration::from_millis(1000))
          .await
      }
    });

    // Wait a bit then broadcast success
    tokio::time::sleep(Duration::from_millis(10)).await;
    let _ = sender.send(Ok(resource.clone()));

    // Both waiters should receive the same result
    let result1 = waiter1.await.unwrap();
    let result2 = waiter2.await.unwrap();

    assert!(result1.is_ok());
    assert!(result2.is_ok());
    assert_eq!(result1.unwrap(), resource);
    assert_eq!(result2.unwrap(), resource);
  }

  #[tokio::test]
  async fn test_concurrent_initialization_broadcast_failure() {
    use std::sync::Arc;

    let entry = Arc::new(AsyncEntry::<TestResource, u32>::new_initializing(42));
    let error = test_error();

    // Get the sender before we move entry
    let sender = {
      let state = entry.state.read().await;
      state.initialization_sender.as_ref().unwrap().clone()
    };

    // Spawn multiple waiters
    let waiter1 = tokio::spawn({
      let entry = Arc::clone(&entry);
      async move {
        entry
          .wait_for_initialization(Duration::from_millis(1000))
          .await
      }
    });

    let waiter2 = tokio::spawn({
      let entry = Arc::clone(&entry);
      async move {
        entry
          .wait_for_initialization(Duration::from_millis(1000))
          .await
      }
    });

    // Wait a bit then broadcast failure
    tokio::time::sleep(Duration::from_millis(10)).await;
    let _ = sender.send(Err(error));

    // Both waiters should receive the error
    let result1 = waiter1.await.unwrap();
    let result2 = waiter2.await.unwrap();

    assert!(result1.is_err());
    assert!(result2.is_err());
  }

  #[tokio::test]
  async fn test_state_transitions_complete_lifecycle() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);

    // Start: Initializing
    assert!(entry.is_initializing().await);

    // Set resource: Initializing -> Active
    let resource = TestResource::new("test data");
    entry.set_resource(resource.clone()).await;
    assert!(entry.is_active().await);
    assert_eq!(entry.get_resource().await, Some(resource.clone()));

    // Mark for removal: Active -> PendingRemoval
    entry.mark_for_removal().await;
    assert!(entry.can_be_removed().await);
    assert!(entry.removal_time().await.is_some());
    assert_eq!(entry.get_resource().await, None); // Should not return resource when pending removal

    // Reactivate: PendingRemoval -> Active
    entry.reactivate().await;
    assert!(entry.is_active().await);
    assert_eq!(entry.get_resource().await, Some(resource));

    // Mark for removal again: Active -> PendingRemoval
    entry.mark_for_removal().await;
    assert!(entry.can_be_removed().await);

    // Try to restart initialization: PendingRemoval -> Initializing
    let restarted = entry.try_mark_initialization_start().await;
    assert!(restarted);
    assert!(entry.is_initializing().await);
    assert!(!entry.has_resource().await);

    // Fail initialization: Initializing -> Failed
    entry.mark_initialization_failed(test_error()).await;
    assert!(entry.is_failed().await);
    assert!(entry.can_be_removed().await);

    // Reactivate from failed: Failed -> Initializing
    entry.reactivate().await;
    assert!(entry.is_initializing().await);
    assert!(!entry.can_be_removed().await);
  }

  #[tokio::test]
  async fn test_edge_case_multiple_set_resource_calls() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);

    let resource1 = TestResource::new("first");
    let resource2 = TestResource::new("second");

    entry.set_resource(resource1).await;
    assert!(entry.is_active().await);

    // Setting resource again should update it
    entry.set_resource(resource2.clone()).await;
    assert!(entry.is_active().await);
    assert_eq!(entry.get_resource().await, Some(resource2));
  }

  #[tokio::test]
  async fn test_edge_case_multiple_mark_failed_calls() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);

    entry.mark_initialization_failed(test_error()).await;
    assert!(entry.is_failed().await);

    // Second call should be ignored
    entry.mark_initialization_failed(test_error()).await;
    assert!(entry.is_failed().await);
  }

  #[tokio::test]
  async fn test_removal_time_precision() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource).await;

    let before_removal = Instant::now();
    entry.mark_for_removal().await;
    let after_removal = Instant::now();

    let removal_time = entry.removal_time().await.unwrap();
    assert!(removal_time >= before_removal);
    assert!(removal_time <= after_removal);
  }

  #[tokio::test]
  async fn test_string_id_type() {
    let entry = AsyncEntry::<TestResource, String>::new_initializing("test-id".to_string());
    assert_eq!(entry.id(), "test-id");
  }

  #[tokio::test]
  async fn test_debug_formatting() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let debug_str = format!("{:?}", entry.state().await);
    assert!(debug_str.contains("Initializing"));
  }

  #[tokio::test]
  async fn test_clone_behavior() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource.clone()).await;

    let cloned_resource = entry.get_resource().await;
    assert_eq!(cloned_resource, Some(resource));

    // Verify that get_resource returns a clone, not a reference
    let resource2 = entry.get_resource().await.unwrap();
    assert_eq!(resource2.data, "test data");
  }

  #[tokio::test]
  async fn test_clone_shares_state() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("shared state test");
    
    // Clone the entry
    let cloned_entry = entry.clone();
    
    // Both should have the same ID
    assert_eq!(entry.id(), cloned_entry.id());
    
    // Both should start in initializing state
    assert!(entry.is_initializing().await);
    assert!(cloned_entry.is_initializing().await);
    
    // Set resource on original entry
    entry.set_resource(resource.clone()).await;
    
    // Both entries should now be active and have the same resource
    assert!(entry.is_active().await);
    assert!(cloned_entry.is_active().await);
    assert_eq!(entry.get_resource().await, Some(resource.clone()));
    assert_eq!(cloned_entry.get_resource().await, Some(resource));
    
    // Mark for removal on cloned entry
    cloned_entry.mark_for_removal().await;
    
    // Both entries should be marked for removal
    assert!(entry.can_be_removed().await);
    assert!(cloned_entry.can_be_removed().await);
    
    // Reactivate through original entry
    entry.reactivate().await;
    
    // Both should be reactivated
    assert!(entry.is_active().await);
    assert!(cloned_entry.is_active().await);
  }

  #[tokio::test]
  async fn test_timeout_with_slow_operation() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);

    // Test that timeout works correctly with tokio::time::timeout
    let result = timeout(
      Duration::from_millis(50),
      entry.wait_for_initialization(Duration::from_millis(100)),
    )
    .await;

    // The timeout should trigger first
    assert!(result.is_err()); // timeout error
  }

  #[tokio::test]
  async fn test_multiple_reactivation_calls() {
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    let resource = TestResource::new("test data");
    entry.set_resource(resource.clone()).await;

    // Multiple reactivate calls on active resource
    let first_access = entry.last_access().await;
    tokio::time::sleep(Duration::from_millis(10)).await;

    entry.reactivate().await;
    let second_access = entry.last_access().await;
    assert!(second_access > first_access);

    entry.reactivate().await;
    let third_access = entry.last_access().await;
    assert!(third_access >= second_access);

    assert!(entry.is_active().await);
    assert_eq!(entry.get_resource().await, Some(resource));
  }

  // Now AsyncEntry is thread-safe, so we can test concurrent access directly
  #[tokio::test]
  async fn test_concurrent_operations() {
    use std::sync::Arc;

    let entry = Arc::new(AsyncEntry::<TestResource, u32>::new_initializing(42));
    let resource = TestResource::new("concurrent test");

    // Spawn multiple tasks that operate on the same entry
    let handles = (0..10)
      .map(|i| {
        let entry = Arc::clone(&entry);
        let resource = resource.clone();

        tokio::spawn(async move {
          match i % 4 {
            0 => {
              // Try to set resource
              if entry.is_initializing().await {
                entry.set_resource(resource).await;
              }
            },
            1 => {
              // Try to get resource
              let _resource = entry.get_resource().await;
            },
            2 => {
              // Try to reactivate
              entry.reactivate().await;
            },
            3 => {
              // Try to mark for removal
              entry.mark_for_removal().await;
            },
            _ => unreachable!(),
          }
        })
      })
      .collect::<Vec<_>>();

    // Wait for all tasks to complete
    for handle in handles {
      handle.await.unwrap();
    }

    // Entry should be in a valid state
    let is_valid_state = entry.is_initializing().await
      || entry.is_active().await
      || entry.is_failed().await
      || entry.can_be_removed().await;
    assert!(is_valid_state);
  }

  #[tokio::test]
  async fn test_concurrent_initialization_attempts() {
    use std::sync::atomic::{AtomicU32, Ordering};
    use std::sync::Arc;

    let entry = Arc::new(AsyncEntry::<TestResource, u32>::new_initializing(42));
    entry.mark_initialization_failed(test_error()).await; // Start from failed state

    let success_count = Arc::new(AtomicU32::new(0));
    let total_attempts = 20;

    let handles = (0..total_attempts)
      .map(|_| {
        let entry = Arc::clone(&entry);
        let success_count = Arc::clone(&success_count);

        tokio::spawn(async move {
          if entry.try_mark_initialization_start().await {
            success_count.fetch_add(1, Ordering::SeqCst);
          }
        })
      })
      .collect::<Vec<_>>();

    // Wait for all attempts
    for handle in handles {
      handle.await.unwrap();
    }

    // Only one should succeed in restarting initialization
    let final_count = success_count.load(Ordering::SeqCst);
    assert_eq!(final_count, 1);
    assert!(entry.is_initializing().await);
  }

  #[tokio::test]
  async fn test_first_initialization_attempt_returns_true() {
    // This test specifically verifies the fix for the issue where
    // the first call to try_mark_initialization_start should return true
    let entry = AsyncEntry::<TestResource, u32>::new_initializing(42);
    
    // Entry should be in initializing state but not yet claimed
    assert!(entry.is_initializing().await);
    
    // First call should return true (claiming initialization)
    let first_attempt = entry.try_mark_initialization_start().await;
    assert!(first_attempt, "First call to try_mark_initialization_start should return true");
    
    // Still in initializing state but now claimed
    assert!(entry.is_initializing().await);
    
    // Second call should return false (already claimed)
    let second_attempt = entry.try_mark_initialization_start().await;
    assert!(!second_attempt, "Second call should return false as initialization is already claimed");
    
    // Third call should also return false
    let third_attempt = entry.try_mark_initialization_start().await;
    assert!(!third_attempt, "Third call should also return false");
  }
}
