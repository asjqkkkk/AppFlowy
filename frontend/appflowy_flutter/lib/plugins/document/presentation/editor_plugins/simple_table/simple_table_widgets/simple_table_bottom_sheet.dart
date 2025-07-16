import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/show_mobile_bottom_sheet.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/base/string_extension.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mobile_toolbar_v3/aa_menu/_toolbar_theme.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/simple_table/simple_table.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/simple_table/simple_table_widgets/_simple_table_bottom_sheet_actions.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

import '../../base/font_colors.dart';

enum _SimpleTableBottomSheetMenuState {
  cellActionMenu,
  textColor,
  textBackgroundColor,
  tableActionMenu,
  align,
}

/// This bottom sheet is used for the column or row action menu.
/// When selecting a cell and tapping the action menu button around the cell,
/// this bottom sheet will be shown.
///
/// Note: This widget is only used for mobile.
class SimpleTableCellBottomSheet extends StatefulWidget {
  const SimpleTableCellBottomSheet({
    super.key,
    required this.type,
    required this.cellNode,
    required this.editorState,
    this.scrollController,
  });

  final SimpleTableMoreActionType type;
  final Node cellNode;
  final EditorState editorState;
  final ScrollController? scrollController;

  @override
  State<SimpleTableCellBottomSheet> createState() =>
      _SimpleTableCellBottomSheetState();
}

class _SimpleTableCellBottomSheetState
    extends State<SimpleTableCellBottomSheet> {
  _SimpleTableBottomSheetMenuState menuState =
      _SimpleTableBottomSheetMenuState.cellActionMenu;

  Color? selectedTextColor;
  Color? selectedCellBackgroundColor;
  TableAlign? selectedAlign;

  @override
  void initState() {
    super.initState();

    selectedTextColor = switch (widget.type) {
      SimpleTableMoreActionType.column =>
        widget.cellNode.textColorInColumn?.tryToColor(),
      SimpleTableMoreActionType.row =>
        widget.cellNode.textColorInRow?.tryToColor(),
    };

    selectedCellBackgroundColor = switch (widget.type) {
      SimpleTableMoreActionType.column =>
        widget.cellNode.buildColumnColor(context),
      SimpleTableMoreActionType.row => widget.cellNode.buildRowColor(context),
    };

    selectedAlign = switch (widget.type) {
      SimpleTableMoreActionType.column => widget.cellNode.columnAlign,
      SimpleTableMoreActionType.row => widget.cellNode.rowAlign,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header
        _buildHeader(),

        // content
        ...menuState == _SimpleTableBottomSheetMenuState.cellActionMenu
            ? _buildScrollableContent()
            : _buildNonScrollableContent(),
      ],
    );
  }

  Widget _buildHeader() {
    switch (menuState) {
      case _SimpleTableBottomSheetMenuState.cellActionMenu:
        return BottomSheetHeader(
          showBackButton: false,
          showCloseButton: true,
          showDoneButton: false,
          showRemoveButton: false,
          title: widget.type.name.capitalize(),
          onClose: () => Navigator.pop(context),
        );
      case _SimpleTableBottomSheetMenuState.textColor ||
            _SimpleTableBottomSheetMenuState.textBackgroundColor:
        return BottomSheetHeader(
          showBackButton: false,
          showCloseButton: true,
          showDoneButton: true,
          showRemoveButton: false,
          title: widget.type.name.capitalize(),
          onClose: () => setState(() {
            menuState = _SimpleTableBottomSheetMenuState.cellActionMenu;
          }),
          onDone: (_) => Navigator.pop(context),
        );
      default:
        throw UnimplementedError('Unsupported menu state: $menuState');
    }
  }

  List<Widget> _buildScrollableContent() {
    return [
      SizedBox(
        height: SimpleTableConstants.actionSheetBottomSheetHeight,
        child: Scrollbar(
          controller: widget.scrollController,
          child: SingleChildScrollView(
            controller: widget.scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildContent(),

                // safe area padding
                VSpace(context.bottomSheetPadding() * 2),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildNonScrollableContent() {
    return [
      ..._buildContent(),

      // safe area padding
      VSpace(context.bottomSheetPadding()),
    ];
  }

  List<Widget> _buildContent() {
    switch (menuState) {
      case _SimpleTableBottomSheetMenuState.cellActionMenu:
        return _buildActionButtons();
      case _SimpleTableBottomSheetMenuState.textColor:
        return _buildTextColor();
      case _SimpleTableBottomSheetMenuState.textBackgroundColor:
        return _buildTextBackgroundColor();
      default:
        throw UnimplementedError('Unsupported menu state: $menuState');
    }
  }

  List<Widget> _buildActionButtons() {
    return [
      // copy, cut, paste, delete
      SimpleTableCellQuickActions(
        type: widget.type,
        cellNode: widget.cellNode,
        editorState: widget.editorState,
      ),
      const VSpace(12),

      // insert row, insert column
      SimpleTableInsertActions(
        type: widget.type,
        cellNode: widget.cellNode,
        editorState: widget.editorState,
      ),
      const VSpace(12),

      // content actions
      SimpleTableContentActions(
        type: widget.type,
        cellNode: widget.cellNode,
        editorState: widget.editorState,
        selectedAlign: selectedAlign,
        selectedTextColor: selectedTextColor,
        selectedCellBackgroundColor: selectedCellBackgroundColor,
        onTextColorSelected: () {
          setState(() {
            menuState = _SimpleTableBottomSheetMenuState.textColor;
          });
        },
        onCellBackgroundColorSelected: () {
          setState(() {
            menuState = _SimpleTableBottomSheetMenuState.textBackgroundColor;
          });
        },
        onAlignTap: _onAlignTap,
      ),
      const VSpace(16),

      // action buttons
      SimpleTableCellActionButtons(
        type: widget.type,
        cellNode: widget.cellNode,
        editorState: widget.editorState,
      ),
    ];
  }

  List<Widget> _buildTextColor() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
        ),
        child: FlowyText(
          LocaleKeys.document_plugins_simpleTable_moreActions_textColor.tr(),
          fontSize: 14.0,
        ),
      ),
      const VSpace(12.0),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8.0,
        ),
        child: EditorTextColorWidget(
          onSelectedColor: _onTextColorSelected,
          selectedColor: selectedTextColor,
        ),
      ),
    ];
  }

  List<Widget> _buildTextBackgroundColor() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
        ),
        child: FlowyText(
          LocaleKeys
              .document_plugins_simpleTable_moreActions_cellBackgroundColor
              .tr(),
          fontSize: 14.0,
        ),
      ),
      const VSpace(12.0),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8.0,
        ),
        child: EditorBackgroundColors(
          onSelectedColor: _onCellBackgroundColorSelected,
          selectedColor: selectedCellBackgroundColor,
        ),
      ),
    ];
  }

  void _onTextColorSelected(Color color) {
    final hex = color.a == 0 ? null : color.toHex();
    switch (widget.type) {
      case SimpleTableMoreActionType.column:
        widget.editorState.updateColumnTextColor(
          tableCellNode: widget.cellNode,
          color: hex ?? '',
        );
      case SimpleTableMoreActionType.row:
        widget.editorState.updateRowTextColor(
          tableCellNode: widget.cellNode,
          color: hex ?? '',
        );
    }

    setState(() {
      selectedTextColor = color;
    });
  }

  void _onCellBackgroundColorSelected(Color color) {
    final hex = color.a == 0 ? null : color.toHex();
    switch (widget.type) {
      case SimpleTableMoreActionType.column:
        widget.editorState.updateColumnBackgroundColor(
          tableCellNode: widget.cellNode,
          color: hex ?? '',
        );
      case SimpleTableMoreActionType.row:
        widget.editorState.updateRowBackgroundColor(
          tableCellNode: widget.cellNode,
          color: hex ?? '',
        );
    }

    setState(() {
      selectedCellBackgroundColor = color;
    });
  }

  void _onAlignTap(TableAlign align) {
    switch (widget.type) {
      case SimpleTableMoreActionType.column:
        widget.editorState.updateColumnAlign(
          tableCellNode: widget.cellNode,
          align: align,
        );
      case SimpleTableMoreActionType.row:
        widget.editorState.updateRowAlign(
          tableCellNode: widget.cellNode,
          align: align,
        );
    }

    setState(() {
      selectedAlign = align;
    });
  }
}

