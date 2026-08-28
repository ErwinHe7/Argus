import 'package:ritual_investing_api_client/generated/model/brokerage_account.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_account_authority.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_accounts_response.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_asset.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_balance.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_balances_projection.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_balances_response.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_capabilities_projection.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_capabilities_response.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_capability.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_order.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_order_command.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_order_command_response.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_order_detail.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_order_detail_response.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_order_list.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_order_preview.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_order_preview_response.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_orders_response.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_position.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_positions_projection.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_positions_response.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_restriction.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_restrictions_projection.dart';
import 'package:ritual_investing_api_client/generated/model/brokerage_restrictions_response.dart';
import 'package:ritual_investing_api_client/generated/model/command_admin_editorial_request.dart';
import 'package:ritual_investing_api_client/generated/model/confirm_cancel_brokerage_order.dart';
import 'package:ritual_investing_api_client/generated/model/confirm_modify_brokerage_order.dart';
import 'package:ritual_investing_api_client/generated/model/confirm_place_brokerage_order.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_editorial_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_admin_editorial_revision_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_circle_request.dart';
import 'package:ritual_investing_api_client/generated/model/create_hypothetical_future_mirror.dart';
import 'package:ritual_investing_api_client/generated/model/create_hypothetical_future_mirror_annual_return_bps.dart';
import 'package:ritual_investing_api_client/generated/model/create_member_intention.dart';
import 'package:ritual_investing_api_client/generated/model/create_privacy_download_url200_response.dart';
import 'package:ritual_investing_api_client/generated/model/create_upload_intent_request.dart';
import 'package:ritual_investing_api_client/generated/model/decide_moderation_request.dart';
import 'package:ritual_investing_api_client/generated/model/disconnect_webull_connection_request.dart';
import 'package:ritual_investing_api_client/generated/model/finalize_upload_request.dart';
import 'package:ritual_investing_api_client/generated/model/get_account200_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_account200_response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/get_account401_response.dart';
import 'package:ritual_investing_api_client/generated/model/get_account401_response_error.dart';
import 'package:ritual_investing_api_client/generated/model/hypothetical_future_mirror.dart';
import 'package:ritual_investing_api_client/generated/model/hypothetical_future_mirror_annual_return_bps.dart';
import 'package:ritual_investing_api_client/generated/model/hypothetical_future_mirror_point.dart';
import 'package:ritual_investing_api_client/generated/model/hypothetical_future_mirror_response.dart';
import 'package:ritual_investing_api_client/generated/model/issue_admin_step_up_request.dart';
import 'package:ritual_investing_api_client/generated/model/issue_member_step_up_request.dart';
import 'package:ritual_investing_api_client/generated/model/member_intention.dart';
import 'package:ritual_investing_api_client/generated/model/member_intention_page.dart';
import 'package:ritual_investing_api_client/generated/model/member_intention_page_response.dart';
import 'package:ritual_investing_api_client/generated/model/member_intention_response.dart';
import 'package:ritual_investing_api_client/generated/model/modify_brokerage_order_intent.dart';
import 'package:ritual_investing_api_client/generated/model/patch_member_intention.dart';
import 'package:ritual_investing_api_client/generated/model/place_brokerage_order_intent.dart';
import 'package:ritual_investing_api_client/generated/model/reconnect_webull_connection_request.dart';
import 'package:ritual_investing_api_client/generated/model/record_consent_request.dart';
import 'package:ritual_investing_api_client/generated/model/redeem_webull_completion_request.dart';
import 'package:ritual_investing_api_client/generated/model/report_content_request.dart';
import 'package:ritual_investing_api_client/generated/model/request_privacy_action_request.dart';
import 'package:ritual_investing_api_client/generated/model/request_privacy_action_request_one_of.dart';
import 'package:ritual_investing_api_client/generated/model/request_privacy_action_request_one_of1.dart';
import 'package:ritual_investing_api_client/generated/model/retry_admin_job_request.dart';
import 'package:ritual_investing_api_client/generated/model/scenario_money.dart';
import 'package:ritual_investing_api_client/generated/model/select_webull_account_request.dart';
import 'package:ritual_investing_api_client/generated/model/transition_ritual_request.dart';
import 'package:ritual_investing_api_client/generated/model/update_circle_request.dart';
import 'package:ritual_investing_api_client/generated/model/update_preferences_request.dart';

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
    case 'BrokerageAccount':
      return BrokerageAccount.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageAccountAuthority':
      return BrokerageAccountAuthority.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageAccountsResponse':
      return BrokerageAccountsResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageAsset':
      return BrokerageAsset.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageBalance':
      return BrokerageBalance.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageBalancesProjection':
      return BrokerageBalancesProjection.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageBalancesResponse':
      return BrokerageBalancesResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageCapabilitiesProjection':
      return BrokerageCapabilitiesProjection.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'BrokerageCapabilitiesResponse':
      return BrokerageCapabilitiesResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'BrokerageCapability':
      return BrokerageCapability.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageOrder':
      return BrokerageOrder.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageOrderCommand':
      return BrokerageOrderCommand.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageOrderCommandResponse':
      return BrokerageOrderCommandResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'BrokerageOrderDetail':
      return BrokerageOrderDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageOrderDetailResponse':
      return BrokerageOrderDetailResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'BrokerageOrderList':
      return BrokerageOrderList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageOrderPreview':
      return BrokerageOrderPreview.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageOrderPreviewResponse':
      return BrokerageOrderPreviewResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'BrokerageOrdersResponse':
      return BrokerageOrdersResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokeragePosition':
      return BrokeragePosition.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokeragePositionsProjection':
      return BrokeragePositionsProjection.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'BrokeragePositionsResponse':
      return BrokeragePositionsResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageRestriction':
      return BrokerageRestriction.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'BrokerageRestrictionsProjection':
      return BrokerageRestrictionsProjection.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'BrokerageRestrictionsResponse':
      return BrokerageRestrictionsResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CommandAdminEditorialRequest':
      return CommandAdminEditorialRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ConfirmCancelBrokerageOrder':
      return ConfirmCancelBrokerageOrder.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ConfirmModifyBrokerageOrder':
      return ConfirmModifyBrokerageOrder.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ConfirmPlaceBrokerageOrder':
      return ConfirmPlaceBrokerageOrder.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateAdminEditorialRequest':
      return CreateAdminEditorialRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateAdminEditorialRevisionRequest':
      return CreateAdminEditorialRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateCircleRequest':
      return CreateCircleRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateHypotheticalFutureMirror':
      return CreateHypotheticalFutureMirror.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateHypotheticalFutureMirrorAnnualReturnBps':
      return CreateHypotheticalFutureMirrorAnnualReturnBps.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateMemberIntention':
      return CreateMemberIntention.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreatePrivacyDownloadUrl200Response':
      return CreatePrivacyDownloadUrl200Response.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateUploadIntentRequest':
      return CreateUploadIntentRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DecideModerationRequest':
      return DecideModerationRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'DisconnectWebullConnectionRequest':
      return DisconnectWebullConnectionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'FinalizeUploadRequest':
      return FinalizeUploadRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetAccount200Response':
      return GetAccount200Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetAccount200ResponseMeta':
      return GetAccount200ResponseMeta.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetAccount401Response':
      return GetAccount401Response.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'GetAccount401ResponseError':
      return GetAccount401ResponseError.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'HypotheticalFutureMirror':
      return HypotheticalFutureMirror.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'HypotheticalFutureMirrorAnnualReturnBps':
      return HypotheticalFutureMirrorAnnualReturnBps.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'HypotheticalFutureMirrorPoint':
      return HypotheticalFutureMirrorPoint.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'HypotheticalFutureMirrorResponse':
      return HypotheticalFutureMirrorResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'IssueAdminStepUpRequest':
      return IssueAdminStepUpRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'IssueMemberStepUpRequest':
      return IssueMemberStepUpRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberIntention':
      return MemberIntention.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberIntentionPage':
      return MemberIntentionPage.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberIntentionPageResponse':
      return MemberIntentionPageResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MemberIntentionResponse':
      return MemberIntentionResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ModifyBrokerageOrderIntent':
      return ModifyBrokerageOrderIntent.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchMemberIntention':
      return PatchMemberIntention.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PlaceBrokerageOrderIntent':
      return PlaceBrokerageOrderIntent.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ReconnectWebullConnectionRequest':
      return ReconnectWebullConnectionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RecordConsentRequest':
      return RecordConsentRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RedeemWebullCompletionRequest':
      return RedeemWebullCompletionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'ReportContentRequest':
      return ReportContentRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RequestPrivacyActionRequest':
      return RequestPrivacyActionRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RequestPrivacyActionRequestOneOf':
      return RequestPrivacyActionRequestOneOf.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RequestPrivacyActionRequestOneOf1':
      return RequestPrivacyActionRequestOneOf1.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'RetryAdminJobRequest':
      return RetryAdminJobRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ScenarioMoney':
      return ScenarioMoney.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SelectWebullAccountRequest':
      return SelectWebullAccountRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TransitionRitualRequest':
      return TransitionRitualRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'UpdateCircleRequest':
      return UpdateCircleRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'UpdatePreferencesRequest':
      return UpdatePreferencesRequest.fromJson(value as Map<String, dynamic>)
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
