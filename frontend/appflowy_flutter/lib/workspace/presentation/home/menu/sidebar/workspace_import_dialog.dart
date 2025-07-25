// import 'package:appflowy/features/import/logic/workspace_import_bloc.dart';
// import 'package:appflowy/generated/flowy_svgs.g.dart';
// import 'package:appflowy/generated/locale_keys.g.dart';
// import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
// import 'package:easy_localization/easy_localization.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// class WorkspaceImportDialog extends StatefulWidget {
//   const WorkspaceImportDialog({super.key});

//   static Future<void> show({
//     required BuildContext context,
//   }) async {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => BlocProvider(
//         create: (context) => WorkspaceImportBloc(),
//         child: const WorkspaceImportDialog(),
//       ),
//     );
//   }

//   @override
//   State<WorkspaceImportDialog> createState() => _WorkspaceImportDialogState();
// }

// class _WorkspaceImportDialogState extends State<WorkspaceImportDialog> {
//   final _workspaceNameController = TextEditingController();
//   String? _selectedFilePath;

//   @override
//   void dispose() {
//     _workspaceNameController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BlocConsumer<WorkspaceImportBloc, WorkspaceImportState>(
//       listener: (context, state) {
//         if (state.status == WorkspaceImportStatus.success) {
//           Navigator.of(context).pop();
//           showToastNotification(
//             message: 'Workspace imported successfully!',
//           );
//         } else if (state.status == WorkspaceImportStatus.failure) {
//           final error = state.importResult?.getFailure();
//           showToastNotification(
//             message: 'Import failed: $error',
//             type: ToastificationType.error,
//           );
//         }
//       },
//       builder: (context, state) {
//         return AlertDialog(
//           title: FlowyText.medium(
//             'Import Workspace',
//             fontSize: 18,
//           ),
//           content: SizedBox(
//             width: 400,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 FlowyText.regular(
//                   'Select a workspace export ZIP file to import:',
//                   fontSize: 14,
//                 ),
//                 const VSpace(16),

//                 // File picker section
//                 _buildFilePicker(),
//                 const VSpace(16),

//                 // Workspace name input
//                 _buildWorkspaceNameInput(),
//                 const VSpace(16),

//                 if (state.status == WorkspaceImportStatus.loading)
//                   const LinearProgressIndicator(),
//               ],
//             ),
//           ),
//           actions: [
//             FlowyButton(
//               text: FlowyText.regular(LocaleKeys.button_cancel.tr()),
//               onTap: () => Navigator.of(context).pop(),
//             ),
//             const HSpace(8),
//             FlowyButton(
//               text: FlowyText.regular('Import'), // TODO: Add to locale_keys
//               onTap: _canImport(state) ? _onImportPressed : null,
//               useIntrinsicWidth: true,
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildFilePicker() {
//     return DecoratedBox(
//       decoration: BoxDecoration(
//         border: Border.all(color: Theme.of(context).dividerColor),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: FlowyButton(
//         onTap: _pickFile,
//         margin: const EdgeInsets.all(12),
//         text: Row(
//           children: [
//             const FlowySvg(FlowySvgs.folder_m),
//             const HSpace(8),
//             Expanded(
//               child: FlowyText.regular(
//                 _selectedFilePath ?? 'Select ZIP file...',
//                 fontSize: 14,
//                 color: _selectedFilePath != null
//                     ? null
//                     : Theme.of(context).hintColor,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildWorkspaceNameInput() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         FlowyText.regular(
//           'Workspace name (optional):',
//           fontSize: 14,
//         ),
//         const VSpace(8),
//         FlowyTextField(
//           controller: _workspaceNameController,
//           hintText:
//               'Enter workspace name or leave empty for auto-generated name',
//         ),
//       ],
//     );
//   }

//   Future<void> _pickFile() async {
//     final result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: ['zip'],
//       dialogTitle: 'Select Workspace Export File',
//     );

//     if (result != null && result.files.single.path != null) {
//       setState(() {
//         _selectedFilePath = result.files.single.path;
//       });
//     }
//   }

//   bool _canImport(WorkspaceImportState state) {
//     return _selectedFilePath != null &&
//         state.status != WorkspaceImportStatus.loading;
//   }

//   void _onImportPressed() {
//     if (_selectedFilePath == null) return;

//     final workspaceName = _workspaceNameController.text.trim();

//     context.read<WorkspaceImportBloc>().add(
//           WorkspaceImportEvent.import(
//             archivePath: _selectedFilePath!,
//             workspaceName: workspaceName.isEmpty ? null : workspaceName,
//           ),
//         );
//   }
// }
