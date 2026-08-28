// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_account401_response_error.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAccount401ResponseErrorCWProxy {
  GetAccount401ResponseError code(String code);

  GetAccount401ResponseError fieldErrors(List<Object?> fieldErrors);

  GetAccount401ResponseError message(String message);

  GetAccount401ResponseError requestId(String requestId);

  GetAccount401ResponseError retryable(bool retryable);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAccount401ResponseError(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAccount401ResponseError(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAccount401ResponseError call({
    String code,
    List<Object?> fieldErrors,
    String message,
    String requestId,
    bool retryable,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAccount401ResponseError.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAccount401ResponseError.copyWith.fieldName(...)`
class _$GetAccount401ResponseErrorCWProxyImpl
    implements _$GetAccount401ResponseErrorCWProxy {
  const _$GetAccount401ResponseErrorCWProxyImpl(this._value);

  final GetAccount401ResponseError _value;

  @override
  GetAccount401ResponseError code(String code) => this(code: code);

  @override
  GetAccount401ResponseError fieldErrors(List<Object?> fieldErrors) =>
      this(fieldErrors: fieldErrors);

  @override
  GetAccount401ResponseError message(String message) => this(message: message);

  @override
  GetAccount401ResponseError requestId(String requestId) =>
      this(requestId: requestId);

  @override
  GetAccount401ResponseError retryable(bool retryable) =>
      this(retryable: retryable);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAccount401ResponseError(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAccount401ResponseError(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAccount401ResponseError call({
    Object? code = const $CopyWithPlaceholder(),
    Object? fieldErrors = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? requestId = const $CopyWithPlaceholder(),
    Object? retryable = const $CopyWithPlaceholder(),
  }) {
    return GetAccount401ResponseError(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      fieldErrors: fieldErrors == const $CopyWithPlaceholder()
          ? _value.fieldErrors
          // ignore: cast_nullable_to_non_nullable
          : fieldErrors as List<Object?>,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      requestId: requestId == const $CopyWithPlaceholder()
          ? _value.requestId
          // ignore: cast_nullable_to_non_nullable
          : requestId as String,
      retryable: retryable == const $CopyWithPlaceholder()
          ? _value.retryable
          // ignore: cast_nullable_to_non_nullable
          : retryable as bool,
    );
  }
}

extension $GetAccount401ResponseErrorCopyWith on GetAccount401ResponseError {
  /// Returns a callable class that can be used as follows: `instanceOfGetAccount401ResponseError.copyWith(...)` or like so:`instanceOfGetAccount401ResponseError.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAccount401ResponseErrorCWProxy get copyWith =>
      _$GetAccount401ResponseErrorCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAccount401ResponseError _$GetAccount401ResponseErrorFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'GetAccount401ResponseError',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'code',
        'field_errors',
        'message',
        'request_id',
        'retryable',
      ],
    );
    final val = GetAccount401ResponseError(
      code: $checkedConvert('code', (v) => v as String),
      fieldErrors: $checkedConvert('field_errors', (v) => v as List<dynamic>),
      message: $checkedConvert('message', (v) => v as String),
      requestId: $checkedConvert('request_id', (v) => v as String),
      retryable: $checkedConvert('retryable', (v) => v as bool),
    );
    return val;
  },
  fieldKeyMap: const {'fieldErrors': 'field_errors', 'requestId': 'request_id'},
);

Map<String, dynamic> _$GetAccount401ResponseErrorToJson(
  GetAccount401ResponseError instance,
) => <String, dynamic>{
  'code': instance.code,
  'field_errors': instance.fieldErrors,
  'message': instance.message,
  'request_id': instance.requestId,
  'retryable': instance.retryable,
};
