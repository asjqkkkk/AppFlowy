import 'dart:io';

import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/plugins/ai_chat/application/ai_chat_prelude.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_message_height_manager.dart';
import 'package:appflowy/plugins/ai_chat/presentation/chat_related_question.dart';
import 'package:appflowy/plugins/ai_chat/presentation/message/ai_text_message.dart';
import 'package:appflowy/plugins/ai_chat/presentation/message/error_text_message.dart';
import 'package:appflowy/plugins/ai_chat/presentation/message/message_util.dart';
import 'package:appflowy/plugins/ai_chat/presentation/message/user_text_message.dart';
import 'package:appflowy/plugins/local_file/local_file.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:string_validator/string_validator.dart';
import 'package:url_launcher/url_launcher.dart';

class TextMessageWidget extends StatelessWidget {
  const TextMessageWidget({
    super.key,
    required this.message,
    required this.userProfile,
    required this.view,
    this.enableAnimation = true,
  });

  final TextMessage message;
  final UserProfilePB userProfile;
  final ViewPB view;
  final bool enableAnimation;

  @override
  Widget build(BuildContext context) {
    final messageType = onetimeMessageTypeFromMeta(
      message.metadata,
    );

    if (messageType == OnetimeShotType.error) {
      return ChatErrorMessageWidget(
        errorMessage: message.metadata?[errorMessageTextKey] ?? "",
      );
    }

    if (messageType == OnetimeShotType.relatedQuestion) {
      final messages = context.read<ChatBloc>().chatController.messages;
      final lastAIMessage = messages.lastWhere(
        (e) =>
            onetimeMessageTypeFromMeta(e.metadata) == null &&
            (e.author.id == aiResponseUserId || e.author.id == systemUserId),
      );
      final minHeight =
          ChatMessageHeightManager().calculateRelatedQuestionMinHeight(
        messageId: lastAIMessage.id,
      );
      return Container(
        constraints: BoxConstraints(
          minHeight: minHeight,
        ),
        child: RelatedQuestionList(
          relatedQuestions: message.metadata!['questions'],
          onQuestionSelected: (question) {
            final bloc = context.read<AIPromptInputBloc>();
            final showPredefinedFormats = bloc.state.showPredefinedFormats;
            final predefinedFormat = bloc.state.predefinedFormat;

            context.read<ChatBloc>().add(
                  ChatEvent.sendMessage(
                    message: question,
                    format: showPredefinedFormats ? predefinedFormat : null,
                  ),
                );
          },
        ),
      );
    }

    if (message.author.id == userProfile.id.toString() ||
        isOtherUserMessage(message)) {
      return ChatUserMessageWidget(
        user: message.author,
        message: message,
      );
    }

    final stream = message.metadata?["$AnswerStream"];
    final questionId = message.metadata?[messageQuestionIdKey];
    final refSourceJsonString = message.metadata?[messageSourceKey] as String?;

    return BlocSelector<ChatSelectMessageBloc, ChatSelectMessageState, bool>(
      selector: (state) => state.isSelectingMessages,
      builder: (context, isSelectingMessages) {
        return BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (previous, current) =>
              previous.promptResponseState != current.promptResponseState,
          builder: (context, state) {
            final chatController = context.read<ChatBloc>().chatController;
            final messages = chatController.messages
                .where((e) => onetimeMessageTypeFromMeta(e.metadata) == null);
            final isLastMessage =
                messages.isEmpty ? false : messages.last.id == message.id;
            final hasRelatedQuestions = state.promptResponseState ==
                PromptResponseState.relatedQuestionsReady;
            return ChatAIMessageWidget(
              user: message.author,
              messageUserId: message.id,
              message: message,
              stream: stream is AnswerStream ? stream : null,
              questionId: questionId,
              chatId: view.id,
              refSourceJsonString: refSourceJsonString,
              isStreaming: !state.promptResponseState.isReady,
              isLastMessage: isLastMessage,
              hasRelatedQuestions: hasRelatedQuestions,
              isSelectingMessages: isSelectingMessages,
              enableAnimation: enableAnimation,
              onSelectedMetadata: (metadata) =>
                  _onSelectMetadata(context, metadata),
              onRegenerate: () => context
                  .read<ChatBloc>()
                  .add(ChatEvent.regenerateAnswer(message.id, null, null)),
              onChangeFormat: (format) => context
                  .read<ChatBloc>()
                  .add(ChatEvent.regenerateAnswer(message.id, format, null)),
              onChangeModel: (model) => context
                  .read<ChatBloc>()
                  .add(ChatEvent.regenerateAnswer(message.id, null, model)),
              onStopStream: () => context.read<ChatBloc>().add(
                    const ChatEvent.stopStream(),
                  ),
            );
          },
        );
      },
    );
  }

  void _onSelectMetadata(
    BuildContext context,
    ChatMessageRefSource metadata,
  ) async {
    // Check the RAGSource for different source types
    if (metadata.source == "appflowy") {
      final sidebarView =
          await ViewBackendService.getView(metadata.id).toNullable();
      if (context.mounted) {
        openPageFromMessage(context, sidebarView);
      }
      return;
    }

    // Check the RAGSource for different source types
    if (metadata.source == "local_file") {
      Log.debug("local_file: ${metadata.name}");

      // Create LocalFileData from metadata
      final fileData = LocalFileData(
        filePath: metadata.id, // Assuming the id contains the file path
        fileName: metadata.name,
      );

      // Build the plugin and open it in secondary panel
      final plugin = LocalFilePluginBuilder().build(fileData);

      if (context.mounted) {
        getIt<TabsBloc>().add(
          TabsEvent.openSecondaryPlugin(
            plugin: plugin,
          ),
        );
      }
      return;
    }

    // Check the RAGSource for different source types
    if (metadata.source == "web") {
      if (isURL(metadata.name)) {
        late Uri uri;
        try {
          uri = Uri.parse(metadata.name);
          // `Uri` identifies `localhost` as a scheme
          if (!uri.hasScheme || uri.scheme == 'localhost') {
            uri = Uri.parse("http://${metadata.name}");
            await InternetAddress.lookup(uri.host);
          }
          await launchUrl(uri);
        } catch (err) {
          Log.error("failed to open url $err");
        }
      }
      return;
    }
  }
}
