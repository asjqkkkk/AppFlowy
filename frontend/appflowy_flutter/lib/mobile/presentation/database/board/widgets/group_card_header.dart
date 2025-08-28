import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_quick_action_button.dart';
import 'package:appflowy/plugins/database/application/field/type_option/type_option_data_parser.dart';
import 'package:appflowy/plugins/database/board/application/board_bloc.dart';
import 'package:appflowy/util/field_type_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// similar to [BoardColumnHeader] in Desktop
class GroupCardHeader extends StatefulWidget {
  const GroupCardHeader({
    super.key,
    required this.groupData,
  });

  final AppFlowyGroupData groupData;

  @override
  State<GroupCardHeader> createState() => _GroupCardHeaderState();
}

class _GroupCardHeaderState extends State<GroupCardHeader> {
  final textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    textController.text = getGroupOption()?.name ?? '';
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardCustomData = widget.groupData.customData as GroupData;
    final titleTextStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontWeight: FontWeight.w600,
        );

    return BlocBuilder<BoardBloc, BoardState>(
      builder: (context, state) {
        final boardBloc = context.read<BoardBloc>();

        Widget title = Text(
          widget.groupData.headerData.groupName,
          style: titleTextStyle,
          overflow: TextOverflow.ellipsis,
        );

        // header can be edited if it's not default group(no status) and the field type can be edited
        if (!boardCustomData.group.isDefault &&
            boardCustomData.fieldType.canEditHeader) {
          final option = getGroupOption(
          );
          if (option != null) {
            title = GestureDetector(
              onTap: () {
                boardBloc.add(
                  BoardEvent.startEditingHeader(widget.groupData.id),
                );
              },
              child: Text(
                option.name,
                style: titleTextStyle,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }
        }

        final isEditing = state.maybeMap(
          ready: (value) => value.editingHeaderId == widget.groupData.id,
          orElse: () => false,
        );

        if (isEditing) {
          title = TextField(
            controller: textController,
            autofocus: true,
            onEditingComplete: () => boardBloc.add(
              BoardEvent.endEditingHeader(
                widget.groupData.id,
                null,
              ),
            ),
            style: titleTextStyle,
            onTapOutside: (_) => boardBloc.add(
              BoardEvent.endEditingHeader(
                widget.groupData.id,
                textController.text,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16),
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                _buildHeaderIcon(boardCustomData),
                Expanded(child: title),
                IconButton(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  splashRadius: 5,
                  onPressed: () => showMobileBottomSheet(
                    context,
                    showDragHandle: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    builder: (_) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MobileQuickActionButton(
                          text: LocaleKeys.board_column_renameColumn.tr(),
                          icon: FlowySvgs.edit_s,
                          onTap: () {
                            context.read<BoardBloc>().add(
                                  BoardEvent.startEditingHeader(
                                    widget.groupData.id,
                                  ),
                                );
                            context.pop();
                          },
                        ),
                        const MobileQuickActionDivider(),
                        MobileQuickActionButton(
                          text: LocaleKeys.board_column_hideColumn.tr(),
                          icon: FlowySvgs.hide_s,
                          onTap: () {
                            context.read<BoardBloc>().add(
                                  BoardEvent.setGroupVisibility(
                                    widget.groupData.customData.group
                                        as GroupPB,
                                    false,
                                  ),
                                );
                            context.pop();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  splashRadius: 5,
                  onPressed: () {
                    context.read<BoardBloc>().add(
                          BoardEvent.createRow(
                            widget.groupData.id,
                            OrderObjectPositionTypePB.Start,
                            null,
                            null,
                          ),
                        );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderIcon(GroupData customData) =>
      switch (customData.fieldType) {
        FieldType.Checkbox => FlowySvg(
            customData.asCheckboxGroup()!.isCheck
                ? FlowySvgs.check_filled_s
                : FlowySvgs.uncheck_s,
            blendMode: BlendMode.dst,
          ),
        _ => const SizedBox.shrink(),
      };

  SelectOptionPB? getGroupOption(
  ) {
    final databaseController = context.read<BoardBloc>().databaseController;
    final groupId = widget.groupData.id;
    final customData = widget.groupData.customData as GroupData;
    final fieldId = customData.fieldInfo.id;
    final field = databaseController.fieldController.getField(fieldId);
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
