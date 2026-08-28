// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_member_step_up_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$IssueMemberStepUpRequestCWProxy {
  IssueMemberStepUpRequest action(IssueMemberStepUpRequestActionEnum action);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `IssueMemberStepUpRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// IssueMemberStepUpRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  IssueMemberStepUpRequest call({IssueMemberStepUpRequestActionEnum action});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfIssueMemberStepUpRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfIssueMemberStepUpRequest.copyWith.fieldName(...)`
class _$IssueMemberStepUpRequestCWProxyImpl
    implements _$IssueMemberStepUpRequestCWProxy {
  const _$IssueMemberStepUpRequestCWProxyImpl(this._value);

  final IssueMemberStepUpRequest _value;

  @override
  IssueMemberStepUpRequest action(IssueMemberStepUpRequestActionEnum action) =>
      this(action: action);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `IssueMemberStepUpRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// IssueMemberStepUpRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  IssueMemberStepUpRequest call({
    Object? action = const $CopyWithPlaceholder(),
  }) {
    return IssueMemberStepUpRequest(
      action: action == const $CopyWithPlaceholder()
          ? _value.action
          // ignore: cast_nullable_to_non_nullable
          : action as IssueMemberStepUpRequestActionEnum,
    );
  }
}

extension $IssueMemberStepUpRequestCopyWith on IssueMemberStepUpRequest {
  /// Returns a callable class that can be used as follows: `instanceOfIssueMemberStepUpRequest.copyWith(...)` or like so:`instanceOfIssueMemberStepUpRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$IssueMemberStepUpRequestCWProxy get copyWith =>
      _$IssueMemberStepUpRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueMemberStepUpRequest _$IssueMemberStepUpRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('IssueMemberStepUpRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['action']);
  final val = IssueMemberStepUpRequest(
    action: $checkedConvert(
      'action',
      (v) => $enumDecode(
        _$IssueMemberStepUpRequestActionEnumEnumMap,
        v,
        unknownValue: IssueMemberStepUpRequestActionEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$IssueMemberStepUpRequestToJson(
  IssueMemberStepUpRequest instance,
) => <String, dynamic>{
  'action': _$IssueMemberStepUpRequestActionEnumEnumMap[instance.action]!,
};

const _$IssueMemberStepUpRequestActionEnumEnumMap = {
  IssueMemberStepUpRequestActionEnum.webullDisconnect: 'webull_disconnect',
  IssueMemberStepUpRequestActionEnum.argusDelete: 'argus_delete',
  IssueMemberStepUpRequestActionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
