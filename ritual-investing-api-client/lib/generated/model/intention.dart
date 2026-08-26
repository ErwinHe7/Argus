//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'intention.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Intention {
  /// Returns a new [Intention] instance.
  Intention({
    required this.demo,

    required this.id,

    required this.latestProjectionId,

    required this.portfolioId,

    required this.progress,

    required this.progressBps,

    required this.status,

    required this.target,

    required this.targetDate,

    required this.title,

    required this.version,
  });

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'latest_projection_id', required: true, includeIfNull: true)
  final String? latestProjectionId;

  @JsonKey(name: r'portfolio_id', required: true, includeIfNull: false)
  final String portfolioId;

  @JsonKey(name: r'progress', required: true, includeIfNull: false)
  final Money progress;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'progress_bps', required: true, includeIfNull: false)
  final int progressBps;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: IntentionStatusEnum.unknownDefaultOpenApi,
  )
  final IntentionStatusEnum status;

  @JsonKey(name: r'target', required: true, includeIfNull: false)
  final Money target;

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
      other is Intention &&
          other.demo == demo &&
          other.id == id &&
          other.latestProjectionId == latestProjectionId &&
          other.portfolioId == portfolioId &&
          other.progress == progress &&
          other.progressBps == progressBps &&
          other.status == status &&
          other.target == target &&
          other.targetDate == targetDate &&
          other.title == title &&
          other.version == version;

  @override
  int get hashCode =>
      demo.hashCode +
      id.hashCode +
      (latestProjectionId == null ? 0 : latestProjectionId.hashCode) +
      portfolioId.hashCode +
      progress.hashCode +
      progressBps.hashCode +
      status.hashCode +
      target.hashCode +
      targetDate.hashCode +
      title.hashCode +
      version.hashCode;

  factory Intention.fromJson(Map<String, dynamic> json) =>
      _$IntentionFromJson(json);

  Map<String, dynamic> toJson() => _$IntentionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum IntentionStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'archived')
  archived(r'archived'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const IntentionStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
