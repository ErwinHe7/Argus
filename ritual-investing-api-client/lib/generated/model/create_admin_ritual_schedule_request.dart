//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_ritual_schedule_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminRitualScheduleRequest {
  /// Returns a new [CreateAdminRitualScheduleRequest] instance.
  CreateAdminRitualScheduleRequest({
    required this.audience,

    required this.effectiveAt,

    required this.localDate,

    required this.mode,

    required this.revisionId,
  });

  @JsonKey(
    name: r'audience',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateAdminRitualScheduleRequestAudienceEnum.unknownDefaultOpenApi,
  )
  final CreateAdminRitualScheduleRequestAudienceEnum audience;

  @JsonKey(name: r'effective_at', required: true, includeIfNull: false)
  final DateTime effectiveAt;

  @JsonKey(name: r'local_date', required: true, includeIfNull: false)
  final DateTime localDate;

  @JsonKey(
    name: r'mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateAdminRitualScheduleRequestModeEnum.unknownDefaultOpenApi,
  )
  final CreateAdminRitualScheduleRequestModeEnum mode;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminRitualScheduleRequest &&
          other.audience == audience &&
          other.effectiveAt == effectiveAt &&
          other.localDate == localDate &&
          other.mode == mode &&
          other.revisionId == revisionId;

  @override
  int get hashCode =>
      audience.hashCode +
      effectiveAt.hashCode +
      localDate.hashCode +
      mode.hashCode +
      revisionId.hashCode;

  factory CreateAdminRitualScheduleRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminRitualScheduleRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminRitualScheduleRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateAdminRitualScheduleRequestAudienceEnum {
  @JsonValue(r'public')
  public(r'public'),
  @JsonValue(r'member')
  member(r'member'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateAdminRitualScheduleRequestAudienceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CreateAdminRitualScheduleRequestModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateAdminRitualScheduleRequestModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
