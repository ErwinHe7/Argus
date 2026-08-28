//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'command_admin_editorial_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CommandAdminEditorialRequest {
  /// Returns a new [CommandAdminEditorialRequest] instance.
  CommandAdminEditorialRequest({
    required this.action,

    this.highTrust = false,

    required this.reason,

    required this.revisionId,
  });

  @JsonKey(
    name: r'action',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CommandAdminEditorialRequestActionEnum.unknownDefaultOpenApi,
  )
  final CommandAdminEditorialRequestActionEnum action;

  @JsonKey(
    defaultValue: false,
    name: r'high_trust',
    required: false,
    includeIfNull: false,
  )
  final bool? highTrust;

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: true)
  final String? revisionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandAdminEditorialRequest &&
          other.action == action &&
          other.highTrust == highTrust &&
          other.reason == reason &&
          other.revisionId == revisionId;

  @override
  int get hashCode =>
      action.hashCode +
      highTrust.hashCode +
      reason.hashCode +
      (revisionId == null ? 0 : revisionId.hashCode);

  factory CommandAdminEditorialRequest.fromJson(Map<String, dynamic> json) =>
      _$CommandAdminEditorialRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CommandAdminEditorialRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CommandAdminEditorialRequestActionEnum {
  @JsonValue(r'request_review')
  requestReview(r'request_review'),
  @JsonValue(r'approve')
  approve(r'approve'),
  @JsonValue(r'changes_requested')
  changesRequested(r'changes_requested'),
  @JsonValue(r'publish')
  publish(r'publish'),
  @JsonValue(r'withdraw')
  withdraw(r'withdraw'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CommandAdminEditorialRequestActionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
