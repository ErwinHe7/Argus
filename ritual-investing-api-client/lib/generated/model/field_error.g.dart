// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'field_error.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FieldErrorCWProxy {
  FieldError code(String code);

  FieldError path(String path);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FieldError(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FieldError(...).copyWith(id: 12, name: "My name")
  /// ````
  FieldError call({String code, String path});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFieldError.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFieldError.copyWith.fieldName(...)`
class _$FieldErrorCWProxyImpl implements _$FieldErrorCWProxy {
  const _$FieldErrorCWProxyImpl(this._value);

  final FieldError _value;

  @override
  FieldError code(String code) => this(code: code);

  @override
  FieldError path(String path) => this(path: path);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FieldError(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FieldError(...).copyWith(id: 12, name: "My name")
  /// ````
  FieldError call({
    Object? code = const $CopyWithPlaceholder(),
    Object? path = const $CopyWithPlaceholder(),
  }) {
    return FieldError(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
    );
  }
}

extension $FieldErrorCopyWith on FieldError {
  /// Returns a callable class that can be used as follows: `instanceOfFieldError.copyWith(...)` or like so:`instanceOfFieldError.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FieldErrorCWProxy get copyWith => _$FieldErrorCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FieldError _$FieldErrorFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FieldError', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['code', 'path']);
      final val = FieldError(
        code: $checkedConvert('code', (v) => v as String),
        path: $checkedConvert('path', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$FieldErrorToJson(FieldError instance) =>
    <String, dynamic>{'code': instance.code, 'path': instance.path};