/// This bottom sheet is used for the table action menu.
/// When selecting a table and tapping the action menu button on the top-left corner of the table,
/// this bottom sheet will be shown.
///
/// Note: This widget is only used for mobile.
class SimpleTableBottomSheet extends StatefulWidget {
  const SimpleTableBottomSheet({
    super.key,
    required this.tableNode,
    required this.editorState,
    this.scrollController,
  });

  final Node tableNode;
  final EditorState editorState;
  final ScrollController? scrollController;

  @override
  State<SimpleTableBottomSheet> createState() => _SimpleTableBottomSheetState();
}

class _SimpleTableBottomSheetState extends State<SimpleTableBottomSheet> {
  _SimpleTableBottomSheetMenuState menuState =
      _SimpleTableBottomSheetMenuState.tableActionMenu;

  TableAlign? selectedAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header
        _buildHeader(),

        // content
        SizedBox(
          height: SimpleTableConstants.actionSheetBottomSheetHeight,
          child: Scrollbar(
            controller: widget.scrollController,
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Column(
                children: [
                  // content
                  ..._buildContent(),

                  // safe area padding
                  VSpace(context.bottomSheetPadding() * 2),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    switch (menuState) {
      case _SimpleTableBottomSheetMenuState.tableActionMenu:
        return BottomSheetHeader(
          showBackButton: false,
          showCloseButton: true,
          showDoneButton: false,
          showRemoveButton: false,
          title: LocaleKeys.document_plugins_simpleTable_headerName_table.tr(),
          onClose: () => Navigator.pop(context),
        );
      case _SimpleTableBottomSheetMenuState.align:
        return BottomSheetHeader(
          showBackButton: true,
          showCloseButton: false,
          showDoneButton: true,
          showRemoveButton: false,
          title: LocaleKeys.document_plugins_simpleTable_headerName_table.tr(),
          onBack: () => setState(() {
            menuState = _SimpleTableBottomSheetMenuState.tableActionMenu;
          }),
          onDone: (_) => Navigator.pop(context),
        );
      default:
        throw UnimplementedError('Unsupported menu state: $menuState');
    }
  }

  List<Widget> _buildContent() {
    switch (menuState) {
      case _SimpleTableBottomSheetMenuState.tableActionMenu:
        return _buildActionButtons();
      case _SimpleTableBottomSheetMenuState.align:
        return _buildAlign();
      default:
        throw UnimplementedError('Unsupported menu state: $menuState');
    }
  }

  List<Widget> _buildActionButtons() {
    return [
      // quick actions
      // copy, cut, paste, delete
      SimpleTableQuickActions(
        tableNode: widget.tableNode,
        editorState: widget.editorState,
      ),
      const VSpace(24),

      // action buttons
      SimpleTableActionButtons(
        tableNode: widget.tableNode,
        editorState: widget.editorState,
        onAlignTap: _onTapAlignButton,
      ),
    ];
  }

  List<Widget> _buildAlign() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
        ),
        child: Row(
          children: [
            _buildAlignButton(TableAlign.left),
            const HSpace(2),
            _buildAlignButton(TableAlign.center),
            const HSpace(2),
            _buildAlignButton(TableAlign.right),
          ],
        ),
      ),
    ];
  }

  Widget _buildAlignButton(TableAlign align) {
    return SimpleTableContentAlignAction(
      onTap: () => _onTapAlign(align),
      align: align,
      isSelected: selectedAlign == align,
    );
  }

  void _onTapAlignButton() {
    setState(() {
      menuState = _SimpleTableBottomSheetMenuState.align;
    });
  }

  void _onTapAlign(TableAlign align) {
    setState(() {
      selectedAlign = align;
    });

    widget.editorState.updateTableAlign(
      tableNode: widget.tableNode,
      align: align,
    );
  }
}

