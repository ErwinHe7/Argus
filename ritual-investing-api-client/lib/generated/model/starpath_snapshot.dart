//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/starpath_progress.dart';
import 'package:ritual_investing_api_client/generated/model/starpath_recall.dart';
import 'package:ritual_investing_api_client/generated/model/starpath_authority.dart';
import 'package:ritual_investing_api_client/generated/model/starpath_session.dart';
import 'package:ritual_investing_api_client/generated/model/starpath_answer_feedback.dart';
import 'package:ritual_investing_api_client/generated/model/starpath_session_theme.dart';
import 'package:ritual_investing_api_client/generated/model/starpath_node.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_snapshot.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathSnapshot {
  /// Returns a new [StarpathSnapshot] instance.
  StarpathSnapshot({
    required this.answer,

    required this.authority,

    required this.availability,

    required this.commandEffect,

    required this.nodes,

    required this.progress,

    required this.recall,

    required this.session,

    required this.theme,

    required this.version,
  });

  @JsonKey(name: r'answer', required: true, includeIfNull: true)
  final StarpathAnswerFeedback? answer;

  @JsonKey(name: r'authority', required: true, includeIfNull: false)
  final StarpathAuthority authority;

  @JsonKey(
    name: r'availability',
    required: true,
    includeIfNull: false,
    unknownEnumValue: StarpathSnapshotAvailabilityEnum.unknownDefaultOpenApi,
  )
  final StarpathSnapshotAvailabilityEnum availability;

  @JsonKey(
    name: r'command_effect',
    required: true,
    includeIfNull: true,
    unknownEnumValue: StarpathSnapshotCommandEffectEnum.unknownDefaultOpenApi,
  )
  final StarpathSnapshotCommandEffectEnum? commandEffect;

  @JsonKey(name: r'nodes', required: true, includeIfNull: false)
  final List<StarpathNode> nodes;

  @JsonKey(name: r'progress', required: true, includeIfNull: true)
  final StarpathProgress? progress;

  @JsonKey(name: r'recall', required: true, includeIfNull: true)
  final StarpathRecall? recall;

  @JsonKey(name: r'session', required: true, includeIfNull: true)
  final StarpathSession? session;

  @JsonKey(name: r'theme', required: true, includeIfNull: true)
  final StarpathSessionTheme? theme;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathSnapshot &&
          other.answer == answer &&
          other.authority == authority &&
          other.availability == availability &&
          other.commandEffect == commandEffect &&
          other.nodes == nodes &&
          other.progress == progress &&
          other.recall == recall &&
          other.session == session &&
          other.theme == theme &&
          other.version == version;

  @override
  int get hashCode =>
      (answer == null ? 0 : answer.hashCode) +
      authority.hashCode +
      availability.hashCode +
      (commandEffect == null ? 0 : commandEffect.hashCode) +
      nodes.hashCode +
      (progress == null ? 0 : progress.hashCode) +
      (recall == null ? 0 : recall.hashCode) +
      (session == null ? 0 : session.hashCode) +
      (theme == null ? 0 : theme.hashCode) +
      version.hashCode;

  factory StarpathSnapshot.fromJson(Map<String, dynamic> json) =>
      _$StarpathSnapshotFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathSnapshotToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum StarpathSnapshotAvailabilityEnum {
  @JsonValue(r'available')
  available(r'available'),
  @JsonValue(r'not_started')
  notStarted(r'not_started'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const StarpathSnapshotAvailabilityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum StarpathSnapshotCommandEffectEnum {
  @JsonValue(r'started')
  started(r'started'),
  @JsonValue(r'resumed')
  resumed(r'resumed'),
  @JsonValue(r'content_replaced')
  contentReplaced(r'content_replaced'),
  @JsonValue(r'wrong_answer')
  wrongAnswer(r'wrong_answer'),
  @JsonValue(r'lesson_completed')
  lessonCompleted(r'lesson_completed'),
  @JsonValue(r'recall_completed')
  recallCompleted(r'recall_completed'),
  @JsonValue(r'recall_skipped')
  recallSkipped(r'recall_skipped'),
  @JsonValue(r'semantic_replay')
  semanticReplay(r'semantic_replay'),
  @JsonValue(r'idempotent_replay')
  idempotentReplay(r'idempotent_replay'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const StarpathSnapshotCommandEffectEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
