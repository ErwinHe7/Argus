// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ErrorResponseCWProxy {
  ErrorResponse error(ErrorResponseError error);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorResponse call({ErrorResponseError error});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfErrorResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfErrorResponse.copyWith.fieldName(...)`
class _$ErrorResponseCWProxyImpl implements _$ErrorResponseCWProxy {
  const _$ErrorResponseCWProxyImpl(this._value);

  final ErrorResponse _value;

  @override
  ErrorResponse error(ErrorResponseError error) => this(error: error);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorResponse call({Object? error = const $CopyWithPlaceholder()}) {
    return ErrorResponse(
      error: error == const $CopyWithPlaceholder()
          ? _value.error
          // ignore: cast_nullable_to_non_nullable
          : error as ErrorResponseError,
    );
  }
}

extension $ErrorResponseCopyWith on ErrorResponse {
  /// Returns a callable class that can be used as follows: `instanceOfErrorResponse.copyWith(...)` or like so:`instanceOfErrorResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ErrorResponseCWProxy get copyWith => _$ErrorResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorResponse _$ErrorResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ErrorResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['error']);
      final val = ErrorResponse(
        error: $checkedConvert(
          'error',
          (v) => ErrorResponseError.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ErrorResponseToJson(ErrorResponse instance) =>
    <String, dynamic>{'error': instance.error.toJson()};
