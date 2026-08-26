//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/error_response_error.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'error_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ErrorResponse {
  /// Returns a new [ErrorResponse] instance.
  ErrorResponse({required this.error});

  @JsonKey(name: r'error', required: true, includeIfNull: false)
  final ErrorResponseError error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ErrorResponse && other.error == error;

  @override
  int get hashCode => error.hashCode;

  factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$ErrorResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
