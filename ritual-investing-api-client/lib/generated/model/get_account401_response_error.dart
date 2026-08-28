//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_account401_response_error.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetAccount401ResponseError {
  /// Returns a new [GetAccount401ResponseError] instance.
  GetAccount401ResponseError({
    required this.code,

    required this.fieldErrors,

    required this.message,

    required this.requestId,

    required this.retryable,
  });

  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @JsonKey(name: r'field_errors', required: true, includeIfNull: false)
  final List<Object?> fieldErrors;

  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  @JsonKey(name: r'request_id', required: true, includeIfNull: false)
  final String requestId;

  @JsonKey(name: r'retryable', required: true, includeIfNull: false)
  final bool retryable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetAccount401ResponseError &&
          other.code == code &&
          other.fieldErrors == fieldErrors &&
          other.message == message &&
          other.requestId == requestId &&
          other.retryable == retryable;

  @override
  int get hashCode =>
      code.hashCode +
      fieldErrors.hashCode +
      message.hashCode +
      requestId.hashCode +
      retryable.hashCode;

  factory GetAccount401ResponseError.fromJson(Map<String, dynamic> json) =>
      _$GetAccount401ResponseErrorFromJson(json);

  Map<String, dynamic> toJson() => _$GetAccount401ResponseErrorToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
