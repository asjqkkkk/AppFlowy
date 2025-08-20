import 'package:appflowy/features/mension_person/presentation/menu_extension.dart';
import 'package:appflowy/features/share_tab/data/models/share_access_level.dart';
import 'package:appflowy/features/share_tab/logic/email_suggestions.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:string_validator/string_validator.dart';

import 'access_level_list_widget.dart';
import 'edit_access_level_widget.dart';
import 'invite_text_field_popover.dart';
import 'inviting_item.dart';

typedef OptionItemFilter<T> = List<T> Function(String query);

class EmailsWithAccessLevel {
  EmailsWithAccessLevel({required this.emails, required this.accessLevel});

  final List<String> emails;
  final ShareAccessLevel accessLevel;
}

class InviteController {
  final Set<VoidCallback> _inviteListeners = {};

  void onInvite() {
    for (final listener in Set.of(_inviteListeners)) {
      listener.call();
    }
  }

  void _addListener(VoidCallback listener) {
    _inviteListeners.add(listener);
  }

  void _removeListener(VoidCallback listener) {
    _inviteListeners.remove(listener);
  }

  void dispose() {
    _inviteListeners.clear();
  }
}

class InviteTextField extends StatefulWidget {
  const InviteTextField({
    super.key,
    this.controller,
    required this.textController,
    required this.readOnly,
    required this.persons,
    required this.filterPersons,
    required this.onDataChanged,
    required this.isEmailInvited,
    this.showAccessLevelWidget = true,
  });

  final TextEditingController textController;
  final InviteController? controller;
  final bool readOnly;
  final List<MentionablePersonPB> persons;
  final OptionItemFilter<MentionablePersonPB> filterPersons;
  final ValueChanged<EmailsWithAccessLevel> onDataChanged;
  final bool Function(String email) isEmailInvited;
  final bool showAccessLevelWidget;

  @override
  State<InviteTextField> createState() => _InviteTextFieldState();
}

class _InviteTextFieldState extends State<InviteTextField> {
  TextEditingController get textController => widget.textController;
  bool get readOnly => widget.readOnly;

  late final FocusNode focusNode = FocusNode(onKeyEvent: onKeyEvent);
  late final List<OptionItem> displayingItems =
      List.of(buildPersons(widget.persons));
  final popoverController = AFPopoverController();
  final List<OptionItem> selectedItems = [];
  final ScrollController horizontalScroller = ScrollController();
  final dropdownListController = AutoScrollController();
  final emailSuggestion = EmailSuggestions();

  late String text = textController.text;
  late String selectedId =
      widget.persons.isNotEmpty ? widget.persons.first.uuid : '';
  bool showEmailSuggestions = false;
  ShareAccessLevel selectedAccessLevel = ShareAccessLevel.readOnly;

