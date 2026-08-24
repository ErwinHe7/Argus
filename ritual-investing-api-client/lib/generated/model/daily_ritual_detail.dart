//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/rowan_counsel.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_detail_revision.dart';
import 'package:ritual_investing_api_client/generated/model/evidence_summary.dart';
import 'package:ritual_investing_api_client/generated/model/ritual_asset_idea.dart';
import 'package:ritual_investing_api_client/generated/model/art_reference.dart';
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily_ritual_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DailyRitualDetail {
  /// Returns a new [DailyRitualDetail] instance.
  DailyRitualDetail({
    required this.art,

    required this.assignmentId,

    required this.completedAt,

    required this.date,

    required this.demo,

    required this.evidence,

    required this.guidance,

    required this.ideas,

    required this.interpretation,

    required this.marketLabel,

    required this.mode,

    required this.revealedAt,

    required this.revision,

    required this.rowan,

    required this.state,

    required this.title,

    required this.version,
  });

  @JsonKey(name: r'art', required: true, includeIfNull: false)
  final ArtReference art;

  @JsonKey(name: r'assignment_id', required: true, includeIfNull: false)
  final String assignmentId;

  @JsonKey(name: r'completed_at', required: true, includeIfNull: true)
  final DateTime? completedAt;

  @JsonKey(name: r'date', required: true, includeIfNull: false)
  final DateTime date;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(name: r'evidence', required: true, includeIfNull: false)
  final List<EvidenceSummary> evidence;

  @JsonKey(name: r'guidance', required: true, includeIfNull: false)
  final String guidance;

  @JsonKey(name: r'ideas', required: true, includeIfNull: false)
  final List<RitualAssetIdea> ideas;

  @JsonKey(name: r'interpretation', required: true, includeIfNull: false)
  final String interpretation;

  @JsonKey(name: r'market_label', required: true, includeIfNull: false)
  final String marketLabel;

  @JsonKey(
    name: r'mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DailyRitualDetailModeEnum.unknownDefaultOpenApi,
  )
  final DailyRitualDetailModeEnum mode;

  @JsonKey(name: r'revealed_at', required: true, includeIfNull: true)
  final DateTime? revealedAt;

  @JsonKey(name: r'revision', required: true, includeIfNull: false)
  final DailyRitualDetailRevision revision;

  @JsonKey(name: r'rowan', required: true, includeIfNull: false)
  final RowanCounsel rowan;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DailyRitualDetailStateEnum.unknownDefaultOpenApi,
  )
  final DailyRitualDetailStateEnum state;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRitualDetail &&
          other.art == art &&
          other.assignmentId == assignmentId &&
          other.completedAt == completedAt &&
          other.date == date &&
          other.demo == demo &&
          other.evidence == evidence &&
          other.guidance == guidance &&
          other.ideas == ideas &&
          other.interpretation == interpretation &&
          other.marketLabel == marketLabel &&
          other.mode == mode &&
          other.revealedAt == revealedAt &&
          other.revision == revision &&
          other.rowan == rowan &&
          other.state == state &&
          other.title == title &&
          other.version == version;

  @override
  int get hashCode =>
      art.hashCode +
      assignmentId.hashCode +
      (completedAt == null ? 0 : completedAt.hashCode) +
      date.hashCode +
      demo.hashCode +
      evidence.hashCode +
      guidance.hashCode +
      ideas.hashCode +
      interpretation.hashCode +
      marketLabel.hashCode +
      mode.hashCode +
      (revealedAt == null ? 0 : revealedAt.hashCode) +
      revision.hashCode +
      rowan.hashCode +
      state.hashCode +
      title.hashCode +
      version.hashCode;

  factory DailyRitualDetail.fromJson(Map<String, dynamic> json) =>
      _$DailyRitualDetailFromJson(json);

  Map<String, dynamic> toJson() => _$DailyRitualDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DailyRitualDetailModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DailyRitualDetailModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum DailyRitualDetailStateEnum {
  @JsonValue(r'assigned')
  assigned(r'assigned'),
  @JsonValue(r'revealed')
  revealed(r'revealed'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DailyRitualDetailStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
