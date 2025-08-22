import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/shared/feedback_gesture_detector.dart';
import 'package:appflowy/shared/flowy_gradient_colors.dart';
import 'package:appflowy/shared/flowy_tint_colors.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PageCoverBottomSheet extends StatelessWidget {
  const PageCoverBottomSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final bloc = context.read<DocumentPageStyleBloc>();

    final userWorkspaceState = context.read<UserWorkspaceBloc>().state;

    final isPro = userWorkspaceState.isInProPlan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: theme.spacing.xxl,
      children: [
        _SolidColors(
          theme: theme,
          onSelect: (tint) {
            bloc.add(
              DocumentPageStyleEvent.updateCoverImage(
                PageStyleCover(
                  type: PageStyleCoverImageType.pureColor,
                  value: tint.id,
                ),
              ),
            );
          },
        ),
        if (isPro)
          _GradientColors(
            theme: theme,
            onSelect: (gradient) {
              bloc.add(
                DocumentPageStyleEvent.updateCoverImage(
                  PageStyleCover(
                    type: PageStyleCoverImageType.gradientColor,
                    value: gradient.id,
                  ),
                ),
              );
            },
          ),
        _BuiltinCovers(
          theme: theme,
          onSelect: (imageName) {
            bloc.add(
              DocumentPageStyleEvent.updateCoverImage(
                PageStyleCover(
                  type: PageStyleCoverImageType.builtInImage,
                  value: imageName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SolidColors extends StatelessWidget {
  const _SolidColors({
    required this.theme,
    required this.onSelect,
  });

  final AppFlowyThemeData theme;
  final void Function(FlowyTint tint) onSelect;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentPageStyleBloc, DocumentPageStyleState>(
      builder: (context, state) {
        return Column(
          spacing: theme.spacing.m,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xl,
              ),
              child: Text(
                LocaleKeys.pageStyle_colors.tr(),
                style: theme.textStyle.caption.prominent(
                  color: theme.textColorScheme.secondary,
                ),
              ),
            ),
            GridView.custom(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisExtent(
                crossAxisExtent: 48,
                mainAxisSpacing: theme.spacing.l,
                crossAxisSpacing: theme.spacing.l,
              ),
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xl,
              ),
              physics: const NeverScrollableScrollPhysics(),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tint = FlowyTint.values[index];

                  return MobileColorTile(
                    colorType: ColorType.background,
                    color: tint.toAFColor(),
                    isSelected: state.coverImage.isPureColor &&
                        state.coverImage.value == tint.id,
                    onSelect: () => onSelect(tint),
                  );
                },
                childCount: FlowyTint.values.length,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GradientColors extends StatelessWidget {
  const _GradientColors({
    required this.theme,
    required this.onSelect,
  });

  final AppFlowyThemeData theme;
  final void Function(FlowyGradient gradient) onSelect;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentPageStyleBloc, DocumentPageStyleState>(
      builder: (context, state) {
        return Column(
          spacing: theme.spacing.m,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xl,
              ),
              child: Text(
                LocaleKeys.pageStyle_gradient.tr(),
                style: theme.textStyle.caption.prominent(
                  color: theme.textColorScheme.secondary,
                ),
              ),
            ),
            GridView.custom(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisExtent(
                crossAxisExtent: 48,
                mainAxisSpacing: theme.spacing.l,
                crossAxisSpacing: theme.spacing.l,
              ),
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xl,
              ),
              physics: const NeverScrollableScrollPhysics(),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) {
                  final gradient = FlowyGradient.values[index];

                  return MobileColorTile(
                    colorType: ColorType.background,
                    color: gradient.toAFColor(),
                    isSelected: state.coverImage.isGradient &&
                        state.coverImage.value == gradient.id,
                    onSelect: () => onSelect(gradient),
                  );
                },
                childCount: FlowyGradient.values.length,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BuiltinCovers extends StatelessWidget {
  const _BuiltinCovers({
    required this.theme,
    required this.onSelect,
  });

  final AppFlowyThemeData theme;
  final void Function(String imageName) onSelect;

  @override
  Widget build(BuildContext context) {
    final imageNames = ['1', '2', '3', '4', '5', '6'];

    return BlocBuilder<DocumentPageStyleBloc, DocumentPageStyleState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.spacing.m,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xl,
              ),
              child: Text(
                LocaleKeys.pageStyle_backgroundImage.tr(),
                style: theme.textStyle.caption.prominent(
                  color: theme.textColorScheme.secondary,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xl,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 16.0 / 9.0,
              ),
              itemCount: imageNames.length,
              itemBuilder: (context, index) => _buildBuiltInImage(
                context,
                state,
                imageNames[index],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBuiltInImage(
    BuildContext context,
    DocumentPageStyleState state,
    String imageName,
  ) {
    final asset = PageStyleCoverImageType.builtInImagePath(imageName);
    final isSelected =
        state.coverImage.isBuiltInImage && state.coverImage.value == imageName;

    Widget child = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
      ),
    );

    if (isSelected) {
      child = Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.borderColorScheme.themeThick,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(theme.spacing.s),
        ),
        padding: EdgeInsets.all(2.0),
        child: child,
      );
    }

    return FeedbackGestureDetector(
      onTap: () => onSelect(imageName),
      child: child,
    );
  }
}
