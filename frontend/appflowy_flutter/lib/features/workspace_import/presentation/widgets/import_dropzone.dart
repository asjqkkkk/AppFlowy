import 'dart:io';

import 'package:appflowy/features/workspace_import/logic/workspace_import_dialog_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportDropzone extends StatefulWidget {
  const ImportDropzone({super.key});

  @override
  State<ImportDropzone> createState() => _ImportDropzoneState();
}

class _ImportDropzoneState extends State<ImportDropzone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocConsumer<WorkspaceImportDialogBloc, WorkspaceImportDialogState>(
      listener: (context, state) {
        if (state.status == WorkspaceImportDialogStatus.dragOver) {
          setState(() => _isDragging = true);
        } else {
          setState(() => _isDragging = false);
        }
      },
      builder: (context, state) {
        final isDragOver =
            _isDragging || state.status == WorkspaceImportDialogStatus.dragOver;
        final isLoading = state.isLoading;

        return Padding(
          padding: EdgeInsets.only(
            top: theme.spacing.xxl,
            left: theme.spacing.xxl,
            right: theme.spacing.xxl,
          ),
          child: DropTarget(
            onDragEntered: (details) {
              context.read<WorkspaceImportDialogBloc>().add(
                    const DragEntered(),
                  );
            },
            onDragExited: (details) {
              context.read<WorkspaceImportDialogBloc>().add(
                    const DragExited(),
                  );
            },
            onDragDone: (details) async {
              if (details.files.isNotEmpty) {
                final file = File(details.files.first.path);
                context.read<WorkspaceImportDialogBloc>().add(
                      FileDropped(file),
                    );
              }
            },
            child: GestureDetector(
              onTap: isLoading
                  ? null
                  : () {
                      context.read<WorkspaceImportDialogBloc>().add(
                            const UploadButtonClicked(),
                          );
                    },
              child: Container(
                height: 170,
                decoration: BoxDecoration(
                  color: isDragOver
                      ? theme.fillColorScheme.themeSelect
                      : theme.surfaceColorScheme.layer01,
                  borderRadius: BorderRadius.circular(theme.borderRadius.l),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: isDragOver
                              ? theme.borderColorScheme.themeThick
                              : theme.borderColorScheme.primary,
                          strokeWidth: 2,
                          dashLength: 8,
                          dashSpace: 4,
                        ),
                      ),
                    ),
                    Center(
                      child: _buildEmptyContent(isDragOver),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyContent(bool isDragOver) {
    final theme = AppFlowyTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlowySvg(
              FlowySvgs.import_workspace_m,
              size: Size.square(20),
              color: theme.iconColorScheme.secondary,
            ),
            VSpace(theme.spacing.m),
            Text(
              LocaleKeys.workspaceImport_uploadZipFiles.tr(),
              style: theme.textStyle.body.enhanced(
                color: theme.textColorScheme.primary,
              ),
            ),
            VSpace(theme.spacing.xs),
            RichText(
              text: TextSpan(
                style: theme.textStyle.body.standard(
                  color: theme.textColorScheme.secondary,
                ),
                children: [
                  TextSpan(
                    text: LocaleKeys.workspaceImport_dragDropInstruction.tr(),
                  ),
                  TextSpan(
                    text: LocaleKeys.workspaceImport_uploadButtonText.tr(),
                    style: theme.textStyle.body.standard(
                      color: theme.textColorScheme.action,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashSpace,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(12),
        ),
      );

    final dashPattern = [dashLength, dashSpace];
    final dashedPath = _createDashedPath(path, dashPattern);

    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, List<double> pattern) {
    final dashedPath = Path();
    final pathMetrics = source.computeMetrics();

    for (final metric in pathMetrics) {
      var distance = 0.0;
      var index = 0;

      while (distance < metric.length) {
        final length = pattern[index % pattern.length];
        final end = distance + length;

        if (index % 2 == 0) {
          dashedPath.addPath(
            metric.extractPath(distance, end.clamp(0, metric.length)),
            Offset.zero,
          );
        }

        distance = end;
        index++;
      }
    }

    return dashedPath;
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashLength != oldDelegate.dashLength ||
        dashSpace != oldDelegate.dashSpace;
  }
}
