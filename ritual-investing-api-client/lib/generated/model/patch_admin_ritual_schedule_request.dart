//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_admin_ritual_schedule_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchAdminRitualScheduleRequest {
  /// Returns a new [PatchAdminRitualScheduleRequest] instance.
  PatchAdminRitualScheduleRequest({this.effectiveAt, this.revisionId});

  @JsonKey(name: r'effective_at', required: false, includeIfNull: false)
  final DateTime? effectiveAt;

  @JsonKey(name: r'revision_id', required: false, includeIfNull: false)
  final String? revisionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchAdminRitualScheduleRequest &&
          other.effectiveAt == effectiveAt &&
          other.revisionId == revisionId;

  @override
  int get hashCode => effectiveAt.hashCode + revisionId.hashCode;

  factory PatchAdminRitualScheduleRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchAdminRitualScheduleRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchAdminRitualScheduleRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
