import 'package:ritual_investing_api_client/generated/model/admin_session.dart';
import 'package:ritual_investing_api_client/generated/model/admin_session_response.dart';
import 'package:ritual_investing_api_client/generated/model/art_reference.dart';
import 'package:ritual_investing_api_client/generated/model/asset_codex_detail.dart';
import 'package:ritual_investing_api_client/generated/model/asset_codex_detail_risks_inner.dart';
import 'package:ritual_investing_api_client/generated/model/asset_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/asset_comparison.dart';
import 'package:ritual_investing_api_client/generated/model/asset_comparison_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/asset_comparison_response.dart';
import 'package:ritual_investing_api_client/generated/model/asset_detail_response.dart';
import 'package:ritual_investing_api_client/generated/model/asset_evidence_response.dart';
import 'package:ritual_investing_api_client/generated/model/asset_metric.dart';
import 'package:ritual_investing_api_client/generated/model/asset_metrics_response.dart';
import 'package:ritual_investing_api_client/generated/model/asset_summary.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_detail.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_detail_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_detail_response.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_summary.dart';
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:ritual_investing_api_client/generated/model/compare_assets_request.dart';
import 'package:ritual_investing_api_client/generated/model/coven_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/coven_detail_response.dart';
import 'package:ritual_investing_api_client/generated/model/coven_entry_detail.dart';
import 'package:ritual_investing_api_client/generated/model/coven_evidence_response.dart';
import 'package:ritual_investing_api_client/generated/model/coven_qualification.dart';
import 'package:ritual_investing_api_client/generated/model/coven_summary.dart';
import 'package:ritual_investing_api_client/generated/model/creator_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_detail.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_detail_revision.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_preview.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_response.dart';
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/discover_item.dart';
import 'package:ritual_investing_api_client/generated/model/discover_item_one_of.dart';
import 'package:ritual_investing_api_client/generated/model/discover_item_one_of1.dart';
import 'package:ritual_investing_api_client/generated/model/discover_item_one_of2.dart';
import 'package:ritual_investing_api_client/generated/model/discover_item_one_of3.dart';
import 'package:ritual_investing_api_client/generated/model/discover_response.dart';
import 'package:ritual_investing_api_client/generated/model/error_response.dart';
import 'package:ritual_investing_api_client/generated/model/error_response_error.dart';
import 'package:ritual_investing_api_client/generated/model/evidence_detail.dart';
import 'package:ritual_investing_api_client/generated/model/evidence_detail_source.dart';
import 'package:ritual_investing_api_client/generated/model/evidence_summary.dart';
import 'package:ritual_investing_api_client/generated/model/field_error.dart';
import 'package:ritual_investing_api_client/generated/model/get_ritual_assignment200_response.dart';
import 'package:ritual_investing_api_client/generated/model/grimoire_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/grimoire_detail.dart';
import 'package:ritual_investing_api_client/generated/model/grimoire_detail_response.dart';
import 'package:ritual_investing_api_client/generated/model/grimoire_summary.dart';
import 'package:ritual_investing_api_client/generated/model/health_response.dart';
import 'package:ritual_investing_api_client/generated/model/health_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/open_api_document.dart';
import 'package:ritual_investing_api_client/generated/model/public_asset_teaser.dart';
import 'package:ritual_investing_api_client/generated/model/public_coven_detail_response.dart';
import 'package:ritual_investing_api_client/generated/model/public_coven_response.dart';
import 'package:ritual_investing_api_client/generated/model/public_coven_teaser.dart';
import 'package:ritual_investing_api_client/generated/model/public_daily_ritual_response.dart';
import 'package:ritual_investing_api_client/generated/model/public_discover_item.dart';
import 'package:ritual_investing_api_client/generated/model/public_discover_item_one_of.dart';
import 'package:ritual_investing_api_client/generated/model/public_discover_item_one_of1.dart';
import 'package:ritual_investing_api_client/generated/model/public_discover_item_one_of2.dart';
import 'package:ritual_investing_api_client/generated/model/public_discover_item_one_of3.dart';
import 'package:ritual_investing_api_client/generated/model/public_discover_response.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/ritual_asset_idea.dart';
import 'package:ritual_investing_api_client/generated/model/ritual_evidence_response.dart';
import 'package:ritual_investing_api_client/generated/model/ritual_history_item.dart';
import 'package:ritual_investing_api_client/generated/model/ritual_history_response.dart';
import 'package:ritual_investing_api_client/generated/model/rowan_counsel.dart';
import 'package:ritual_investing_api_client/generated/model/rowan_counsel_response.dart';
import 'package:ritual_investing_api_client/generated/model/search_response.dart';
import 'package:ritual_investing_api_client/generated/model/search_result.dart';
import 'package:ritual_investing_api_client/generated/model/seeded_creator.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_account.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_default_portfolio.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_entitlement.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_onboarding.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_preferences.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_profile.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_response.dart';

final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