class EditorTextColorWidget extends StatelessWidget {
  EditorTextColorWidget({
    super.key,
    this.selectedColor,
    required this.onSelectedColor,
  });

  final Color? selectedColor;
  final void Function(Color color) onSelectedColor;

  final colors = [
    const Color(0x00FFFFFF),
    const Color(0xFFDB3636),
    const Color(0xFFEA8F06),
    const Color(0xFF18A166),
    const Color(0xFF205EEE),
    const Color(0xFFC619C9),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: colors.mapIndexed(
        (index, color) {
          return _TextColorItem(
            color: color,
            isSelected:
                selectedColor == null ? index == 0 : selectedColor == color,
            onTap: () => onSelectedColor(color),
          );
        },
      ).toList(),
    );
  }
}

class _TextColorItem extends StatelessWidget {
  const _TextColorItem({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final VoidCallback onTap;
  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          borderRadius: Corners.s12Border,
          border: Border.all(
            width: isSelected ? 2.0 : 1.0,
            color: isSelected
                ? const Color(0xff00C6F1)
                : Theme.of(context).dividerColor,
          ),
        ),
        alignment: Alignment.center,
        child: FlowyText(
          'A',
          fontSize: 24,
          color: color.a == 0 ? null : color,
        ),
      ),
    );
  }
}

class EditorBackgroundColors extends StatelessWidget {
  const EditorBackgroundColors({
    super.key,
    this.selectedColor,
    required this.onSelectedColor,
  });

  final Color? selectedColor;
  final void Function(Color color) onSelectedColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.light
        ? EditorFontColors.lightColors
        : EditorFontColors.darkColors;
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: colors.mapIndexed(
        (index, color) {
          return _BackgroundColorItem(
            color: color,
            isSelected:
                selectedColor == null ? index == 0 : selectedColor == color,
            onTap: () => onSelectedColor(color),
          );
        },
      ).toList(),
    );
  }
}

class _BackgroundColorItem extends StatelessWidget {
  const _BackgroundColorItem({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final VoidCallback onTap;
  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = ToolbarColorExtension.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: Corners.s12Border,
          border: Border.all(
            width: isSelected ? 2.0 : 1.0,
            color: isSelected
                ? theme.toolbarMenuItemSelectedBackgroundColor
                : Theme.of(context).dividerColor,
          ),
        ),
        alignment: Alignment.center,
        child: isSelected
            ? const FlowySvg(
                FlowySvgs.m_blue_check_s,
                size: Size.square(28.0),
                blendMode: null,
              )
            : null,
      ),
    );
  }
}
