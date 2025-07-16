import 'package:appflowy/shared/list_extension.dart';
import 'package:bloc/bloc.dart';

import '../data/models/af_color.dart';
import '../data/models/color_picker_config.dart';
import '../data/repositories/recent_custom_color_repository.dart';
import 'color_picker_event.dart';
import 'color_picker_state.dart';

class ColorPickerBloc extends Bloc<ColorPickerEvent, ColorPickerState> {
  ColorPickerBloc({
    required this.repository,
    required this.config,
  }) : super(ColorPickerState()) {
    on<ColorPickerInitial>(_onInitial);
    on<ColorPickerUseColor>(_onUseColor);
    on<ColorPickerUseDefaultColor>(_onUseDefaultColor);
    on<ColorPickerCreateCustomColor>(_onCreateCustomColor);
  }

  final RecentCustomColorRepository repository;
  final ColorPickerConfig config;

  /// The initially selected color.
  AFColor? _initialSelectedColor;

  /// The color to save to recent after closing the color picker.
  AFColor? _recentColorToSave;

  @override
  Future<void> close() async {
    if (_recentColorToSave != null &&
        _recentColorToSave != config.defaultColor &&
        _recentColorToSave != _initialSelectedColor) {
      final recentColors =
          [_recentColorToSave!, ...state.recentColors].unique();
      trimColors(recentColors, config.maxColorLimit);
      await repository.saveRecentColors(recentColors);
    }
    await super.close();
  }

  Future<void> _onInitial(
    ColorPickerInitial event,
    Emitter<ColorPickerState> emit,
  ) async {
    final recentColors = await repository.getRecentColors();
    final customColors = await repository.getCustomColors();

    // selected color
    final selectedColor = switch (event.selectedColors.length) {
      0 => config.defaultColor,
      1 => event.selectedColors.first,
      _ => null,
    };
    _initialSelectedColor = selectedColor;

    // recent colors
    trimColors(recentColors, config.maxColorLimit);

    // custom colors
    trimColors(customColors, config.maxColorLimit - 1);
    final singleSelectedColor = event.selectedColors.singleOrNull;
    if (singleSelectedColor is CustomAFColor &&
        !customColors.contains(singleSelectedColor)) {
      customColors.insert(0, singleSelectedColor);
      trimColors(customColors, config.maxColorLimit - 1);
    }

    emit(
      ColorPickerState(
        recentColors: recentColors,
        customColors: customColors,
        selectedColor: selectedColor,
      ),
    );
  }

  Future<void> _onUseColor(
    ColorPickerUseColor event,
    Emitter<ColorPickerState> emit,
  ) async {
    emit(
      state.copyWith(selectedColor: event.color),
    );

    _recentColorToSave = event.color;
  }

  Future<void> _onUseDefaultColor(
    ColorPickerUseDefaultColor event,
    Emitter<ColorPickerState> emit,
  ) async {
    emit(
      state.copyWith(selectedColor: config.defaultColor),
    );
  }

  Future<void> _onCreateCustomColor(
    ColorPickerCreateCustomColor event,
    Emitter<ColorPickerState> emit,
  ) async {
    _recentColorToSave = event.color;

    if (state.customColors.contains(event.color)) {
      emit(
        state.copyWith(selectedColor: event.color),
      );
      return;
    }

    final customColors = [...state.customColors, event.color];
    trimColors(customColors, config.maxColorLimit - 1, fromStart: true);
    await repository.saveCustomColors(customColors);

    emit(
      state.copyWith(
        selectedColor: event.color,
        customColors: customColors,
      ),
    );
  }

  void trimColors(
    List<AFColor> colors,
    int targetLength, {
    bool fromStart = false,
  }) {
    if (colors.length > targetLength) {
      if (fromStart) {
        colors.removeRange(0, colors.length - targetLength);
      } else {
        colors.removeRange(targetLength, colors.length);
      }
    }
  }
}
