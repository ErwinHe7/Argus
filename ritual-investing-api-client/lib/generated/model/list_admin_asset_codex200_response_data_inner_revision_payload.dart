//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of4.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of_evidence_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of_ideas_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of3.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of4_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of6_sections_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of1_risks_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of2.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of5.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of6.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of1.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayload {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayload] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayload({
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

    required this.appearanceReason,

    required this.assetId,

    required this.evidenceClaimIds,

    required this.limitations,

    required this.metricsAsOf,

    required this.risks,

    required this.thesis,

    required this.companyId,

    required this.inclusionRationale,

    required this.summary,

    required this.assets,

    required this.curatorLabel,

    required this.description,

    required this.themeCode,

    required this.creatorId,

    required this.allowedTokens,

    required this.bodyTemplate,

    required this.riskFooter,

    required this.scriptKey,

    required this.surface,

    required this.briefingType,

    required this.sections,

    required this.templateKey,
  });

  @JsonKey(name: r'art_media_id', required: false, includeIfNull: false)
  final String? artMediaId;

  @JsonKey(
    name: r'cadence',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadCadenceEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadCadenceEnum
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
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadModeEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadModeEnum mode;

  @JsonKey(name: r'observation_at', required: true, includeIfNull: false)
  final DateTime observationAt;

  @JsonKey(name: r'scenario_key', required: true, includeIfNull: false)
  final String scenarioKey;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'uncertainty', required: true, includeIfNull: false)
  final String uncertainty;

  @JsonKey(name: r'appearance_reason', required: true, includeIfNull: false)
  final String appearanceReason;

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'evidence_claim_ids', required: true, includeIfNull: false)
  final List<String> evidenceClaimIds;

  @JsonKey(name: r'limitations', required: true, includeIfNull: false)
  final String limitations;

  @JsonKey(name: r'metrics_as_of', required: true, includeIfNull: false)
  final DateTime metricsAsOf;

  @JsonKey(name: r'risks', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner
  >
  risks;

  @JsonKey(name: r'thesis', required: true, includeIfNull: false)
  final String thesis;

  @JsonKey(name: r'company_id', required: true, includeIfNull: false)
  final String companyId;

  @JsonKey(name: r'inclusion_rationale', required: true, includeIfNull: false)
  final String inclusionRationale;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final String summary;

  @JsonKey(name: r'assets', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
  >
  assets;

  @JsonKey(name: r'curator_label', required: true, includeIfNull: false)
  final String curatorLabel;

  @JsonKey(name: r'description', required: true, includeIfNull: false)
  final String description;

  @JsonKey(name: r'theme_code', required: true, includeIfNull: false)
  final String themeCode;

  @JsonKey(name: r'creator_id', required: true, includeIfNull: false)
  final String creatorId;

  @JsonKey(name: r'allowed_tokens', required: true, includeIfNull: false)
  final List<String> allowedTokens;

  @JsonKey(name: r'body_template', required: true, includeIfNull: false)
  final String bodyTemplate;

  @JsonKey(name: r'risk_footer', required: true, includeIfNull: false)
  final String riskFooter;

  @JsonKey(name: r'script_key', required: true, includeIfNull: false)
  final String scriptKey;

  @JsonKey(
    name: r'surface',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadSurfaceEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadSurfaceEnum
  surface;

  @JsonKey(
    name: r'briefing_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadBriefingTypeEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadBriefingTypeEnum
  briefingType;

  @JsonKey(name: r'sections', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  >
  sections;

  @JsonKey(name: r'template_key', required: true, includeIfNull: false)
  final String templateKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInnerRevisionPayload &&
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
          other.uncertainty == uncertainty &&
          other.appearanceReason == appearanceReason &&
          other.assetId == assetId &&
          other.evidenceClaimIds == evidenceClaimIds &&
          other.limitations == limitations &&
          other.metricsAsOf == metricsAsOf &&
          other.risks == risks &&
          other.thesis == thesis &&
          other.companyId == companyId &&
          other.inclusionRationale == inclusionRationale &&
          other.summary == summary &&
          other.assets == assets &&
          other.curatorLabel == curatorLabel &&
          other.description == description &&
          other.themeCode == themeCode &&
          other.creatorId == creatorId &&
          other.allowedTokens == allowedTokens &&
          other.bodyTemplate == bodyTemplate &&
          other.riskFooter == riskFooter &&
          other.scriptKey == scriptKey &&
          other.surface == surface &&
          other.briefingType == briefingType &&
          other.sections == sections &&
          other.templateKey == templateKey;

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
      uncertainty.hashCode +
      appearanceReason.hashCode +
      assetId.hashCode +
      evidenceClaimIds.hashCode +
      limitations.hashCode +
      metricsAsOf.hashCode +
      risks.hashCode +
      thesis.hashCode +
      companyId.hashCode +
      inclusionRationale.hashCode +
      summary.hashCode +
      assets.hashCode +
      curatorLabel.hashCode +
      description.hashCode +
      themeCode.hashCode +
      creatorId.hashCode +
      allowedTokens.hashCode +
      bodyTemplate.hashCode +
      riskFooter.hashCode +
      scriptKey.hashCode +
      surface.hashCode +
      briefingType.hashCode +
      sections.hashCode +
      templateKey.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayload.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionPayloadCadenceEnum {
  @JsonValue(r'daily')
  daily(r'daily'),
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'moon_cycle')
  moonCycle(r'moon_cycle'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionPayloadCadenceEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionPayloadModeEnum {
  @JsonValue(r'tarot')
  tarot(r'tarot'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionPayloadModeEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionPayloadSurfaceEnum {
  @JsonValue(r'ritual')
  ritual(r'ritual'),
  @JsonValue(r'intention')
  intention(r'intention'),
  @JsonValue(r'briefing')
  briefing(r'briefing'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionPayloadSurfaceEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionPayloadBriefingTypeEnum {
  @JsonValue(r'daily')
  daily(r'daily'),
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'moon_cycle')
  moonCycle(r'moon_cycle'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionPayloadBriefingTypeEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}
