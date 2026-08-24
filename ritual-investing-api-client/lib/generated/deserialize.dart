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
import 'package:ritual_investing_api_client/generated/model/astrology_profile.dart';
import 'package:ritual_investing_api_client/generated/model/astrology_profile_response.dart';
import 'package:ritual_investing_api_client/generated/model/circle_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/circle_response.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_detail.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_detail_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_detail_response.dart';
import 'package:ritual_investing_api_client/generated/model/circle_template_summary.dart';
import 'package:ritual_investing_api_client/generated/model/circle_view.dart';
import 'package:ritual_investing_api_client/generated/model/circle_view_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:ritual_investing_api_client/generated/model/commit_order200_response.dart';
import 'package:ritual_investing_api_client/generated/model/commit_order_request.dart';
import 'package:ritual_investing_api_client/generated/model/compare_assets_request.dart';
import 'package:ritual_investing_api_client/generated/model/confirm_demo_checkout200_response.dart';
import 'package:ritual_investing_api_client/generated/model/consent_receipt.dart';
import 'package:ritual_investing_api_client/generated/model/consent_receipt_response.dart';
import 'package:ritual_investing_api_client/generated/model/copy_circle_template201_response.dart';
import 'package:ritual_investing_api_client/generated/model/copy_circle_template_request.dart';
import 'package:ritual_investing_api_client/generated/model/coven_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/coven_detail_response.dart';
import 'package:ritual_investing_api_client/generated/model/coven_entry_detail.dart';
import 'package:ritual_investing_api_client/generated/model/coven_evidence_response.dart';
import 'package:ritual_investing_api_client/generated/model/coven_qualification.dart';
import 'package:ritual_investing_api_client/generated/model/coven_summary.dart';
import 'package:ritual_investing_api_client/generated/model/create_circle_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_circle_request_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/create_consent_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_checkout201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_checkout_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_contribution_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_funding_source201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_funding_source_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_future_mirror200_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_future_mirror_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_future_mirror_request_annual_return_bps.dart';
import 'package:ritual_investing_api_client/generated/model/create_intention201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_intention_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_order_preview200_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_order_preview_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_portfolio201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_portfolio_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_portfolio_request_target_allocation_inner.dart';
import 'package:ritual_investing_api_client/generated/model/create_rebalance_preview200_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_rebalance_preview_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_recurring_plan201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_recurring_plan_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_recurring_plan_request_allocations_inner.dart';
import 'package:ritual_investing_api_client/generated/model/creator_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_detail.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_detail_revision.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_preview.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_response.dart';
import 'package:ritual_investing_api_client/generated/model/demo_checkout_session.dart';
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/demo_entitlement.dart';
import 'package:ritual_investing_api_client/generated/model/demo_funding_source.dart';
import 'package:ritual_investing_api_client/generated/model/demo_plan.dart';
import 'package:ritual_investing_api_client/generated/model/demo_reset_result.dart';
import 'package:ritual_investing_api_client/generated/model/demo_reset_result_default_portfolio.dart';
import 'package:ritual_investing_api_client/generated/model/demo_reset_result_entitlement.dart';
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
import 'package:ritual_investing_api_client/generated/model/future_mirror_view.dart';
import 'package:ritual_investing_api_client/generated/model/future_mirror_view_points_inner.dart';
import 'package:ritual_investing_api_client/generated/model/get_order200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_ritual_assignment200_response.dart';
import 'package:ritual_investing_api_client/generated/model/grimoire_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/grimoire_detail.dart';
import 'package:ritual_investing_api_client/generated/model/grimoire_detail_response.dart';
import 'package:ritual_investing_api_client/generated/model/grimoire_summary.dart';
import 'package:ritual_investing_api_client/generated/model/health_response.dart';
import 'package:ritual_investing_api_client/generated/model/health_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/input_money.dart';
import 'package:ritual_investing_api_client/generated/model/intention.dart';
import 'package:ritual_investing_api_client/generated/model/investor_profile.dart';
import 'package:ritual_investing_api_client/generated/model/investor_profile_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_demo_funding_sources200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_demo_plans200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_intentions200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_orders200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_portfolio_activity200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_portfolio_holdings200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_portfolio_holdings200_response_data_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_portfolio_snapshots200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_portfolios200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_recurring_plans200_response.dart';
import 'package:ritual_investing_api_client/generated/model/member_account_response.dart';
import 'package:ritual_investing_api_client/generated/model/member_account_view.dart';
import 'package:ritual_investing_api_client/generated/model/member_account_view_account.dart';
import 'package:ritual_investing_api_client/generated/model/member_preferences.dart';
import 'package:ritual_investing_api_client/generated/model/member_preferences_response.dart';
import 'package:ritual_investing_api_client/generated/model/member_profile.dart';
import 'package:ritual_investing_api_client/generated/model/member_profile_response.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:ritual_investing_api_client/generated/model/onboarding_response.dart';
import 'package:ritual_investing_api_client/generated/model/onboarding_state.dart';
import 'package:ritual_investing_api_client/generated/model/open_api_document.dart';
import 'package:ritual_investing_api_client/generated/model/order_preview.dart';
import 'package:ritual_investing_api_client/generated/model/patch_circle_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_intention_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_onboarding200_response.dart';
import 'package:ritual_investing_api_client/generated/model/patch_onboarding_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_portfolio_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_preferences200_response.dart';
import 'package:ritual_investing_api_client/generated/model/patch_preferences_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_profile_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_recurring_plan_request.dart';
import 'package:ritual_investing_api_client/generated/model/portfolio_activity.dart';
import 'package:ritual_investing_api_client/generated/model/portfolio_snapshot.dart';
import 'package:ritual_investing_api_client/generated/model/portfolio_view.dart';
import 'package:ritual_investing_api_client/generated/model/positive_input_money.dart';
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
import 'package:ritual_investing_api_client/generated/model/put_astrology_profile200_response.dart';
import 'package:ritual_investing_api_client/generated/model/put_astrology_profile_request.dart';
import 'package:ritual_investing_api_client/generated/model/put_circle_asset_request.dart';
import 'package:ritual_investing_api_client/generated/model/put_investor_profile200_response.dart';
import 'package:ritual_investing_api_client/generated/model/put_investor_profile_request.dart';
import 'package:ritual_investing_api_client/generated/model/quantity.dart';
import 'package:ritual_investing_api_client/generated/model/rebalance_preview.dart';
import 'package:ritual_investing_api_client/generated/model/rebalance_preview_trades_inner.dart';
import 'package:ritual_investing_api_client/generated/model/recurring_plan.dart';
import 'package:ritual_investing_api_client/generated/model/recurring_plan_recent_runs_inner.dart';
import 'package:ritual_investing_api_client/generated/model/reset_demo_state200_response.dart';
import 'package:ritual_investing_api_client/generated/model/reset_demo_state_request.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/ritual_asset_idea.dart';
import 'package:ritual_investing_api_client/generated/model/ritual_evidence_response.dart';
import 'package:ritual_investing_api_client/generated/model/ritual_history_item.dart';
import 'package:ritual_investing_api_client/generated/model/ritual_history_response.dart';
import 'package:ritual_investing_api_client/generated/model/rowan_counsel.dart';
import 'package:ritual_investing_api_client/generated/model/rowan_counsel_response.dart';
import 'package:ritual_investing_api_client/generated/model/save_asset200_response.dart';
import 'package:ritual_investing_api_client/generated/model/save_asset_request.dart';
import 'package:ritual_investing_api_client/generated/model/saved_item_receipt.dart';
import 'package:ritual_investing_api_client/generated/model/search_response.dart';
import 'package:ritual_investing_api_client/generated/model/search_result.dart';
import 'package:ritual_investing_api_client/generated/model/seeded_creator.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_default_portfolio.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_entitlement.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_onboarding.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_preferences.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_profile.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_response.dart';
import 'package:ritual_investing_api_client/generated/model/signed_money.dart';
import 'package:ritual_investing_api_client/generated/model/simulated_order.dart';
import 'package:ritual_investing_api_client/generated/model/simulated_order_fill.dart';
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/simulation_result.dart';
import 'package:ritual_investing_api_client/generated/model/simulation_result_response.dart';

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
    case 'AstrologyProfile':
      return AstrologyProfile.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AstrologyProfileResponse':
      return AstrologyProfileResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CircleCollectionResponse':
      return CircleCollectionResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CircleResponse':
      return CircleResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
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
    case 'CircleView':
      return CircleView.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CircleViewAssetsInner':
      return CircleViewAssetsInner.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CollectionMeta':
      return CollectionMeta.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CommitOrder200Response':
      return CommitOrder200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CommitOrderRequest':
      return CommitOrderRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CompareAssetsRequest':
      return CompareAssetsRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ConfirmDemoCheckout200Response':
      return ConfirmDemoCheckout200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ConsentReceipt':
      return ConsentReceipt.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ConsentReceiptResponse':
      return ConsentReceiptResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CopyCircleTemplate201Response':
      return CopyCircleTemplate201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CopyCircleTemplateRequest':
      return CopyCircleTemplateRequest.fromJson(value as Map<String, dynamic>)
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
    case 'CreateCircleRequest':
      return CreateCircleRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateCircleRequestAssetsInner':
      return CreateCircleRequestAssetsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateConsentRequest':
      return CreateConsentRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateDemoCheckout201Response':
      return CreateDemoCheckout201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateDemoCheckoutRequest':
      return CreateDemoCheckoutRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateDemoContributionRequest':
      return CreateDemoContributionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateDemoFundingSource201Response':
      return CreateDemoFundingSource201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateDemoFundingSourceRequest':
      return CreateDemoFundingSourceRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateFutureMirror200Response':
      return CreateFutureMirror200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateFutureMirrorRequest':
      return CreateFutureMirrorRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateFutureMirrorRequestAnnualReturnBps':
      return CreateFutureMirrorRequestAnnualReturnBps.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateIntention201Response':
      return CreateIntention201Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateIntentionRequest':
      return CreateIntentionRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateOrderPreview200Response':
      return CreateOrderPreview200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateOrderPreviewRequest':
      return CreateOrderPreviewRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreatePortfolio201Response':
      return CreatePortfolio201Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreatePortfolioRequest':
      return CreatePortfolioRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreatePortfolioRequestTargetAllocationInner':
      return CreatePortfolioRequestTargetAllocationInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateRebalancePreview200Response':
      return CreateRebalancePreview200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateRebalancePreviewRequest':
      return CreateRebalancePreviewRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateRecurringPlan201Response':
      return CreateRecurringPlan201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateRecurringPlanRequest':
      return CreateRecurringPlanRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateRecurringPlanRequestAllocationsInner':
      return CreateRecurringPlanRequestAllocationsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
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
    case 'DemoCheckoutSession':
      return DemoCheckoutSession.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DemoDisclosure':
      return DemoDisclosure.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DemoEntitlement':
      return DemoEntitlement.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DemoFundingSource':
      return DemoFundingSource.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DemoPlan':
      return DemoPlan.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'DemoResetResult':
      return DemoResetResult.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DemoResetResultDefaultPortfolio':
      return DemoResetResultDefaultPortfolio.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'DemoResetResultEntitlement':
      return DemoResetResultEntitlement.fromJson(value as Map<String, dynamic>)
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
    case 'FutureMirrorView':
      return FutureMirrorView.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'FutureMirrorViewPointsInner':
      return FutureMirrorViewPointsInner.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetOrder200Response':
      return GetOrder200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
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
    case 'InputMoney':
      return InputMoney.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Intention':
      return Intention.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'InvestorProfile':
      return InvestorProfile.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'InvestorProfileResponse':
      return InvestorProfileResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListDemoFundingSources200Response':
      return ListDemoFundingSources200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListDemoPlans200Response':
      return ListDemoPlans200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListIntentions200Response':
      return ListIntentions200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListOrders200Response':
      return ListOrders200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListPortfolioActivity200Response':
      return ListPortfolioActivity200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListPortfolioHoldings200Response':
      return ListPortfolioHoldings200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListPortfolioHoldings200ResponseDataInner':
      return ListPortfolioHoldings200ResponseDataInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListPortfolioSnapshots200Response':
      return ListPortfolioSnapshots200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListPortfolios200Response':
      return ListPortfolios200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListRecurringPlans200Response':
      return ListRecurringPlans200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'MemberAccountResponse':
      return MemberAccountResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberAccountView':
      return MemberAccountView.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberAccountViewAccount':
      return MemberAccountViewAccount.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberPreferences':
      return MemberPreferences.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberPreferencesResponse':
      return MemberPreferencesResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberProfile':
      return MemberProfile.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberProfileResponse':
      return MemberProfileResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Money':
      return Money.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'OnboardingResponse':
      return OnboardingResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OnboardingState':
      return OnboardingState.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OpenApiDocument':
      return OpenApiDocument.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OrderPreview':
      return OrderPreview.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'PatchCircleRequest':
      return PatchCircleRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchIntentionRequest':
      return PatchIntentionRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchOnboarding200Response':
      return PatchOnboarding200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchOnboardingRequest':
      return PatchOnboardingRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchPortfolioRequest':
      return PatchPortfolioRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchPreferences200Response':
      return PatchPreferences200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchPreferencesRequest':
      return PatchPreferencesRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchProfileRequest':
      return PatchProfileRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchRecurringPlanRequest':
      return PatchRecurringPlanRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PortfolioActivity':
      return PortfolioActivity.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PortfolioSnapshot':
      return PortfolioSnapshot.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PortfolioView':
      return PortfolioView.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PositiveInputMoney':
      return PositiveInputMoney.fromJson(value as Map<String, dynamic>)
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
    case 'PutAstrologyProfile200Response':
      return PutAstrologyProfile200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PutAstrologyProfileRequest':
      return PutAstrologyProfileRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PutCircleAssetRequest':
      return PutCircleAssetRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PutInvestorProfile200Response':
      return PutInvestorProfile200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PutInvestorProfileRequest':
      return PutInvestorProfileRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Quantity':
      return Quantity.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'RebalancePreview':
      return RebalancePreview.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RebalancePreviewTradesInner':
      return RebalancePreviewTradesInner.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RecurringPlan':
      return RecurringPlan.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RecurringPlanRecentRunsInner':
      return RecurringPlanRecentRunsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ResetDemoState200Response':
      return ResetDemoState200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ResetDemoStateRequest':
      return ResetDemoStateRequest.fromJson(value as Map<String, dynamic>)
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
    case 'SaveAsset200Response':
      return SaveAsset200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SaveAssetRequest':
      return SaveAssetRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SavedItemReceipt':
      return SavedItemReceipt.fromJson(value as Map<String, dynamic>)
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
    case 'SignedMoney':
      return SignedMoney.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'SimulatedOrder':
      return SimulatedOrder.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SimulatedOrderFill':
      return SimulatedOrderFill.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SimulationDemoDisclosure':
      return SimulationDemoDisclosure.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SimulationResult':
      return SimulationResult.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SimulationResultResponse':
      return SimulationResultResponse.fromJson(value as Map<String, dynamic>)
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
