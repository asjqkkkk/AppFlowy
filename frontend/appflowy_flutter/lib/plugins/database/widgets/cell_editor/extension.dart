import 'package:appflowy/features/color_picker/color_picker.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/select_option_entities.pb.dart';

const Map<SelectOptionColorPB, (String, String)>
    _selectOptionColorToAFColorMap = {
  SelectOptionColorPB.SelectOptionColor1: (
    'tag-fill-1-light',
    'tag-text-1-light'
  ),
  SelectOptionColorPB.SelectOptionColor2: (
    'tag-fill-2-light',
    'tag-text-2-light'
  ),
  SelectOptionColorPB.SelectOptionColor3: (
    'tag-fill-3-light',
    'tag-text-3-light'
  ),
  SelectOptionColorPB.SelectOptionColor4: (
    'tag-fill-4-light',
    'tag-text-4-light'
  ),
  SelectOptionColorPB.SelectOptionColor5: (
    'tag-fill-5-light',
    'tag-text-5-light'
  ),
  SelectOptionColorPB.SelectOptionColor6: (
    'tag-fill-6-light',
    'tag-text-6-light'
  ),
  SelectOptionColorPB.SelectOptionColor7: (
    'tag-fill-7-light',
    'tag-text-7-light'
  ),
  SelectOptionColorPB.SelectOptionColor8: (
    'tag-fill-8-light',
    'tag-text-8-light'
  ),
  SelectOptionColorPB.SelectOptionColor9: (
    'tag-fill-9-light',
    'tag-text-9-light'
  ),
  SelectOptionColorPB.SelectOptionColor10: (
    'tag-fill-10-light',
    'tag-text-10-light'
  ),
  SelectOptionColorPB.SelectOptionColor11: (
    'tag-fill-1-thick',
    'tag-text-1-thick'
  ),
  SelectOptionColorPB.SelectOptionColor12: (
    'tag-fill-2-thick',
    'tag-text-2-thick'
  ),
  SelectOptionColorPB.SelectOptionColor13: (
    'tag-fill-3-thick',
    'tag-text-3-thick'
  ),
  SelectOptionColorPB.SelectOptionColor14: (
    'tag-fill-4-thick',
    'tag-text-4-thick'
  ),
  SelectOptionColorPB.SelectOptionColor15: (
    'tag-fill-5-thick',
    'tag-text-5-thick'
  ),
  SelectOptionColorPB.SelectOptionColor16: (
    'tag-fill-6-thick',
    'tag-text-6-thick'
  ),
  SelectOptionColorPB.SelectOptionColor17: (
    'tag-fill-7-thick',
    'tag-text-7-thick'
  ),
  SelectOptionColorPB.SelectOptionColor18: (
    'tag-fill-8-thick',
    'tag-text-8-thick'
  ),
  SelectOptionColorPB.SelectOptionColor19: (
    'tag-fill-9-thick',
    'tag-text-9-thick'
  ),
  SelectOptionColorPB.SelectOptionColor20: (
    'tag-fill-10-thick',
    'tag-text-10-thick'
  ),
};

AFColor selectOptionColorToBgAFColor(SelectOptionColorPB color) {
  final value = _selectOptionColorToAFColorMap[color]?.$1 ?? 'tag-fill-1-light';
  return BuiltinAFColor(value);
}

AFColor selectOptionColorToTextAFColor(SelectOptionColorPB color) {
  final value = _selectOptionColorToAFColorMap[color]?.$2 ?? 'tag-text-1-light';
  return BuiltinAFColor(value);
}

SelectOptionColorPB afColorToSelectOptionColor(AFColor color) {
  return switch (color.value) {
    'tag-fill-1-light' => SelectOptionColorPB.SelectOptionColor1,
    'tag-fill-2-light' => SelectOptionColorPB.SelectOptionColor2,
    'tag-fill-3-light' => SelectOptionColorPB.SelectOptionColor3,
    'tag-fill-4-light' => SelectOptionColorPB.SelectOptionColor4,
    'tag-fill-5-light' => SelectOptionColorPB.SelectOptionColor5,
    'tag-fill-6-light' => SelectOptionColorPB.SelectOptionColor6,
    'tag-fill-7-light' => SelectOptionColorPB.SelectOptionColor7,
    'tag-fill-8-light' => SelectOptionColorPB.SelectOptionColor8,
    'tag-fill-9-light' => SelectOptionColorPB.SelectOptionColor9,
    'tag-fill-10-light' => SelectOptionColorPB.SelectOptionColor10,
    'tag-fill-1-thick' => SelectOptionColorPB.SelectOptionColor11,
    'tag-fill-2-thick' => SelectOptionColorPB.SelectOptionColor12,
    'tag-fill-3-thick' => SelectOptionColorPB.SelectOptionColor13,
    'tag-fill-4-thick' => SelectOptionColorPB.SelectOptionColor14,
    'tag-fill-5-thick' => SelectOptionColorPB.SelectOptionColor15,
    'tag-fill-6-thick' => SelectOptionColorPB.SelectOptionColor16,
    'tag-fill-7-thick' => SelectOptionColorPB.SelectOptionColor17,
    'tag-fill-8-thick' => SelectOptionColorPB.SelectOptionColor18,
    'tag-fill-9-thick' => SelectOptionColorPB.SelectOptionColor19,
    'tag-fill-10-thick' => SelectOptionColorPB.SelectOptionColor20,
    _ => SelectOptionColorPB.SelectOptionColor1,
  };
}
