// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_session_theme.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathSessionThemeCWProxy {
  StarpathSessionTheme accessibleLabel(String accessibleLabel);

  StarpathSessionTheme factualFocus(String factualFocus);

  StarpathSessionTheme horoscopeFrame(String horoscopeFrame);

  StarpathSessionTheme id(String id);

  StarpathSessionTheme key(String key);

  StarpathSessionTheme title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathSessionTheme(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathSessionTheme(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathSessionTheme call({
    String accessibleLabel,
    String factualFocus,
    String horoscopeFrame,
    String id,
    String key,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathSessionTheme.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathSessionTheme.copyWith.fieldName(...)`
class _$StarpathSessionThemeCWProxyImpl
    implements _$StarpathSessionThemeCWProxy {
  const _$StarpathSessionThemeCWProxyImpl(this._value);

  final StarpathSessionTheme _value;

  @override
  StarpathSessionTheme accessibleLabel(String accessibleLabel) =>
      this(accessibleLabel: accessibleLabel);

  @override
  StarpathSessionTheme factualFocus(String factualFocus) =>
      this(factualFocus: factualFocus);

  @override
  StarpathSessionTheme horoscopeFrame(String horoscopeFrame) =>
      this(horoscopeFrame: horoscopeFrame);

  @override
  StarpathSessionTheme id(String id) => this(id: id);

  @override
  StarpathSessionTheme key(String key) => this(key: key);

  @override
  StarpathSessionTheme title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathSessionTheme(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathSessionTheme(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathSessionTheme call({
    Object? accessibleLabel = const $CopyWithPlaceholder(),
    Object? factualFocus = const $CopyWithPlaceholder(),
    Object? horoscopeFrame = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? key = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return StarpathSessionTheme(
      accessibleLabel: accessibleLabel == const $CopyWithPlaceholder()
          ? _value.accessibleLabel
          // ignore: cast_nullable_to_non_nullable
          : accessibleLabel as String,
      factualFocus: factualFocus == const $CopyWithPlaceholder()
          ? _value.factualFocus
          // ignore: cast_nullable_to_non_nullable
          : factualFocus as String,
      horoscopeFrame: horoscopeFrame == const $CopyWithPlaceholder()
          ? _value.horoscopeFrame
          // ignore: cast_nullable_to_non_nullable
          : horoscopeFrame as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      key: key == const $CopyWithPlaceholder()
          ? _value.key
          // ignore: cast_nullable_to_non_nullable
          : key as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $StarpathSessionThemeCopyWith on StarpathSessionTheme {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathSessionTheme.copyWith(...)` or like so:`instanceOfStarpathSessionTheme.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathSessionThemeCWProxy get copyWith =>
      _$StarpathSessionThemeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathSessionTheme _$StarpathSessionThemeFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'StarpathSessionTheme',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'accessible_label',
        'factual_focus',
        'horoscope_frame',
        'id',
        'key',
        'title',
      ],
    );
    final val = StarpathSessionTheme(
      accessibleLabel: $checkedConvert('accessible_label', (v) => v as String),
      factualFocus: $checkedConvert('factual_focus', (v) => v as String),
      horoscopeFrame: $checkedConvert('horoscope_frame', (v) => v as String),
      id: $checkedConvert('id', (v) => v as String),
      key: $checkedConvert('key', (v) => v as String),
      title: $checkedConvert('title', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'accessibleLabel': 'accessible_label',
    'factualFocus': 'factual_focus',
    'horoscopeFrame': 'horoscope_frame',
  },
);

Map<String, dynamic> _$StarpathSessionThemeToJson(
  StarpathSessionTheme instance,
) => <String, dynamic>{
  'accessible_label': instance.accessibleLabel,
  'factual_focus': instance.factualFocus,
  'horoscope_frame': instance.horoscopeFrame,
  'id': instance.id,
  'key': instance.key,
  'title': instance.title,
};
