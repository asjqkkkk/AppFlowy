import 'package:appflowy/features/shared_section/models/shared_page.dart';
import 'package:collection/collection.dart';

class SharedSectionState {
  factory SharedSectionState.initial() => const SharedSectionState();

  const SharedSectionState({
    this.sharedPages = const [],
    this.isLoading = false,
    this.errorMessage = '',
    this.isExpanded = true,
    this.noAccessViewIds = const [],
  });

  final SharedPages sharedPages;
  final bool isLoading;
  final String errorMessage;
  final bool isExpanded;
  final List<String> noAccessViewIds;

  SharedSectionState copyWith({
    SharedPages? sharedPages,
    bool? isLoading,
    String? errorMessage,
    bool? isExpanded,
    List<String>? noAccessViewIds,
  }) {
    return SharedSectionState(
      sharedPages: sharedPages ?? this.sharedPages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isExpanded: isExpanded ?? this.isExpanded,
      noAccessViewIds: noAccessViewIds ?? this.noAccessViewIds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedSectionState &&
        DeepCollectionEquality().equals(other.sharedPages, sharedPages) &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage &&
        other.isExpanded == isExpanded &&
        DeepCollectionEquality().equals(other.noAccessViewIds, noAccessViewIds);
  }

  @override
  int get hashCode {
    return Object.hash(
      sharedPages,
      isLoading,
      errorMessage,
      isExpanded,
      noAccessViewIds,
    );
  }

  @override
  String toString() {
    return 'SharedSectionState(sharedPages: $sharedPages, noAccessViewIds: $noAccessViewIds, isLoading: $isLoading, errorMessage: $errorMessage, isExpanded: $isExpanded)';
  }
}
