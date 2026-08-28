//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/scenario_money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_intention.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberIntention {
  /// Returns a new [MemberIntention] instance.
  MemberIntention({
    required this.createdAt,

    required this.id,

    required this.status,

    required this.target,

    required this.targetDate,

    required this.title,

    required this.version,
  });

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: MemberIntentionStatusEnum.unknownDefaultOpenApi,
  )
  final MemberIntentionStatusEnum status;

  @JsonKey(name: r'target', required: true, includeIfNull: false)
  final ScenarioMoney target;

  @JsonKey(name: r'target_date', required: true, includeIfNull: false)
  final DateTime targetDate;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberIntention &&
          other.createdAt == createdAt &&
          other.id == id &&
          other.status == status &&
          other.target == target &&
          other.targetDate == targetDate &&
          other.title == title &&
          other.version == version;

  @override
  int get hashCode =>
      createdAt.hashCode +
      id.hashCode +
      status.hashCode +
      target.hashCode +
      targetDate.hashCode +
      title.hashCode +
      version.hashCode;

  factory MemberIntention.fromJson(Map<String, dynamic> json) =>
      _$MemberIntentionFromJson(json);

  Map<String, dynamic> toJson() => _$MemberIntentionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MemberIntentionStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'archived')
  archived(r'archived'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MemberIntentionStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
