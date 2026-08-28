// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_admin_editorial_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CommandAdminEditorialRequestCWProxy {
  CommandAdminEditorialRequest action(
    CommandAdminEditorialRequestActionEnum action,
  );

  CommandAdminEditorialRequest highTrust(bool? highTrust);

  CommandAdminEditorialRequest reason(String reason);

  CommandAdminEditorialRequest revisionId(String? revisionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CommandAdminEditorialRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CommandAdminEditorialRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CommandAdminEditorialRequest call({
    CommandAdminEditorialRequestActionEnum action,
    bool? highTrust,
    String reason,
    String? revisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCommandAdminEditorialRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCommandAdminEditorialRequest.copyWith.fieldName(...)`
class _$CommandAdminEditorialRequestCWProxyImpl
    implements _$CommandAdminEditorialRequestCWProxy {
  const _$CommandAdminEditorialRequestCWProxyImpl(this._value);

  final CommandAdminEditorialRequest _value;

  @override
  CommandAdminEditorialRequest action(
    CommandAdminEditorialRequestActionEnum action,
  ) => this(action: action);

  @override
  CommandAdminEditorialRequest highTrust(bool? highTrust) =>
      this(highTrust: highTrust);

  @override
  CommandAdminEditorialRequest reason(String reason) => this(reason: reason);

  @override
  CommandAdminEditorialRequest revisionId(String? revisionId) =>
      this(revisionId: revisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CommandAdminEditorialRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CommandAdminEditorialRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CommandAdminEditorialRequest call({
    Object? action = const $CopyWithPlaceholder(),
    Object? highTrust = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
  }) {
    return CommandAdminEditorialRequest(
      action: action == const $CopyWithPlaceholder()
          ? _value.action
          // ignore: cast_nullable_to_non_nullable
          : action as CommandAdminEditorialRequestActionEnum,
      highTrust: highTrust == const $CopyWithPlaceholder()
          ? _value.highTrust
          // ignore: cast_nullable_to_non_nullable
          : highTrust as bool?,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
      revisionId: revisionId == const $CopyWithPlaceholder()
          ? _value.revisionId
          // ignore: cast_nullable_to_non_nullable
          : revisionId as String?,
    );
  }
}

extension $CommandAdminEditorialRequestCopyWith
    on CommandAdminEditorialRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCommandAdminEditorialRequest.copyWith(...)` or like so:`instanceOfCommandAdminEditorialRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CommandAdminEditorialRequestCWProxy get copyWith =>
      _$CommandAdminEditorialRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommandAdminEditorialRequest _$CommandAdminEditorialRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CommandAdminEditorialRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['action', 'reason', 'revision_id']);
  final val = CommandAdminEditorialRequest(
    action: $checkedConvert(
      'action',
      (v) => $enumDecode(
        _$CommandAdminEditorialRequestActionEnumEnumMap,
        v,
        unknownValue:
            CommandAdminEditorialRequestActionEnum.unknownDefaultOpenApi,
      ),
    ),
    highTrust: $checkedConvert('high_trust', (v) => v as bool? ?? false),
    reason: $checkedConvert('reason', (v) => v as String),
    revisionId: $checkedConvert('revision_id', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'highTrust': 'high_trust', 'revisionId': 'revision_id'});

Map<String, dynamic> _$CommandAdminEditorialRequestToJson(
  CommandAdminEditorialRequest instance,
) => <String, dynamic>{
  'action': _$CommandAdminEditorialRequestActionEnumEnumMap[instance.action]!,
  'high_trust': ?instance.highTrust,
  'reason': instance.reason,
  'revision_id': instance.revisionId,
};

const _$CommandAdminEditorialRequestActionEnumEnumMap = {
  CommandAdminEditorialRequestActionEnum.requestReview: 'request_review',
  CommandAdminEditorialRequestActionEnum.approve: 'approve',
  CommandAdminEditorialRequestActionEnum.changesRequested: 'changes_requested',
  CommandAdminEditorialRequestActionEnum.publish: 'publish',
  CommandAdminEditorialRequestActionEnum.withdraw: 'withdraw',
  CommandAdminEditorialRequestActionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
