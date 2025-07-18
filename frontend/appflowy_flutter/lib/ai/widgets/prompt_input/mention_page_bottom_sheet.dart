import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/base/flowy_search_text_field.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

import 'mention_page_menu.dart';

Future<ViewPB?> showPageSelectorSheet(
  BuildContext context, {
  required bool Function(ViewPB view) filter,
}) async {
  return showDraggableMobileBottomSheet<ViewPB>(
    context,
    headerBuilder: null,
    builder: (context) => SizedBox.shrink(),
    sheetContentBuilder: (context) {
      return _MobilePageSelectorBody(
        filter: filter,
      );
    },
  );
}

class _MobilePageSelectorBody extends StatefulWidget {
  const _MobilePageSelectorBody({
    this.filter,
  });

  final bool Function(ViewPB view)? filter;

  @override
  State<_MobilePageSelectorBody> createState() =>
      _MobilePageSelectorBodyState();
}

class _MobilePageSelectorBodyState extends State<_MobilePageSelectorBody> {
  final textController = TextEditingController();
  late final Future<List<ViewPB>> _viewsFuture = _fetchViews();

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DragHandle(),
        SizedBox(
          height: 44.0,
          child: Center(
            child: FlowyText.medium(
              LocaleKeys.document_mobilePageSelector_title.tr(),
              fontSize: 16.0,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          child: SizedBox(
            height: 44.0,
            child: FlowySearchTextField(
              controller: textController,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const AFDivider(),
        Expanded(
          child: FutureBuilder(
            future: _viewsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: FlowyText(
                    LocaleKeys.document_mobilePageSelector_failedToLoad.tr(),
                  ),
                );
              }

              final views = snapshot.data!
                  .where((v) => widget.filter?.call(v) ?? true)
                  .toList();

              final filtered = views.where(
                (v) =>
                    textController.text.isEmpty ||
                    v.name
                        .toLowerCase()
                        .contains(textController.text.toLowerCase()),
              );

              if (filtered.isEmpty) {
                return Center(
                  child: FlowyText(
                    LocaleKeys.document_mobilePageSelector_noPagesFound.tr(),
                  ),
                );
              }

              return ListView.builder(
                controller: PrimaryScrollController.of(context),
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final view = filtered.elementAt(index);
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(view),
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.transparent,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.all(4.0),
                      child: Row(
                        children: [
                          MentionViewIcon(view: view),
                          const HSpace(8),
                          Expanded(
                            child: MentionViewTitleAndAncestors(view: view),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<ViewPB>> _fetchViews() async {
    final viewsOrNull = await ViewBackendService.getAllViews().toNullable();
    return viewsOrNull?.items ?? [];
  }
}
