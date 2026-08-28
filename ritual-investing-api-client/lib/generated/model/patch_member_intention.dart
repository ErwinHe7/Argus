//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/scenario_money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_member_intention.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchMemberIntention {
  /// Returns a new [PatchMemberIntention] instance.
  PatchMemberIntention({this.target, this.targetDate, this.title});

  @JsonKey(name: r'target', required: false, includeIfNull: false)
  final ScenarioMoney? target;

  @JsonKey(name: r'target_date', required: false, includeIfNull: false)
  final DateTime? targetDate;

  @JsonKey(name: r'title', required: false, includeIfNull: false)
  final String? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchMemberIntention &&
          other.target == target &&
          other.targetDate == targetDate &&
          other.title == title;

  @override
  int get hashCode => target.hashCode + targetDate.hashCode + title.hashCode;

  factory PatchMemberIntention.fromJson(Map<String, dynamic> json) =>
      _$PatchMemberIntentionFromJson(json);

  Map<String, dynamic> toJson() => _$PatchMemberIntentionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
