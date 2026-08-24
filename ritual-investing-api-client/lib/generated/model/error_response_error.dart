//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/field_error.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'error_response_error.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ErrorResponseError {
  /// Returns a new [ErrorResponseError] instance.
  ErrorResponseError({
    required this.code,

    required this.fieldErrors,

    required this.message,

    required this.requestId,

    this.retryAfterSeconds,

    required this.retryable,
  });

  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @JsonKey(name: r'field_errors', required: true, includeIfNull: false)
  final List<FieldError> fieldErrors;

  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  /// Server-assigned request correlation identifier.
  @JsonKey(name: r'request_id', required: true, includeIfNull: false)
  final String requestId;

  // minimum: 0
  // maximum: 86400
  @JsonKey(name: r'retry_after_seconds', required: false, includeIfNull: false)
  final int? retryAfterSeconds;

  @JsonKey(name: r'retryable', required: true, includeIfNull: false)
  final bool retryable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorResponseError &&
          other.code == code &&
          other.fieldErrors == fieldErrors &&
          other.message == message &&
          other.requestId == requestId &&
          other.retryAfterSeconds == retryAfterSeconds &&
          other.retryable == retryable;

  @override
  int get hashCode =>
      code.hashCode +
      fieldErrors.hashCode +
      message.hashCode +
      requestId.hashCode +
      retryAfterSeconds.hashCode +
      retryable.hashCode;

  factory ErrorResponseError.fromJson(Map<String, dynamic> json) =>
      _$ErrorResponseErrorFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorResponseErrorToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
