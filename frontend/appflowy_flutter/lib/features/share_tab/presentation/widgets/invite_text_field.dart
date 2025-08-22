import 'package:appflowy/features/mension_person/presentation/menu_extension.dart';
import 'package:appflowy/features/share_tab/data/models/share_access_level.dart';
import 'package:appflowy/features/share_tab/data/models/shared_user.dart';
import 'package:appflowy/features/share_tab/logic/email_suggestions.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
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
    required this.displayingUsers,
    required this.filterUsers,
    required this.onDataChanged,
    required this.isEmailInvited,
    this.showAccessLevelWidget = true,
  });

  final TextEditingController textController;
  final InviteController? controller;
  final bool readOnly;
  final List<SharedUser> displayingUsers;
  final OptionItemFilter<SharedUser> filterUsers;
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
      List.of(buildUsers(widget.displayingUsers).take(8));
  final popoverController = AFPopoverController();
  final List<OptionItem> selectedItems = [];
  final ScrollController horizontalScroller = ScrollController();
  final dropdownListController = AutoScrollController();
  final emailSuggestion = EmailSuggestions();

  late String text = textController.text;
  late String selectedId = widget.displayingUsers.isNotEmpty
      ? widget.displayingUsers.first.email
      : '';
  bool showEmailSuggestions = false, initialed = false;
  ShareAccessLevel selectedAccessLevel = ShareAccessLevel.readOnly;

  @override
  void initState() {
    textController.addListener(onTextChanged);
    widget.controller?._addListener(onInvite);

    if (!readOnly) {
      focusNode.makeSureHasFocus(() => !mounted).then((_) {
        focusNode.addListener(() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                displayingItems.isEmpty ||
                !focusNode.hasFocus ||
                !initialed) {
              initialed = true;
              return;
            }
            popoverController.show();
          });
        });
      });
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
      hintText:
          selectedItems.isEmpty ? LocaleKeys.shareTab_inviteByEmail.tr() : null,
      suffixIconConstraints: hasPrefixOrSuffix && widget.showAccessLevelWidget
          ? BoxConstraints.expand(width: 100, height: 24)
          : null,
      suffixIconBuilder: hasPrefixOrSuffix && widget.showAccessLevelWidget
          ? (context, isObscured) => buildEditAccessLevelWidget()
          : null,
      prefixIconConstraints:
          hasPrefixOrSuffix ? BoxConstraints(maxWidth: 200) : null,
      prefixIconBuilder:
          hasPrefixOrSuffix ? (context) => buildSelectedUsers() : null,
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

  Widget buildSelectedUsers() => HorizontalInvitingItems(
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

  List<UserOptionItem> buildUsers(SharedUsers users) =>
      users.map((p) => UserOptionItem(value: p)).toList();

  List<EmailSuggestionItem> buildEmailSuggestions(List<String> suggestions) =>
      suggestions.map((e) => EmailSuggestionItem(value: e)).toList();

  void onTextChanged() {
    if (text == textController.text) return;
    if (textController.text.contains(',')) {
      commaSeparatedEmails(textController.text);
    } else {
      updateDropdownList();
    }
    text = textController.text;
  }

  void updateDropdownList() {
    final text = textController.text;
    final query = text.trim().toLowerCase(),
        selectedIds = selectedItems.map((e) => e.id).toSet();
    final filterItems = widget
        .filterUsers(query)
        .where((e) => !selectedIds.contains(e.email))
        .toList();
    if (filterItems.isEmpty && query.isNotEmpty) {
      final suggestions = emailSuggestion
          .generateEmails(query)
          .where((e) => !selectedIds.contains(e))
          .toList();
      if (suggestions.isNotEmpty) {
        showEmailSuggestions = true;
        update(
          selectedId: suggestions.first,
          displayingItems: buildEmailSuggestions(suggestions),
        );
      } else {
        update(selectedId: '', displayingItems: []);
      }
    } else if (filterItems.isNotEmpty) {
      showEmailSuggestions = false;
      update(
        selectedId: filterItems.first.email,
        displayingItems: buildUsers(filterItems),
      );
    } else {
      update(selectedId: '', displayingItems: []);
    }
  }

  void commaSeparatedEmails(String text) {
    final selectedEmails = selectedItems.map((e) => e.id).toSet();
    final emails = text.split(',').map((e) => e.trim()).where(
          (e) =>
              !widget.isEmailInvited(e) &&
              !selectedEmails.contains(e) &&
              isEmail(e),
        );
    if (emails.isNotEmpty) {
      final newSelectedItems = List.of(selectedItems);
      final displayingItemMap = <String, OptionItem>{};
      for (final item in buildUsers(widget.displayingUsers)) {
        displayingItemMap[item.id] = item;
      }
      for (final email in emails) {
        final item =
            displayingItemMap[email] ?? EmailSuggestionItem(value: email);
        newSelectedItems.add(item);
      }
      update(
        selectedItems: newSelectedItems,
        displayingItems: [],
      );
      _scrollToEnd();
    }
    textController.clear();
  }

  void update({
    String? selectedId,
    List<OptionItem>? selectedItems,
    List<OptionItem>? displayingItems,
  }) {
    final needRefresh =
        selectedId != null || selectedItems != null || displayingItems != null;
    if (needRefresh && mounted) {
      setState(() {
        if (selectedId != null) {
          this.selectedId = selectedId;
        }
        if (selectedItems != null) {
          this.selectedItems.clear();
          this.selectedItems.addAll(selectedItems);
          widget.onDataChanged.call(
            buildEmailsWithAccessLevel(selectedItems, selectedAccessLevel),
          );
        }
        if (displayingItems != null) {
          this.displayingItems.clear();
          this.displayingItems.addAll(displayingItems.take(8));
          if (displayingItems.isEmpty) {
            popoverController.hide();
          } else {
            popoverController.show();
          }
        }
      });
    }
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
      update(selectedId: displayingItems[newIndex].id);
      scrollTo(newIndex);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      int newIndex = 0;
      if (index > 0) {
        newIndex = index - 1;
      } else if (index <= 0) {
        newIndex = displayingItems.length - 1;
      }
      update(selectedId: displayingItems[newIndex].id);
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
    update(selectedItems: newItems);
    updateDropdownList();
  }

  void onItemSelected(OptionItem item) {
    final newSelectedItems = List.of(selectedItems);
    if (item is UserOptionItem) {
      final user = item.value;
      if (newSelectedItems.any((e) => e.id == user.email)) {
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
    update(selectedItems: newSelectedItems);
    textController.clear();
    updateDropdownList();
    focusNode.makeSureHasFocus(() => !mounted);

    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!horizontalScroller.hasClients || !mounted) return;
      horizontalScroller.animateTo(
        horizontalScroller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
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
      } else if (item is UserOptionItem) {
        emails.add(item.value.email);
      }
    }
    return EmailsWithAccessLevel(emails: emails, accessLevel: accessLevel);
  }
}
