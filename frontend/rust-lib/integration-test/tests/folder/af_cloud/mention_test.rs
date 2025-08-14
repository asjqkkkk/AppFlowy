use crate::util::{create_2_clients, receive_with_timeout};
use event_integration_test::user_event::use_localhost_af_cloud;
use flowy_folder::entities::GetMentionablePersonsResponsePB;
use std::time::Duration;

#[tokio::test]
async fn mention_person_list_order_test() {
  use_localhost_af_cloud().await;

  let (client_1, client_2) = create_2_clients().await;
  let workspace = client_1.get_current_workspace().await.id;
  let client_1_email = client_1.get_email().await;
  let client_2_email = client_2.get_email().await;

  let persons = client_1.get_workspace_mentionable_persons().await;
  assert_eq!(persons.len(), 1);
  assert_eq!(persons[0].email, client_1_email);

  client_1.add_workspace_member(&workspace, &client_2).await;
  tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;

  let persons = client_1.get_workspace_mentionable_persons().await;

  // No local cache, so it will fetch from the server and send a notification
  assert_eq!(persons.len(), 2);
  let cloned_client_1_email = client_1_email.clone();
  let cloned_client_2_email = client_2_email.clone();
  let rx = client_1
    .notification_sender
    .subscribe_with_condition::<GetMentionablePersonsResponsePB, _>(&workspace, move |pb| {
      dbg!(&persons);
      assert_eq!(pb.persons.len(), 2);
      assert_eq!(pb.persons[0].email, cloned_client_2_email);
      assert_eq!(pb.persons[1].email, cloned_client_1_email);
      true
    });
  let _ = receive_with_timeout(rx, Duration::from_secs(30)).await;

  // remove the member
  client_1
    .delete_workspace_member(&workspace, &client_2_email)
    .await;

  let _ = client_1.get_workspace_mentionable_persons().await;
  // We return the disk cache first, so it might still show 2 people.
  // However, a WebSocket notification will also remove the member from the list,q
  // so the member may or may not appear initially.
  // The `get_workspace_mentionable_persons` function will trigger a background fetch,
  // and the list will eventually update to show only 1 person.
  let rx = client_1
    .notification_sender
    .subscribe_with_condition::<GetMentionablePersonsResponsePB, _>(&workspace, move |pb| {
      dbg!(&pb);
      assert_eq!(pb.persons.len(), 1);
      assert_eq!(pb.persons[1].email, client_1_email);
      true
    });
  let _ = receive_with_timeout(rx, Duration::from_secs(30)).await;
}
