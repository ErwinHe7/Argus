//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of_evidence_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of_ideas_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf({
    this.artMediaId,

    required this.cadence,

    required this.evidence,

    required this.guidance,

    required this.ideas,

    required this.interpretation,

    required this.marketLabel,

    required this.mode,

    required this.observationAt,

    required this.scenarioKey,

    required this.title,

    required this.uncertainty,
  });

  @JsonKey(name: r'art_media_id', required: false, includeIfNull: false)
  final String? artMediaId;

  @JsonKey(
    name: r'cadence',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfCadenceEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfCadenceEnum
  cadence;

  @JsonKey(name: r'evidence', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner
  >
  evidence;

  @JsonKey(name: r'guidance', required: true, includeIfNull: false)
  final String guidance;

  @JsonKey(name: r'ideas', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner
  >
  ideas;

  @JsonKey(name: r'interpretation', required: true, includeIfNull: false)
  final String interpretation;

  @JsonKey(name: r'market_label', required: true, includeIfNull: false)
  final String marketLabel;

  @JsonKey(
    name: r'mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfModeEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfModeEnum
  mode;

  @JsonKey(name: r'observation_at', required: true, includeIfNull: false)
  final DateTime observationAt;

  @JsonKey(name: r'scenario_key', required: true, includeIfNull: false)
  final String scenarioKey;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'uncertainty', required: true, includeIfNull: false)
  final String uncertainty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf &&
          other.artMediaId == artMediaId &&
          other.cadence == cadence &&
          other.evidence == evidence &&
          other.guidance == guidance &&
          other.ideas == ideas &&
          other.interpretation == interpretation &&
          other.marketLabel == marketLabel &&
          other.mode == mode &&
          other.observationAt == observationAt &&
          other.scenarioKey == scenarioKey &&
          other.title == title &&
          other.uncertainty == uncertainty;

  @override
  int get hashCode =>
      (artMediaId == null ? 0 : artMediaId.hashCode) +
      cadence.hashCode +
      evidence.hashCode +
      guidance.hashCode +
      ideas.hashCode +
      interpretation.hashCode +
      marketLabel.hashCode +
      mode.hashCode +
      observationAt.hashCode +
      scenarioKey.hashCode +
      title.hashCode +
      uncertainty.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfFromJson(
    json,
  );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfCadenceEnum {
  @JsonValue(r'daily')
  daily(r'daily'),
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'moon_cycle')
  moonCycle(r'moon_cycle'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfCadenceEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfModeEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}
