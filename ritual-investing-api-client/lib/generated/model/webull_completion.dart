//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webull_completion.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebullCompletion {
  /// Returns a new [WebullCompletion] instance.
  WebullCompletion({
    required this.connectionId,

    required this.createdAt,

    required this.outcome,
  });

  @JsonKey(name: r'connection_id', required: true, includeIfNull: false)
  final String connectionId;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(
    name: r'outcome',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WebullCompletionOutcomeEnum.unknownDefaultOpenApi,
  )
  final WebullCompletionOutcomeEnum outcome;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebullCompletion &&
          other.connectionId == connectionId &&
          other.createdAt == createdAt &&
          other.outcome == outcome;

  @override
  int get hashCode =>
      connectionId.hashCode + createdAt.hashCode + outcome.hashCode;

  factory WebullCompletion.fromJson(Map<String, dynamic> json) =>
      _$WebullCompletionFromJson(json);

  Map<String, dynamic> toJson() => _$WebullCompletionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum WebullCompletionOutcomeEnum {
  @JsonValue(r'connected')
  connected(r'connected'),
  @JsonValue(r'denied')
  denied(r'denied'),
  @JsonValue(r'failed')
  failed(r'failed'),
  @JsonValue(r'temporarily_unavailable')
  temporarilyUnavailable(r'temporarily_unavailable'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WebullCompletionOutcomeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
