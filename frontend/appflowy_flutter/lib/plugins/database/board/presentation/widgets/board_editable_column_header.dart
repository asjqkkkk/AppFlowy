import 'package:appflowy/plugins/database/application/database_controller.dart';
import 'package:appflowy/plugins/database/application/field/type_option/type_option_data_parser.dart';
import 'package:appflowy/plugins/database/board/application/board_bloc.dart';
import 'package:appflowy/plugins/database/widgets/field/type_option_editor/select/select_option_editor.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:collection/collection.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'board_column_header.dart';

/// This column header is used for the MultiSelect and SingleSelect field types.
class EditableColumnHeader extends StatefulWidget {
  const EditableColumnHeader({
    super.key,
    required this.databaseController,
    required this.groupData,
    required this.isEditing,
    required this.onSubmitted,
  });

  final DatabaseController databaseController;
  final AppFlowyGroupData groupData;
  final ValueNotifier<bool> isEditing;
  final void Function(String columnName) onSubmitted;

  @override
  State<EditableColumnHeader> createState() => _EditableColumnHeaderState();
}

class _EditableColumnHeaderState extends State<EditableColumnHeader> {
  late final FocusNode focusNode;
  late final TextEditingController textController;

  GroupData get customData => widget.groupData.customData;

  @override
  void initState() {
    super.initState();
    final option = _getGroupOption();
    textController = TextEditingController(text: option?.name ?? '');
    focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape &&
            event is KeyUpEvent) {
          focusNode.unfocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    )..addListener(onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant oldWidget) {
    if (oldWidget.groupData.customData != widget.groupData.customData) {
      final option = _getGroupOption();
      textController.text = option?.name ?? '';
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    focusNode
      ..removeListener(onFocusChanged)
      ..dispose();
    textController.dispose();
    super.dispose();
  }

  void onFocusChanged() {
    if (!focusNode.hasFocus) {
      widget.isEditing.value = false;
      widget.onSubmitted(textController.text);
    } else {
      textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: textController.text.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: widget.isEditing,
            builder: (context, isEditing, _) {
              if (isEditing) {
                focusNode.requestFocus();
              }
              return isEditing ? _buildTextField() : _buildTitle();
            },
          ),
        ),
        const HSpace(6),
        GroupOptionsButton(
          groupData: widget.groupData,
          isEditing: widget.isEditing,
        ),
        const HSpace(4),
        CreateCardFromTopButton(
          groupId: widget.groupData.id,
        ),
      ],
    );
  }

  Widget _buildTitle() {
    final option = _getGroupOption();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.isEditing.value = true;
        },
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FlowyTooltip(
            message: option?.name,
            child: SelectOptionTag(
              option: option,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: textController,
      focusNode: focusNode,
      onEditingComplete: () {
        widget.isEditing.value = false;
      },
      onSubmitted: widget.onSubmitted,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        hoverColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        isDense: true,
      ),
    );
  }

  SelectOptionPB? _getGroupOption() {
    final groupId = widget.groupData.id;
    final fieldId = customData.fieldInfo.id;
    final field = widget.databaseController.fieldController.getField(fieldId);
    if (field == null) {
      return null;
    }

    final selectOptions = switch (field.fieldType) {
      FieldType.MultiSelect => MultiSelectTypeOptionDataParser()
          .fromBuffer(field.field.typeOptionData)
          .options,
      FieldType.SingleSelect => SingleSelectTypeOptionDataParser()
          .fromBuffer(field.field.typeOptionData)
          .options,
      _ => <SelectOptionPB>[],
    };

    return selectOptions.firstWhereOrNull((e) => e.id == groupId);
  }
}
