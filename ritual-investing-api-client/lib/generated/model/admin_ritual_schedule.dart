//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_ritual_schedule.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminRitualSchedule {
  /// Returns a new [AdminRitualSchedule] instance.
  AdminRitualSchedule({
    required this.audience,

    required this.effectiveAt,

    required this.etag,

    required this.id,

    required this.localDate,

    required this.mode,

    required this.revisionId,

    required this.state,

    required this.version,
  });

  @JsonKey(
    name: r'audience',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminRitualScheduleAudienceEnum.unknownDefaultOpenApi,
  )
  final AdminRitualScheduleAudienceEnum audience;

  @JsonKey(name: r'effective_at', required: true, includeIfNull: false)
  final DateTime effectiveAt;

  @JsonKey(name: r'etag', required: true, includeIfNull: false)
  final String etag;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'local_date', required: true, includeIfNull: false)
  final DateTime localDate;

  @JsonKey(
    name: r'mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminRitualScheduleModeEnum.unknownDefaultOpenApi,
  )
  final AdminRitualScheduleModeEnum mode;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminRitualScheduleStateEnum.unknownDefaultOpenApi,
  )
  final AdminRitualScheduleStateEnum state;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminRitualSchedule &&
          other.audience == audience &&
          other.effectiveAt == effectiveAt &&
          other.etag == etag &&
          other.id == id &&
          other.localDate == localDate &&
          other.mode == mode &&
          other.revisionId == revisionId &&
          other.state == state &&
          other.version == version;

  @override
  int get hashCode =>
      audience.hashCode +
      effectiveAt.hashCode +
      etag.hashCode +
      id.hashCode +
      localDate.hashCode +
      mode.hashCode +
      revisionId.hashCode +
      state.hashCode +
      version.hashCode;

  factory AdminRitualSchedule.fromJson(Map<String, dynamic> json) =>
      _$AdminRitualScheduleFromJson(json);

  Map<String, dynamic> toJson() => _$AdminRitualScheduleToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminRitualScheduleAudienceEnum {
  @JsonValue(r'public')
  public(r'public'),
  @JsonValue(r'member')
  member(r'member'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminRitualScheduleAudienceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum AdminRitualScheduleModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminRitualScheduleModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum AdminRitualScheduleStateEnum {
  @JsonValue(r'draft')
  draft(r'draft'),
  @JsonValue(r'scheduled')
  scheduled(r'scheduled'),
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'withdrawn')
  withdrawn(r'withdrawn'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminRitualScheduleStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
