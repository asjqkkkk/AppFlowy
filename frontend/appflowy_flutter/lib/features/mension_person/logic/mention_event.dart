import 'package:appflowy/features/mension_person/data/models/models.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';

sealed class MentionEvent {
  const MentionEvent();
  const factory MentionEvent.init() = Initial;
  const factory MentionEvent.getPersons({required String workspaceId}) =
      GetPersons;
  const factory MentionEvent.updatePersonList(
    List<MentionablePersonPB> persons,
  ) = UpdatePersonList;
  const factory MentionEvent.query(String text) = Query;
  const factory MentionEvent.showMorePersons(String lastId) = ShowMorePersons;
  const factory MentionEvent.showMorePages(String lastId) = ShowMorePages;
  const factory MentionEvent.toggleSendNotification() = ToggleSendNotification;
  const factory MentionEvent.addVisibleItem(String id) = AddVisibleItem;
  const factory MentionEvent.removeVisibleItem(String id) = RemoveVisibleItem;
  const factory MentionEvent.selectItem(String id) = SelectItem;

  const factory MentionEvent.updateViews(List<ViewPB> views) = UpdateViews;
  const factory MentionEvent.executeItem(MentionMenuItem item) = ExecuteItem;
  const factory MentionEvent.mentionPerson({
    required String documentId,
    required String personId,
    required String ancestorId,
    String? blockId,
  }) = MentionPerson;
  const factory MentionEvent.reloadPersons(List<MentionablePersonPB> persons) =
      ReloadPersonsEvent;
}

class Initial implements MentionEvent {
  const Initial();
}

class GetPersons implements MentionEvent {
  const GetPersons({required this.workspaceId});

  final String workspaceId;
}

class GetPersonsWithAccess implements MentionEvent {
  const GetPersonsWithAccess({
    required this.workspaceId,
    required this.documentId,
  });

  final String workspaceId;
  final String documentId;
}

class UpdatePersonList implements MentionEvent {
  const UpdatePersonList(this.persons);

  final List<MentionablePersonPB> persons;
}

class UpdateViews implements MentionEvent {
  const UpdateViews(this.views);

  final List<ViewPB> views;
}

class Query implements MentionEvent {
  const Query(this.text);

  final String text;
}

class ShowMorePersons implements MentionEvent {
  const ShowMorePersons(this.lastId);

  final String lastId;
}

class ShowMorePages implements MentionEvent {
  const ShowMorePages(this.lastId);

  final String lastId;
}

class ToggleSendNotification implements MentionEvent {
  const ToggleSendNotification();
}

class AddVisibleItem implements MentionEvent {
  const AddVisibleItem(this.id);

  final String id;
}

class RemoveVisibleItem implements MentionEvent {
  const RemoveVisibleItem(this.id);

  final String id;
}

class SelectItem implements MentionEvent {
  const SelectItem(this.id);

  final String id;
}

class ExecuteItem implements MentionEvent {
  const ExecuteItem(this.item);

  final MentionMenuItem item;
}

class MentionPerson implements MentionEvent {
  const MentionPerson({
    required this.documentId,
    required this.personId,
    required this.ancestorId,
    this.blockId,
  });

  final String documentId;
  final String personId;
  final String? blockId;
  final String ancestorId;
}

class ReloadPersonsEvent implements MentionEvent {
  const ReloadPersonsEvent(this.persons);

  final List<MentionablePersonPB> persons;
}
