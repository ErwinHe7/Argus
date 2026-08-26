//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/admin_ritual_schedule.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_ritual_schedule201_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminRitualSchedule201Response {
  /// Returns a new [CreateAdminRitualSchedule201Response] instance.
  CreateAdminRitualSchedule201Response({
    required this.data,

    required this.meta,
  });

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final AdminRitualSchedule data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminRitualSchedule201Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CreateAdminRitualSchedule201Response.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminRitualSchedule201ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminRitualSchedule201ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
