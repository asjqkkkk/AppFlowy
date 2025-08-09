import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/select_option_entities.pb.dart';

// NOTE: Yes, this doesn't make sense. But it's for backward compatibility with old code.

const Map<SelectOptionColorPB, String> _selectOptionColorToAFColorMap = {
  SelectOptionColorPB.Purple: 'bg-color-14',
  SelectOptionColorPB.Pink: 'bg-color-16',
  SelectOptionColorPB.LightPink: 'bg-color-18',
  SelectOptionColorPB.Orange: 'bg-color-2',
  SelectOptionColorPB.Yellow: 'bg-color-4',
  SelectOptionColorPB.Lime: 'bg-color-6',
  SelectOptionColorPB.Green: 'bg-color-8',
  SelectOptionColorPB.Aqua: 'bg-color-10',
  SelectOptionColorPB.Blue: 'bg-color-12',
  SelectOptionColorPB.Cream: 'bg-color-20',
};

AFColor selectOptionColorToBgAFColor(SelectOptionColorPB color) {
  final value = _selectOptionColorToAFColorMap[color] ?? 'bg-color-14';
  return BuiltinAFColor(value);
}

SelectOptionColorPB afColorToSelectOptionColor(AFColor color) {
  return _selectOptionColorToAFColorMap.entries
      .firstWhere(
        (entry) => entry.value == color.value,
        orElse: () => const MapEntry(SelectOptionColorPB.Purple, 'bg-color-14'),
      )
      .key;
}
