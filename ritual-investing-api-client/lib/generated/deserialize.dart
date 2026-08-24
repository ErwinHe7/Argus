import 'package:ritual_investing_api_client/generated/model/admin_asset.dart';
import 'package:ritual_investing_api_client/generated/model/admin_asset_metric_snapshot.dart';
import 'package:ritual_investing_api_client/generated/model/admin_audit_event.dart';
import 'package:ritual_investing_api_client/generated/model/admin_coven_qualification.dart';
import 'package:ritual_investing_api_client/generated/model/admin_coven_verification.dart';
import 'package:ritual_investing_api_client/generated/model/admin_evidence_claim.dart';
import 'package:ritual_investing_api_client/generated/model/admin_evidence_source.dart';
import 'package:ritual_investing_api_client/generated/model/admin_health.dart';
import 'package:ritual_investing_api_client/generated/model/admin_health_dependencies.dart';
import 'package:ritual_investing_api_client/generated/model/admin_me.dart';
import 'package:ritual_investing_api_client/generated/model/admin_moderation_case.dart';
import 'package:ritual_investing_api_client/generated/model/admin_moderation_case_decisions_inner.dart';
import 'package:ritual_investing_api_client/generated/model/admin_moderation_report.dart';
import 'package:ritual_investing_api_client/generated/model/admin_ritual_schedule.dart';
import 'package:ritual_investing_api_client/generated/model/admin_seeded_creator.dart';
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
import 'package:ritual_investing_api_client/generated/model/complete_media_upload202_response.dart';
import 'package:ritual_investing_api_client/generated/model/complete_media_upload202_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/complete_media_upload_request.dart';
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
import 'package:ritual_investing_api_client/generated/model/create_admin_asset201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_asset_codex201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_asset_metric_snapshot201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_asset_metric_snapshot_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_asset_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_coven_qualification201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_coven_qualification_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_evidence_claim201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_evidence_claim_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_evidence_source201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_evidence_source_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_moderation_case_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_ritual_schedule201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_ritual_schedule_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_seeded_creator201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_seeded_creator_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_asset_codex_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_asset_codex_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_briefing_template_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_briefing_template_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_circle_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_circle_request_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/create_circle_template_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_circle_template_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_consent_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_content_report201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_content_report201_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/create_content_report_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_coven_entry_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_coven_entry_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_checkout201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_checkout_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_contribution_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_funding_source201_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_demo_funding_source_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_future_mirror200_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_future_mirror_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_future_mirror_request_annual_return_bps.dart';
import 'package:ritual_investing_api_client/generated/model/create_grimoire_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_grimoire_revision_request.dart';
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
import 'package:ritual_investing_api_client/generated/model/create_ritual_scenario_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_ritual_scenario_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_rowan_script_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_rowan_script_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/creator_collection_response.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_detail.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_detail_revision.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_preview.dart';
import 'package:ritual_investing_api_client/generated/model/daily_ritual_response.dart';
import 'package:ritual_investing_api_client/generated/model/decide_admin_asset_codex_review_request.dart';
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
import 'package:ritual_investing_api_client/generated/model/get_admin_asset_codex_revision200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_admin_health_ready200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_admin_job200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_admin_me200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_admin_media200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_admin_moderation_case200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_admin_privacy_request200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_briefing200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_briefing200_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/get_briefing200_response_data_sections_inner.dart';
import 'package:ritual_investing_api_client/generated/model/get_daily_briefing202_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_daily_briefing202_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/get_notification_preferences200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_notification_preferences200_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/get_notification_preferences200_response_data_quiet_hours.dart';
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
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of1.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of1_risks_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of2.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of3.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of3_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of4.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of4_assets_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of5.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of6.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of6_sections_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of_evidence_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of_ideas_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_assets200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_audit_events200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_evidence_claims200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_evidence_sources200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_jobs200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_jobs200_response_data_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_media200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_media200_response_data_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_moderation_reports200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_privacy_requests200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_privacy_requests200_response_data_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_ritual_schedules200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_seeded_creators200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_briefings200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_briefings200_response_data_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_demo_funding_sources200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_demo_plans200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_intentions200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_notifications200_response.dart';
import 'package:ritual_investing_api_client/generated/model/list_notifications200_response_data_inner.dart';
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
import 'package:ritual_investing_api_client/generated/model/patch_admin_asset_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_admin_evidence_source_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_admin_moderation_case_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_admin_ritual_schedule_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_admin_seeded_creator_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_asset_codex_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_briefing_template_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_circle_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_circle_template_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_coven_entry_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_grimoire_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_intention_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_notification_preferences_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_onboarding200_response.dart';
import 'package:ritual_investing_api_client/generated/model/patch_onboarding_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_portfolio_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_preferences200_response.dart';
import 'package:ritual_investing_api_client/generated/model/patch_preferences_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_profile_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_recurring_plan_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_ritual_scenario_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/patch_rowan_script_revision_request.dart';
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
import 'package:ritual_investing_api_client/generated/model/publish_admin_asset_codex_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/put_astrology_profile200_response.dart';
import 'package:ritual_investing_api_client/generated/model/put_astrology_profile_request.dart';
import 'package:ritual_investing_api_client/generated/model/put_circle_asset_request.dart';
import 'package:ritual_investing_api_client/generated/model/put_investor_profile200_response.dart';
import 'package:ritual_investing_api_client/generated/model/put_investor_profile_request.dart';
import 'package:ritual_investing_api_client/generated/model/quantity.dart';
import 'package:ritual_investing_api_client/generated/model/read_all_notifications200_response.dart';
import 'package:ritual_investing_api_client/generated/model/read_all_notifications200_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/read_all_notifications_request.dart';
import 'package:ritual_investing_api_client/generated/model/rebalance_preview.dart';
import 'package:ritual_investing_api_client/generated/model/rebalance_preview_trades_inner.dart';
import 'package:ritual_investing_api_client/generated/model/recurring_plan.dart';
import 'package:ritual_investing_api_client/generated/model/recurring_plan_recent_runs_inner.dart';
import 'package:ritual_investing_api_client/generated/model/register_notification_device201_response.dart';
import 'package:ritual_investing_api_client/generated/model/register_notification_device201_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/register_notification_device_request.dart';
import 'package:ritual_investing_api_client/generated/model/replace_circle_assets_request.dart';
import 'package:ritual_investing_api_client/generated/model/request_account_deletion202_response.dart';
import 'package:ritual_investing_api_client/generated/model/request_account_deletion202_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/request_account_deletion_request.dart';
import 'package:ritual_investing_api_client/generated/model/request_admin_asset_codex_review_request.dart';
import 'package:ritual_investing_api_client/generated/model/request_media_upload201_response.dart';
import 'package:ritual_investing_api_client/generated/model/request_media_upload201_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/request_media_upload_request.dart';
import 'package:ritual_investing_api_client/generated/model/request_privacy_export202_response.dart';
import 'package:ritual_investing_api_client/generated/model/request_privacy_export202_response_data.dart';
import 'package:ritual_investing_api_client/generated/model/request_privacy_export202_response_data_download_link.dart';
import 'package:ritual_investing_api_client/generated/model/request_privacy_export_request.dart';
import 'package:ritual_investing_api_client/generated/model/reset_demo_state200_response.dart';
import 'package:ritual_investing_api_client/generated/model/reset_demo_state_request.dart';
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/retry_admin_job_request.dart';
import 'package:ritual_investing_api_client/generated/model/retry_admin_privacy_request202_response.dart';
import 'package:ritual_investing_api_client/generated/model/retry_admin_privacy_request202_response_data.dart';
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
import 'package:ritual_investing_api_client/generated/model/set_briefing_read_state200_response.dart';
import 'package:ritual_investing_api_client/generated/model/set_briefing_read_state_request.dart';
import 'package:ritual_investing_api_client/generated/model/set_notification_read_state200_response.dart';
import 'package:ritual_investing_api_client/generated/model/signed_money.dart';
import 'package:ritual_investing_api_client/generated/model/simulated_order.dart';
import 'package:ritual_investing_api_client/generated/model/simulated_order_fill.dart';
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/simulation_result.dart';
import 'package:ritual_investing_api_client/generated/model/simulation_result_response.dart';
import 'package:ritual_investing_api_client/generated/model/verify_admin_coven_qualification201_response.dart';
import 'package:ritual_investing_api_client/generated/model/verify_admin_coven_qualification_request.dart';
import 'package:ritual_investing_api_client/generated/model/withdraw_admin_asset_codex_request.dart';

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
    case 'AdminAsset':
      return AdminAsset.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AdminAssetMetricSnapshot':
      return AdminAssetMetricSnapshot.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminAuditEvent':
      return AdminAuditEvent.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminCovenQualification':
      return AdminCovenQualification.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminCovenVerification':
      return AdminCovenVerification.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminEvidenceClaim':
      return AdminEvidenceClaim.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminEvidenceSource':
      return AdminEvidenceSource.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminHealth':
      return AdminHealth.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AdminHealthDependencies':
      return AdminHealthDependencies.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminMe':
      return AdminMe.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AdminModerationCase':
      return AdminModerationCase.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminModerationCaseDecisionsInner':
      return AdminModerationCaseDecisionsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'AdminModerationReport':
      return AdminModerationReport.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminRitualSchedule':
      return AdminRitualSchedule.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AdminSeededCreator':
      return AdminSeededCreator.fromJson(value as Map<String, dynamic>)
          as ReturnType;
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
    case 'CompleteMediaUpload202Response':
      return CompleteMediaUpload202Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CompleteMediaUpload202ResponseData':
      return CompleteMediaUpload202ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CompleteMediaUploadRequest':
      return CompleteMediaUploadRequest.fromJson(value as Map<String, dynamic>)
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
    case 'CreateAdminAsset201Response':
      return CreateAdminAsset201Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateAdminAssetCodex201Response':
      return CreateAdminAssetCodex201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminAssetMetricSnapshot201Response':
      return CreateAdminAssetMetricSnapshot201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminAssetMetricSnapshotRequest':
      return CreateAdminAssetMetricSnapshotRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminAssetRequest':
      return CreateAdminAssetRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateAdminCovenQualification201Response':
      return CreateAdminCovenQualification201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminCovenQualificationRequest':
      return CreateAdminCovenQualificationRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminEvidenceClaim201Response':
      return CreateAdminEvidenceClaim201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminEvidenceClaimRequest':
      return CreateAdminEvidenceClaimRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminEvidenceSource201Response':
      return CreateAdminEvidenceSource201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminEvidenceSourceRequest':
      return CreateAdminEvidenceSourceRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminModerationCaseRequest':
      return CreateAdminModerationCaseRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminRitualSchedule201Response':
      return CreateAdminRitualSchedule201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminRitualScheduleRequest':
      return CreateAdminRitualScheduleRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminSeededCreator201Response':
      return CreateAdminSeededCreator201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAdminSeededCreatorRequest':
      return CreateAdminSeededCreatorRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateAssetCodexRequest':
      return CreateAssetCodexRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateAssetCodexRevisionRequest':
      return CreateAssetCodexRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateBriefingTemplateRequest':
      return CreateBriefingTemplateRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateBriefingTemplateRevisionRequest':
      return CreateBriefingTemplateRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateCircleRequest':
      return CreateCircleRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateCircleRequestAssetsInner':
      return CreateCircleRequestAssetsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateCircleTemplateRequest':
      return CreateCircleTemplateRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateCircleTemplateRevisionRequest':
      return CreateCircleTemplateRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateConsentRequest':
      return CreateConsentRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateContentReport201Response':
      return CreateContentReport201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateContentReport201ResponseData':
      return CreateContentReport201ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateContentReportRequest':
      return CreateContentReportRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateCovenEntryRequest':
      return CreateCovenEntryRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateCovenEntryRevisionRequest':
      return CreateCovenEntryRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
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
    case 'CreateGrimoireRequest':
      return CreateGrimoireRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateGrimoireRevisionRequest':
      return CreateGrimoireRevisionRequest.fromJson(
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
    case 'CreateRitualScenarioRequest':
      return CreateRitualScenarioRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateRitualScenarioRevisionRequest':
      return CreateRitualScenarioRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateRowanScriptRequest':
      return CreateRowanScriptRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateRowanScriptRevisionRequest':
      return CreateRowanScriptRevisionRequest.fromJson(
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
    case 'DecideAdminAssetCodexReviewRequest':
      return DecideAdminAssetCodexReviewRequest.fromJson(
            value as Map<String, dynamic>,
          )
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
    case 'GetAdminAssetCodexRevision200Response':
      return GetAdminAssetCodexRevision200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'GetAdminHealthReady200Response':
      return GetAdminHealthReady200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'GetAdminJob200Response':
      return GetAdminJob200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetAdminMe200Response':
      return GetAdminMe200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetAdminMedia200Response':
      return GetAdminMedia200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetAdminModerationCase200Response':
      return GetAdminModerationCase200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'GetAdminPrivacyRequest200Response':
      return GetAdminPrivacyRequest200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'GetBriefing200Response':
      return GetBriefing200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetBriefing200ResponseData':
      return GetBriefing200ResponseData.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetBriefing200ResponseDataSectionsInner':
      return GetBriefing200ResponseDataSectionsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'GetDailyBriefing202Response':
      return GetDailyBriefing202Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetDailyBriefing202ResponseData':
      return GetDailyBriefing202ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'GetNotificationPreferences200Response':
      return GetNotificationPreferences200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'GetNotificationPreferences200ResponseData':
      return GetNotificationPreferences200ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'GetNotificationPreferences200ResponseDataQuietHours':
      return GetNotificationPreferences200ResponseDataQuietHours.fromJson(
            value as Map<String, dynamic>,
          )
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
    case 'ListAdminAssetCodex200Response':
      return ListAdminAssetCodex200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInner':
      return ListAdminAssetCodex200ResponseDataInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevision':
      return ListAdminAssetCodex200ResponseDataInnerRevision.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayload':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayload.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfEvidenceInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner':
      return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOfIdeasInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminAssets200Response':
      return ListAdminAssets200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListAdminAuditEvents200Response':
      return ListAdminAuditEvents200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminEvidenceClaims200Response':
      return ListAdminEvidenceClaims200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminEvidenceSources200Response':
      return ListAdminEvidenceSources200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminJobs200Response':
      return ListAdminJobs200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListAdminJobs200ResponseDataInner':
      return ListAdminJobs200ResponseDataInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminMedia200Response':
      return ListAdminMedia200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListAdminMedia200ResponseDataInner':
      return ListAdminMedia200ResponseDataInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminModerationReports200Response':
      return ListAdminModerationReports200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminPrivacyRequests200Response':
      return ListAdminPrivacyRequests200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminPrivacyRequests200ResponseDataInner':
      return ListAdminPrivacyRequests200ResponseDataInner.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminRitualSchedules200Response':
      return ListAdminRitualSchedules200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListAdminSeededCreators200Response':
      return ListAdminSeededCreators200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListBriefings200Response':
      return ListBriefings200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListBriefings200ResponseDataInner':
      return ListBriefings200ResponseDataInner.fromJson(
            value as Map<String, dynamic>,
          )
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
    case 'ListNotifications200Response':
      return ListNotifications200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ListNotifications200ResponseDataInner':
      return ListNotifications200ResponseDataInner.fromJson(
            value as Map<String, dynamic>,
          )
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
    case 'PatchAdminAssetRequest':
      return PatchAdminAssetRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchAdminEvidenceSourceRequest':
      return PatchAdminEvidenceSourceRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchAdminModerationCaseRequest':
      return PatchAdminModerationCaseRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchAdminRitualScheduleRequest':
      return PatchAdminRitualScheduleRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchAdminSeededCreatorRequest':
      return PatchAdminSeededCreatorRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchAssetCodexRevisionRequest':
      return PatchAssetCodexRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchBriefingTemplateRevisionRequest':
      return PatchBriefingTemplateRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchCircleRequest':
      return PatchCircleRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchCircleTemplateRevisionRequest':
      return PatchCircleTemplateRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchCovenEntryRevisionRequest':
      return PatchCovenEntryRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchGrimoireRevisionRequest':
      return PatchGrimoireRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchIntentionRequest':
      return PatchIntentionRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchNotificationPreferencesRequest':
      return PatchNotificationPreferencesRequest.fromJson(
            value as Map<String, dynamic>,
          )
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
    case 'PatchRitualScenarioRevisionRequest':
      return PatchRitualScenarioRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'PatchRowanScriptRevisionRequest':
      return PatchRowanScriptRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
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
    case 'PublishAdminAssetCodexRevisionRequest':
      return PublishAdminAssetCodexRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
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
    case 'ReadAllNotifications200Response':
      return ReadAllNotifications200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ReadAllNotifications200ResponseData':
      return ReadAllNotifications200ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ReadAllNotificationsRequest':
      return ReadAllNotificationsRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
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
    case 'RegisterNotificationDevice201Response':
      return RegisterNotificationDevice201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RegisterNotificationDevice201ResponseData':
      return RegisterNotificationDevice201ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RegisterNotificationDeviceRequest':
      return RegisterNotificationDeviceRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ReplaceCircleAssetsRequest':
      return ReplaceCircleAssetsRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RequestAccountDeletion202Response':
      return RequestAccountDeletion202Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestAccountDeletion202ResponseData':
      return RequestAccountDeletion202ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestAccountDeletionRequest':
      return RequestAccountDeletionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestAdminAssetCodexReviewRequest':
      return RequestAdminAssetCodexReviewRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestMediaUpload201Response':
      return RequestMediaUpload201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestMediaUpload201ResponseData':
      return RequestMediaUpload201ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestMediaUploadRequest':
      return RequestMediaUploadRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RequestPrivacyExport202Response':
      return RequestPrivacyExport202Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestPrivacyExport202ResponseData':
      return RequestPrivacyExport202ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestPrivacyExport202ResponseDataDownloadLink':
      return RequestPrivacyExport202ResponseDataDownloadLink.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestPrivacyExportRequest':
      return RequestPrivacyExportRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ResetDemoState200Response':
      return ResetDemoState200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ResetDemoStateRequest':
      return ResetDemoStateRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ResponseMeta':
      return ResponseMeta.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'RetryAdminJobRequest':
      return RetryAdminJobRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RetryAdminPrivacyRequest202Response':
      return RetryAdminPrivacyRequest202Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RetryAdminPrivacyRequest202ResponseData':
      return RetryAdminPrivacyRequest202ResponseData.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
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
    case 'SetBriefingReadState200Response':
      return SetBriefingReadState200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'SetBriefingReadStateRequest':
      return SetBriefingReadStateRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SetNotificationReadState200Response':
      return SetNotificationReadState200Response.fromJson(
            value as Map<String, dynamic>,
          )
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
    case 'VerifyAdminCovenQualification201Response':
      return VerifyAdminCovenQualification201Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'VerifyAdminCovenQualificationRequest':
      return VerifyAdminCovenQualificationRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'WithdrawAdminAssetCodexRequest':
      return WithdrawAdminAssetCodexRequest.fromJson(
            value as Map<String, dynamic>,
          )
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