ReturnType deserialize<ReturnType, BaseType>(
  dynamic value,
  String targetType, {
  bool growable = true,
}) {
  switch (targetType) {
    case 'String':
      return '$value' as ReturnType;
    case 'int':
      return (value is int ? value : int.parse('$value')) as ReturnType;
    case 'bool':
      if (value is bool) {
        return value as ReturnType;
      }
      final valueString = '$value'.toLowerCase();
      return (valueString == 'true' || valueString == '1') as ReturnType;
    case 'double':
      return (value is double ? value : double.parse('$value')) as ReturnType;
    case 'AdminSession':
      return AdminSession.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AdminSessionResponse':
      return AdminSessionResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ArtReference':
      return ArtReference.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AssetCodexDetail':
      return AssetCodexDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AssetCodexDetailRisksInner':
      return AssetCodexDetailRisksInner.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AssetCollectionResponse':
      return AssetCollectionResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AssetComparison':
      return AssetComparison.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AssetComparisonAssetsInner':
      return AssetComparisonAssetsInner.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AssetComparisonResponse':
      return AssetComparisonResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AssetDetailResponse':
      return AssetDetailResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AssetEvidenceResponse':
      return AssetEvidenceResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AssetMetric':
      return AssetMetric.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AssetMetricsResponse':
      return AssetMetricsResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AssetSummary':
      return AssetSummary.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CircleTemplateCollectionResponse':
      return CircleTemplateCollectionResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CircleTemplateDetail':
      return CircleTemplateDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CircleTemplateDetailAssetsInner':
      return CircleTemplateDetailAssetsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CircleTemplateDetailResponse':
      return CircleTemplateDetailResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CircleTemplateSummary':
      return CircleTemplateSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CollectionMeta':
      return CollectionMeta.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CompareAssetsRequest':
      return CompareAssetsRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CovenCollectionResponse':
      return CovenCollectionResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CovenDetailResponse':
      return CovenDetailResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CovenEntryDetail':
      return CovenEntryDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CovenEvidenceResponse':
      return CovenEvidenceResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CovenQualification':
      return CovenQualification.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CovenSummary':
      return CovenSummary.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CreatorCollectionResponse':
      return CreatorCollectionResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DailyRitualDetail':
      return DailyRitualDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DailyRitualDetailRevision':
      return DailyRitualDetailRevision.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DailyRitualPreview':
      return DailyRitualPreview.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DailyRitualResponse':
      return DailyRitualResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DemoDisclosure':
      return DemoDisclosure.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DiscoverItem':
      return DiscoverItem.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DiscoverItemOneOf':
      return DiscoverItemOneOf.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DiscoverItemOneOf1':
      return DiscoverItemOneOf1.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DiscoverItemOneOf2':
      return DiscoverItemOneOf2.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DiscoverItemOneOf3':
      return DiscoverItemOneOf3.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DiscoverResponse':
      return DiscoverResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ErrorResponse':
      return ErrorResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ErrorResponseError':
      return ErrorResponseError.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'EvidenceDetail':
      return EvidenceDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'EvidenceDetailSource':
      return EvidenceDetailSource.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'EvidenceSummary':
      return EvidenceSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'FieldError':
      return FieldError.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'GetRitualAssignment200Response':
      return GetRitualAssignment200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'GrimoireCollectionResponse':
      return GrimoireCollectionResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GrimoireDetail':
      return GrimoireDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GrimoireDetailResponse':
      return GrimoireDetailResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GrimoireSummary':
      return GrimoireSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'HealthResponse':
      return HealthResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'HealthResponseData':
      return HealthResponseData.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OpenApiDocument':
      return OpenApiDocument.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicAssetTeaser':
      return PublicAssetTeaser.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicCovenDetailResponse':
      return PublicCovenDetailResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicCovenResponse':
      return PublicCovenResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicCovenTeaser':
      return PublicCovenTeaser.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicDailyRitualResponse':
      return PublicDailyRitualResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicDiscoverItem':
      return PublicDiscoverItem.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicDiscoverItemOneOf':
      return PublicDiscoverItemOneOf.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicDiscoverItemOneOf1':
      return PublicDiscoverItemOneOf1.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicDiscoverItemOneOf2':
      return PublicDiscoverItemOneOf2.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicDiscoverItemOneOf3':
      return PublicDiscoverItemOneOf3.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicDiscoverResponse':
      return PublicDiscoverResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ResponseMeta':
      return ResponseMeta.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'RitualAssetIdea':
      return RitualAssetIdea.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RitualEvidenceResponse':
      return RitualEvidenceResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RitualHistoryItem':
      return RitualHistoryItem.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RitualHistoryResponse':
      return RitualHistoryResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RowanCounsel':
      return RowanCounsel.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'RowanCounselResponse':
      return RowanCounselResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SearchResponse':
      return SearchResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SearchResult':
      return SearchResult.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SeededCreator':
      return SeededCreator.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionBootstrap':
      return SessionBootstrap.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionBootstrapAccount':
      return SessionBootstrapAccount.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionBootstrapDefaultPortfolio':
      return SessionBootstrapDefaultPortfolio.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'SessionBootstrapEntitlement':
      return SessionBootstrapEntitlement.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionBootstrapOnboarding':
      return SessionBootstrapOnboarding.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionBootstrapPreferences':
      return SessionBootstrapPreferences.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionBootstrapProfile':
      return SessionBootstrapProfile.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SessionBootstrapResponse':
      return SessionBootstrapResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    default:
      RegExpMatch? match;

      if (value is List && (match = _regList.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toList(growable: growable)
            as ReturnType;
      }
      if (value is Set && (match = _regSet.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toSet()
            as ReturnType;
      }
      if (value is Map && (match = _regMap.firstMatch(targetType)) != null) {
        targetType = match![1]!.trim(); // ignore: parameter_assignments
        return Map<String, BaseType>.fromIterables(
              value.keys as Iterable<String>,
              value.values.map(
                (dynamic v) => deserialize<BaseType, BaseType>(
                  v,
                  targetType,
                  growable: growable,
                ),
              ),
            )
            as ReturnType;
      }
      break;
  }
  throw Exception('Cannot deserialize');
}
