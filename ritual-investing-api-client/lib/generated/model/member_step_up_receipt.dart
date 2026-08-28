//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_step_up_receipt.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberStepUpReceipt {
  /// Returns a new [MemberStepUpReceipt] instance.
  MemberStepUpReceipt({
    required this.action,

    required this.expiresAt,

    required this.receipt,

    required this.sessionId,

    required this.userId,
  });

  @JsonKey(
    name: r'action',
    required: true,
    includeIfNull: false,
    unknownEnumValue: MemberStepUpReceiptActionEnum.unknownDefaultOpenApi,
  )
  final MemberStepUpReceiptActionEnum action;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'receipt', required: true, includeIfNull: false)
  final String receipt;

  @JsonKey(name: r'session_id', required: true, includeIfNull: false)
  final String sessionId;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberStepUpReceipt &&
          other.action == action &&
          other.expiresAt == expiresAt &&
          other.receipt == receipt &&
          other.sessionId == sessionId &&
          other.userId == userId;

  @override
  int get hashCode =>
      action.hashCode +
      expiresAt.hashCode +
      receipt.hashCode +
      sessionId.hashCode +
      userId.hashCode;

  factory MemberStepUpReceipt.fromJson(Map<String, dynamic> json) =>
      _$MemberStepUpReceiptFromJson(json);

  Map<String, dynamic> toJson() => _$MemberStepUpReceiptToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MemberStepUpReceiptActionEnum {
  @JsonValue(r'webull_disconnect')
  webullDisconnect(r'webull_disconnect'),
  @JsonValue(r'argus_delete')
  argusDelete(r'argus_delete'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MemberStepUpReceiptActionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
