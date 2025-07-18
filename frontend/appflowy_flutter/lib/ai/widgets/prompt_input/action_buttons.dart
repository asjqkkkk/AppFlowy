import 'package:appflowy/ai/service/ai_attach_file_bloc.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy/plugins/local_file/local_file.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:flowy_infra/file_picker/file_picker_service.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'layout_define.dart';

class PromptInputAttachmentButton extends StatefulWidget {
  const PromptInputAttachmentButton({
    required this.onSelectFiles,
    required this.chatId,
    super.key,
  });

  final Future<void> Function(FilePickerResult? result) onSelectFiles;
  final String chatId;

  @override
  State<PromptInputAttachmentButton> createState() =>
      _PromptInputAttachmentButtonState();
}

class _PromptInputAttachmentButtonState
    extends State<PromptInputAttachmentButton> {
  final popoverController = PopoverController();
  late AIAattachFileBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = AIAattachFileBloc(chatId: widget.chatId);
  }

  @override
  void dispose() {
    bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFlowyPopover(
      constraints: BoxConstraints(
        minWidth: 220,
        maxWidth: 220,
        minHeight: 80,
        maxHeight: 280,
      ),
      offset: const Offset(0.0, -10.0),
      direction: PopoverDirection.topWithCenterAligned,
      margin: EdgeInsets.zero,
      controller: popoverController,
      popupBuilder: (_) {
        return _AttachedFiles(
          bloc: bloc,
          onOpenFile: (file) {
            final fileData = LocalFileData(
              filePath: file.filePath,
              fileName: file.fileName,
            );

            final plugin = LocalFilePluginBuilder().build(fileData);
            if (context.mounted) {
              getIt<TabsBloc>().add(
                TabsEvent.openSecondaryPlugin(
                  plugin: plugin,
                ),
              );
            }

            popoverController.close();
          },
          onAddMoreFiles: () async {
            final path = await getIt<FilePickerService>().pickFiles(
              dialogTitle: '',
              type: FileType.custom,
              allowedExtensions: ["pdf", "txt", "md", "markdown"],
            );

            await widget.onSelectFiles(path);
            popoverController.close();
          },
        );
      },
      child: BlocProvider.value(
        value: bloc,
        child: BlocListener<AIAattachFileBloc, AIAattachFileState>(
          listenWhen: (previous, current) =>
              previous.embedFileError != current.embedFileError,
          listener: (context, state) {
            if (state.embedFileError != null) {
              showToastNotification(
                message: state.embedFileError!.error,
                type: ToastificationType.error,
              );
            }
          },
          child: _IndicatorButton(
            onTap: () => popoverController.show(),
            bloc: bloc,
          ),
        ),
      ),
    );
  }
}

class PromptInputMentionButton extends StatelessWidget {
  const PromptInputMentionButton({
    super.key,
    required this.buttonSize,
    required this.iconSize,
    required this.onTap,
  });

  final double buttonSize;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: LocaleKeys.chat_clickToMention.tr(),
      preferBelow: false,
      child: FlowyIconButton(
        width: buttonSize,
        hoverColor: AFThemeExtension.of(context).lightGreyHover,
        radius: BorderRadius.circular(8),
        icon: FlowySvg(
          FlowySvgs.chat_at_s,
          size: Size.square(iconSize),
          color: Theme.of(context).iconTheme.color,
        ),
        onPressed: onTap,
      ),
    );
  }
}

class _AttachedFiles extends StatelessWidget {
  const _AttachedFiles({
    required this.onAddMoreFiles,
    required this.onOpenFile,
    required this.bloc,
  });

  final VoidCallback onAddMoreFiles;
  final AIAattachFileBloc bloc;
  final void Function(ChatFile) onOpenFile;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: bloc,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<AIAattachFileBloc, AIAattachFileState>(
            buildWhen: (previous, current) =>
                previous.files.length != current.files.length,
            builder: (context, state) {
              return Flexible(
                child: Stack(
                  children: [
                    ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      separatorBuilder: (context, index) => const HSpace(6),
                      itemCount: state.files.length,
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 6 : 3,
                          bottom: 3,
                        ),
                        child: AttachedFilePreview(
                          key: ValueKey(state.files[index]),
                          file: state.files[index],
                          onOpenFile: onOpenFile,
                        ),
                      ),
                    ),
                    if (state.files.isEmpty)
                      Positioned.fill(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: FlowyText(
                              LocaleKeys.chat_noFilesAttached.tr(),
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 12, right: 12),
            child: SizedBox(
              height: 32,
              child: FlowyButton(
                backgroundColor: AFThemeExtension.of(context).lightGreyHover,
                text: Center(
                  child: FlowyText.regular(
                    LocaleKeys.chat_addMoreFiles.tr(),
                  ),
                ),
                onTap: () async {
                  onAddMoreFiles();
                },
              ),
            ),
          ),
          BlocBuilder<AIAattachFileBloc, AIAattachFileState>(
            buildWhen: (previous, current) =>
                previous.files.length != current.files.length,
            builder: (context, state) {
              if (state.files.length > 3) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 8.0,
                    left: 12,
                    right: 12,
                  ),
                  child: Text(
                    'Too many files may decrease RAG effectiveness',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class AttachedFilePreview extends StatelessWidget {
  const AttachedFilePreview({
    required this.file,
    required this.onOpenFile,
    super.key,
  });

  final ChatFile file;
  final void Function(ChatFile) onOpenFile;

  @override
  Widget build(BuildContext context) {
    return FlowyHover(
      style: const HoverStyle(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: GestureDetector(
        onTap: () {
          onOpenFile(file);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              _fileIcon(context),
              const HSpace(8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FlowyText(
                      file.fileName,
                      fontSize: 12.0,
                    ),
                    FlowyText(
                      file.fileType.name,
                      color: Theme.of(context).hintColor,
                      fontSize: 12.0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileIcon(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AFThemeExtension.of(context).tint1,
        borderRadius: BorderRadius.circular(8),
      ),
      height: 32,
      width: 32,
      child: Center(
        child: FlowySvg(
          FlowySvgs.page_m,
          size: const Size.square(16),
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}

class _IndicatorButton extends StatelessWidget {
  const _IndicatorButton({
    required this.onTap,
    required this.bloc,
  });

  final VoidCallback onTap;
  final AIAattachFileBloc bloc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: DesktopAIPromptSizes.actionBarButtonSize,
        child: FlowyHover(
          style: const HoverStyle(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 15,
                  child: FlowySvg(
                    FlowySvgs.ai_attachment_s,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const HSpace(2.0),
                BlocProvider.value(
                  value: bloc,
                  child: BlocBuilder<AIAattachFileBloc, AIAattachFileState>(
                    builder: (context, state) {
                      return FlowyText(
                        state.files.length.toString(),
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      );
                    },
                  ),
                ),
                FlowySvg(
                  FlowySvgs.ai_source_drop_down_s,
                  color: Theme.of(context).hintColor,
                  size: const Size.square(8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