  @override
  void initState() {
    textController.addListener(onTextChanged);
    widget.controller?._addListener(onInvite);
    if (!widget.readOnly) {
      focusNode.addListener(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || displayingItems.isEmpty || !focusNode.hasFocus) {
            return;
          }
          popoverController.show();
        });
      });
      focusNode.makeSureHasFocus(() => !mounted);
    }
    super.initState();
  }

  @override
  void dispose() {
    textController.removeListener(onTextChanged);
    widget.controller?._removeListener(onInvite);
    focusNode.dispose();
    popoverController.dispose();
    horizontalScroller.dispose();
    dropdownListController.dispose();
    displayingItems.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constrains) {
        final width = constrains.maxWidth;
        return AFPopover(
          padding: EdgeInsets.zero,
          controller: popoverController,
          popover: (context) => buildPopover(width, context),
          child: buildTextField(),
        );
      },
    );
  }

  Widget buildTextField() {
    final hasPrefixOrSuffix = selectedItems.isNotEmpty;
    return AFTextField(
      controller: textController,
      focusNode: focusNode,
      size: AFTextFieldSize.m,
      readOnly: readOnly,
      hintText: LocaleKeys.shareTab_inviteByEmail.tr(),
      suffixIconConstraints: hasPrefixOrSuffix && widget.showAccessLevelWidget
          ? BoxConstraints.expand(width: 100, height: 24)
          : null,
      suffixIconBuilder: hasPrefixOrSuffix && widget.showAccessLevelWidget
          ? (context, isObscured) => buildEditAccessLevelWidget()
          : null,
      prefixIconConstraints:
          hasPrefixOrSuffix ? BoxConstraints(maxWidth: 200) : null,
      prefixIconBuilder:
          hasPrefixOrSuffix ? (context) => buildSelectedPersons() : null,
      onSubmitted: (value) {},
    );
  }

  Widget buildEditAccessLevelWidget() {
    final theme = AppFlowyTheme.of(context), spacing = theme.spacing;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 24,
        child: EditAccessLevelWidget(
          selectedAccessLevel: selectedAccessLevel,
          padding: EdgeInsets.symmetric(horizontal: spacing.m),
          suffixIcon: FlowySvg(
            FlowySvgs.toolbar_arrow_down_m,
            color: theme.textColorScheme.secondary,
          ),
          supportedAccessLevels: [
            ShareAccessLevel.readOnly,
            ShareAccessLevel.readAndWrite,
          ],
          additionalUserManagementOptions: [],
          callbacks: AccessLevelListCallbacks.none().copyWith(
            onSelectAccessLevel: (v) {
              setState(() {
                selectedAccessLevel = v;
              });
              widget.onDataChanged.call(
                buildEmailsWithAccessLevel(selectedItems, selectedAccessLevel),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildSelectedPersons() => HorizontalInvitingItems(
        items: selectedItems,
        onItemRemoved: onItemRemoved,
        controller: horizontalScroller,
      );

  Widget buildPopover(double width, BuildContext context) {
    return InviteTextFieldPopover(
      maxWidth: width,
      items: displayingItems,
      controller: dropdownListController,
      selectedId: selectedId,
      title: showEmailSuggestions
          ? LocaleKeys.shareTab_dropdownMenu_keepTyping.tr()
          : LocaleKeys.shareTab_dropdownMenu_notInvitedToPage.tr(),
      onItemSelected: (item) => onItemSelected(item),
    );
  }

  List<PersonOptionItem> buildPersons(List<MentionablePersonPB> persons) =>
      persons.map((p) => PersonOptionItem(value: p)).toList();

  List<EmailSuggestionItem> buildEmailSuggestions(List<String> suggestions) =>
      suggestions.map((e) => EmailSuggestionItem(value: e)).toList();

  void onTextChanged() {
    if (text == textController.text) return;
    updateDropdownList();
  }

  void updateDropdownList() {
    final text = textController.text;
    this.text = text;
    final query = text.trim().toLowerCase(),
        selectedIds = selectedItems.map((e) => e.id).toSet();
    final filterItems = widget
        .filterPersons(query)
        .where((e) => !selectedIds.contains(e.uuid))
        .toList();
    if (filterItems.isEmpty && query.isNotEmpty) {
      final suggestions = emailSuggestion.generateEmails(query);
      if (suggestions.isNotEmpty) {
        showEmailSuggestions = true;
        updateSelectedId(suggestions.first);
        updateDisplayingItems(buildEmailSuggestions(suggestions));
      } else {
        Log.error('No email suggestions found for query: $query');
      }
    } else if (filterItems.isNotEmpty) {
      showEmailSuggestions = false;
      updateSelectedId(filterItems.first.uuid);
      updateDisplayingItems(buildPersons(filterItems));
    } else {
      updateSelectedId('');
      updateDisplayingItems([]);
    }
  }

  void updateDisplayingItems(List<OptionItem> items) {
    if (!mounted) return;
    setState(() {
      displayingItems.clear();
      displayingItems.addAll(items);
    });
    if (items.isEmpty) {
      popoverController.hide();
    } else {
      popoverController.show();
    }
  }

  void updateSelectedId(String id) {
    if (!mounted) return;
    setState(() {
      selectedId = id;
    });
  }

  void updateSelectedItems(List<OptionItem> items) {
    if (!mounted) return;
    setState(() {
      selectedItems.clear();
      selectedItems.addAll(items);
      widget.onDataChanged
          .call(buildEmailsWithAccessLevel(items, selectedAccessLevel));
    });
  }

  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final index = displayingItems.indexWhere((e) => e.id == selectedId);
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      int newIndex = 0;
      if (index < 0 || index == displayingItems.length - 1) {
        newIndex = 0;
      } else {
        newIndex = index + 1;
      }
      updateSelectedId(displayingItems[newIndex].id);
      scrollTo(newIndex);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      int newIndex = 0;
      if (index > 0) {
        newIndex = index - 1;
      } else if (index <= 0) {
        newIndex = displayingItems.length - 1;
      }
      updateSelectedId(displayingItems[newIndex].id);
      scrollTo(newIndex);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (!popoverController.isOpen) return KeyEventResult.ignored;
      if (index < 0) return KeyEventResult.ignored;
      onItemSelected(displayingItems[index]);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (textController.text.isEmpty && selectedItems.isNotEmpty) {
        onItemRemoved(selectedItems.last);
        _scrollToEnd();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void scrollTo(int index) {
    dropdownListController.scrollToIndex(
      index,
      duration: const Duration(milliseconds: 50),
      preferPosition: AutoScrollPosition.middle,
    );
  }

  void onItemRemoved(OptionItem item) {
    final newItems = List.of(selectedItems);
    newItems.remove(item);
    updateSelectedItems(newItems);
    updateDropdownList();
  }

  void onItemSelected(OptionItem item) {
    final newSelectedItems = List.of(selectedItems);
    if (item is PersonOptionItem) {
      final person = item.value;
      if (newSelectedItems.any((e) => e.id == person.uuid)) {
        showToastNotification(
          type: ToastificationType.error,
          message: LocaleKeys.shareTab_personAlreadyInList.tr(),
        );
        return;
      }
      newSelectedItems.add(item);
    } else if (item is EmailSuggestionItem) {
      final email = item.value;
      if (email.isEmpty ||
          newSelectedItems.any((e) => e.id == email) ||
          widget.isEmailInvited(email)) {
        showToastNotification(
          type: ToastificationType.error,
          message: LocaleKeys.shareTab_emailAlreadyInList.tr(),
        );
        return;
      }

      if (!isEmail(email)) {
        showToastNotification(
          type: ToastificationType.error,
          message: LocaleKeys.document_mentionMenu_emailInputError.tr(),
        );
        return;
      }
      newSelectedItems.add(item);
    }
    updateSelectedItems(newSelectedItems);
    textController.clear();
    updateDropdownList();
    focusNode.makeSureHasFocus(() => !mounted);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    if (!horizontalScroller.hasClients || !mounted) return;
    horizontalScroller.animateTo(
      horizontalScroller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void onInvite() {
    if (!mounted) return;
    setState(() {
      selectedItems.clear();
      widget.onDataChanged
          .call(buildEmailsWithAccessLevel([], selectedAccessLevel));
      focusNode.unfocus();
    });
  }

  EmailsWithAccessLevel buildEmailsWithAccessLevel(
    List<OptionItem> items,
    ShareAccessLevel accessLevel,
  ) {
    final List<String> emails = [];
    for (final item in items) {
      if (item is EmailSuggestionItem) {
        emails.add(item.value);
      } else if (item is PersonOptionItem) {
        emails.add(item.value.email);
      }
    }
    return EmailsWithAccessLevel(emails: emails, accessLevel: accessLevel);
  }
}
