// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_admin_step_up_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$IssueAdminStepUpRequestCWProxy {
  IssueAdminStepUpRequest action(IssueAdminStepUpRequestActionEnum action);

  IssueAdminStepUpRequest targetId(String targetId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `IssueAdminStepUpRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// IssueAdminStepUpRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  IssueAdminStepUpRequest call({
    IssueAdminStepUpRequestActionEnum action,
    String targetId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfIssueAdminStepUpRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfIssueAdminStepUpRequest.copyWith.fieldName(...)`
class _$IssueAdminStepUpRequestCWProxyImpl
    implements _$IssueAdminStepUpRequestCWProxy {
  const _$IssueAdminStepUpRequestCWProxyImpl(this._value);

  final IssueAdminStepUpRequest _value;

  @override
  IssueAdminStepUpRequest action(IssueAdminStepUpRequestActionEnum action) =>
      this(action: action);

  @override
  IssueAdminStepUpRequest targetId(String targetId) => this(targetId: targetId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `IssueAdminStepUpRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// IssueAdminStepUpRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  IssueAdminStepUpRequest call({
    Object? action = const $CopyWithPlaceholder(),
    Object? targetId = const $CopyWithPlaceholder(),
  }) {
    return IssueAdminStepUpRequest(
      action: action == const $CopyWithPlaceholder()
          ? _value.action
          // ignore: cast_nullable_to_non_nullable
          : action as IssueAdminStepUpRequestActionEnum,
      targetId: targetId == const $CopyWithPlaceholder()
          ? _value.targetId
          // ignore: cast_nullable_to_non_nullable
          : targetId as String,
    );
  }
}

extension $IssueAdminStepUpRequestCopyWith on IssueAdminStepUpRequest {
  /// Returns a callable class that can be used as follows: `instanceOfIssueAdminStepUpRequest.copyWith(...)` or like so:`instanceOfIssueAdminStepUpRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$IssueAdminStepUpRequestCWProxy get copyWith =>
      _$IssueAdminStepUpRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueAdminStepUpRequest _$IssueAdminStepUpRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('IssueAdminStepUpRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['action', 'target_id']);
  final val = IssueAdminStepUpRequest(
    action: $checkedConvert(
      'action',
      (v) => $enumDecode(
        _$IssueAdminStepUpRequestActionEnumEnumMap,
        v,
        unknownValue: IssueAdminStepUpRequestActionEnum.unknownDefaultOpenApi,
      ),
    ),
    targetId: $checkedConvert('target_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'targetId': 'target_id'});

Map<String, dynamic> _$IssueAdminStepUpRequestToJson(
  IssueAdminStepUpRequest instance,
) => <String, dynamic>{
  'action': _$IssueAdminStepUpRequestActionEnumEnumMap[instance.action]!,
  'target_id': instance.targetId,
};

const _$IssueAdminStepUpRequestActionEnumEnumMap = {
  IssueAdminStepUpRequestActionEnum.adminJobRetry: 'admin_job_retry',
  IssueAdminStepUpRequestActionEnum.adminPrivacyRetry: 'admin_privacy_retry',
  IssueAdminStepUpRequestActionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
