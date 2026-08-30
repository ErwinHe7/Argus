//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_session.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathSession {
  /// Returns a new [StarpathSession] instance.
  StarpathSession({
    required this.explicitStart,

    required this.id,

    required this.lastActionAt,

    required this.replacementOfSessionId,

    required this.startedAt,

    required this.state,
  });

  @JsonKey(name: r'explicit_start', required: true, includeIfNull: false)
  final bool explicitStart;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'last_action_at', required: true, includeIfNull: false)
  final DateTime lastActionAt;

  @JsonKey(
    name: r'replacement_of_session_id',
    required: true,
    includeIfNull: true,
  )
  final String? replacementOfSessionId;

  @JsonKey(name: r'started_at', required: true, includeIfNull: false)
  final DateTime startedAt;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: StarpathSessionStateEnum.unknownDefaultOpenApi,
  )
  final StarpathSessionStateEnum state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathSession &&
          other.explicitStart == explicitStart &&
          other.id == id &&
          other.lastActionAt == lastActionAt &&
          other.replacementOfSessionId == replacementOfSessionId &&
          other.startedAt == startedAt &&
          other.state == state;

  @override
  int get hashCode =>
      explicitStart.hashCode +
      id.hashCode +
      lastActionAt.hashCode +
      (replacementOfSessionId == null ? 0 : replacementOfSessionId.hashCode) +
      startedAt.hashCode +
      state.hashCode;

  factory StarpathSession.fromJson(Map<String, dynamic> json) =>
      _$StarpathSessionFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathSessionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum StarpathSessionStateEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'closed')
  closed(r'closed'),
  @JsonValue(r'replaced')
  replaced(r'replaced'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const StarpathSessionStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
