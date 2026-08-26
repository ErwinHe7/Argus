// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_response_error.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ErrorResponseErrorCWProxy {
  ErrorResponseError code(String code);

  ErrorResponseError fieldErrors(List<FieldError> fieldErrors);

  ErrorResponseError message(String message);

  ErrorResponseError requestId(String requestId);

  ErrorResponseError retryAfterSeconds(int? retryAfterSeconds);

  ErrorResponseError retryable(bool retryable);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorResponseError(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorResponseError(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorResponseError call({
    String code,
    List<FieldError> fieldErrors,
    String message,
    String requestId,
    int? retryAfterSeconds,
    bool retryable,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfErrorResponseError.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfErrorResponseError.copyWith.fieldName(...)`
class _$ErrorResponseErrorCWProxyImpl implements _$ErrorResponseErrorCWProxy {
  const _$ErrorResponseErrorCWProxyImpl(this._value);

  final ErrorResponseError _value;

  @override
  ErrorResponseError code(String code) => this(code: code);

  @override
  ErrorResponseError fieldErrors(List<FieldError> fieldErrors) =>
      this(fieldErrors: fieldErrors);

  @override
  ErrorResponseError message(String message) => this(message: message);

  @override
  ErrorResponseError requestId(String requestId) => this(requestId: requestId);

  @override
  ErrorResponseError retryAfterSeconds(int? retryAfterSeconds) =>
      this(retryAfterSeconds: retryAfterSeconds);

  @override
  ErrorResponseError retryable(bool retryable) => this(retryable: retryable);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorResponseError(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorResponseError(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorResponseError call({
    Object? code = const $CopyWithPlaceholder(),
    Object? fieldErrors = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? requestId = const $CopyWithPlaceholder(),
    Object? retryAfterSeconds = const $CopyWithPlaceholder(),
    Object? retryable = const $CopyWithPlaceholder(),
  }) {
    return ErrorResponseError(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      fieldErrors: fieldErrors == const $CopyWithPlaceholder()
          ? _value.fieldErrors
          // ignore: cast_nullable_to_non_nullable
          : fieldErrors as List<FieldError>,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      requestId: requestId == const $CopyWithPlaceholder()
          ? _value.requestId
          // ignore: cast_nullable_to_non_nullable
          : requestId as String,
      retryAfterSeconds: retryAfterSeconds == const $CopyWithPlaceholder()
          ? _value.retryAfterSeconds
          // ignore: cast_nullable_to_non_nullable
          : retryAfterSeconds as int?,
      retryable: retryable == const $CopyWithPlaceholder()
          ? _value.retryable
          // ignore: cast_nullable_to_non_nullable
          : retryable as bool,
    );
  }
}

extension $ErrorResponseErrorCopyWith on ErrorResponseError {
  /// Returns a callable class that can be used as follows: `instanceOfErrorResponseError.copyWith(...)` or like so:`instanceOfErrorResponseError.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ErrorResponseErrorCWProxy get copyWith =>
      _$ErrorResponseErrorCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorResponseError _$ErrorResponseErrorFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ErrorResponseError',
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
        final val = ErrorResponseError(
          code: $checkedConvert('code', (v) => v as String),
          fieldErrors: $checkedConvert(
            'field_errors',
            (v) => (v as List<dynamic>)
                .map((e) => FieldError.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
          message: $checkedConvert('message', (v) => v as String),
          requestId: $checkedConvert('request_id', (v) => v as String),
          retryAfterSeconds: $checkedConvert(
            'retry_after_seconds',
            (v) => (v as num?)?.toInt(),
          ),
          retryable: $checkedConvert('retryable', (v) => v as bool),
        );
        return val;
      },
      fieldKeyMap: const {
        'fieldErrors': 'field_errors',
        'requestId': 'request_id',
        'retryAfterSeconds': 'retry_after_seconds',
      },
    );

Map<String, dynamic> _$ErrorResponseErrorToJson(ErrorResponseError instance) =>
    <String, dynamic>{
      'code': instance.code,
      'field_errors': instance.fieldErrors.map((e) => e.toJson()).toList(),
      'message': instance.message,
      'request_id': instance.requestId,
      'retry_after_seconds': ?instance.retryAfterSeconds,
      'retryable': instance.retryable,
    };
