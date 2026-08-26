// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_admin_moderation_case_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchAdminModerationCaseRequestCWProxy {
  PatchAdminModerationCaseRequest reason(String reason);

  PatchAdminModerationCaseRequest resolutionCode(String? resolutionCode);

  PatchAdminModerationCaseRequest status(
    PatchAdminModerationCaseRequestStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminModerationCaseRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminModerationCaseRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminModerationCaseRequest call({
    String reason,
    String? resolutionCode,
    PatchAdminModerationCaseRequestStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchAdminModerationCaseRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchAdminModerationCaseRequest.copyWith.fieldName(...)`
class _$PatchAdminModerationCaseRequestCWProxyImpl
    implements _$PatchAdminModerationCaseRequestCWProxy {
  const _$PatchAdminModerationCaseRequestCWProxyImpl(this._value);

  final PatchAdminModerationCaseRequest _value;

  @override
  PatchAdminModerationCaseRequest reason(String reason) => this(reason: reason);

  @override
  PatchAdminModerationCaseRequest resolutionCode(String? resolutionCode) =>
      this(resolutionCode: resolutionCode);

  @override
  PatchAdminModerationCaseRequest status(
    PatchAdminModerationCaseRequestStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminModerationCaseRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminModerationCaseRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminModerationCaseRequest call({
    Object? reason = const $CopyWithPlaceholder(),
    Object? resolutionCode = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return PatchAdminModerationCaseRequest(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
      resolutionCode: resolutionCode == const $CopyWithPlaceholder()
          ? _value.resolutionCode
          // ignore: cast_nullable_to_non_nullable
          : resolutionCode as String?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as PatchAdminModerationCaseRequestStatusEnum,
    );
  }
}

extension $PatchAdminModerationCaseRequestCopyWith
    on PatchAdminModerationCaseRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchAdminModerationCaseRequest.copyWith(...)` or like so:`instanceOfPatchAdminModerationCaseRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchAdminModerationCaseRequestCWProxy get copyWith =>
      _$PatchAdminModerationCaseRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchAdminModerationCaseRequest _$PatchAdminModerationCaseRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchAdminModerationCaseRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['reason', 'status']);
  final val = PatchAdminModerationCaseRequest(
    reason: $checkedConvert('reason', (v) => v as String),
    resolutionCode: $checkedConvert('resolution_code', (v) => v as String?),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$PatchAdminModerationCaseRequestStatusEnumEnumMap,
        v,
        unknownValue:
            PatchAdminModerationCaseRequestStatusEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'resolutionCode': 'resolution_code'});

Map<String, dynamic> _$PatchAdminModerationCaseRequestToJson(
  PatchAdminModerationCaseRequest instance,
) => <String, dynamic>{
  'reason': instance.reason,
  'resolution_code': ?instance.resolutionCode,
  'status':
      _$PatchAdminModerationCaseRequestStatusEnumEnumMap[instance.status]!,
};

const _$PatchAdminModerationCaseRequestStatusEnumEnumMap = {
  PatchAdminModerationCaseRequestStatusEnum.investigating: 'investigating',
  PatchAdminModerationCaseRequestStatusEnum.resolved: 'resolved',
  PatchAdminModerationCaseRequestStatusEnum.dismissed: 'dismissed',
  PatchAdminModerationCaseRequestStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
