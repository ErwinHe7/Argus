//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/scenario_money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_member_intention.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateMemberIntention {
  /// Returns a new [CreateMemberIntention] instance.
  CreateMemberIntention({
    required this.target,

    required this.targetDate,

    required this.title,
  });

  @JsonKey(name: r'target', required: true, includeIfNull: false)
  final ScenarioMoney target;

  @JsonKey(name: r'target_date', required: true, includeIfNull: false)
  final DateTime targetDate;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateMemberIntention &&
          other.target == target &&
          other.targetDate == targetDate &&
          other.title == title;

  @override
  int get hashCode => target.hashCode + targetDate.hashCode + title.hashCode;

  factory CreateMemberIntention.fromJson(Map<String, dynamic> json) =>
      _$CreateMemberIntentionFromJson(json);

  Map<String, dynamic> toJson() => _$CreateMemberIntentionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
