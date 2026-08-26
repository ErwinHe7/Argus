//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'request_account_deletion_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RequestAccountDeletionRequest {
  /// Returns a new [RequestAccountDeletionRequest] instance.
  RequestAccountDeletionRequest({required this.confirmation});

  @JsonKey(
    name: r'confirmation',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RequestAccountDeletionRequestConfirmationEnum.unknownDefaultOpenApi,
  )
  final RequestAccountDeletionRequestConfirmationEnum confirmation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestAccountDeletionRequest &&
          other.confirmation == confirmation;

  @override
  int get hashCode => confirmation.hashCode;

  factory RequestAccountDeletionRequest.fromJson(Map<String, dynamic> json) =>
      _$RequestAccountDeletionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RequestAccountDeletionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RequestAccountDeletionRequestConfirmationEnum {
  @JsonValue(r'DELETE')
  DELETE(r'DELETE'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RequestAccountDeletionRequestConfirmationEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
