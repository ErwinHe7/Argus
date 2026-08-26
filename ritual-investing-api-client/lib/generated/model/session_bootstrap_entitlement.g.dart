// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_entitlement.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapEntitlementCWProxy {
  SessionBootstrapEntitlement planCode(String planCode);

  SessionBootstrapEntitlement status(
    SessionBootstrapEntitlementStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapEntitlement(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapEntitlement(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapEntitlement call({
    String planCode,
    SessionBootstrapEntitlementStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapEntitlement.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapEntitlement.copyWith.fieldName(...)`
class _$SessionBootstrapEntitlementCWProxyImpl
    implements _$SessionBootstrapEntitlementCWProxy {
  const _$SessionBootstrapEntitlementCWProxyImpl(this._value);

  final SessionBootstrapEntitlement _value;

  @override
  SessionBootstrapEntitlement planCode(String planCode) =>
      this(planCode: planCode);

  @override
  SessionBootstrapEntitlement status(
    SessionBootstrapEntitlementStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapEntitlement(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapEntitlement(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapEntitlement call({
    Object? planCode = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapEntitlement(
      planCode: planCode == const $CopyWithPlaceholder()
          ? _value.planCode
          // ignore: cast_nullable_to_non_nullable
          : planCode as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as SessionBootstrapEntitlementStatusEnum,
    );
  }
}

extension $SessionBootstrapEntitlementCopyWith on SessionBootstrapEntitlement {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrapEntitlement.copyWith(...)` or like so:`instanceOfSessionBootstrapEntitlement.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapEntitlementCWProxy get copyWith =>
      _$SessionBootstrapEntitlementCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrapEntitlement _$SessionBootstrapEntitlementFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SessionBootstrapEntitlement', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['plan_code', 'status']);
  final val = SessionBootstrapEntitlement(
    planCode: $checkedConvert('plan_code', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$SessionBootstrapEntitlementStatusEnumEnumMap,
        v,
        unknownValue:
            SessionBootstrapEntitlementStatusEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'planCode': 'plan_code'});

Map<String, dynamic> _$SessionBootstrapEntitlementToJson(
  SessionBootstrapEntitlement instance,
) => <String, dynamic>{
  'plan_code': instance.planCode,
  'status': _$SessionBootstrapEntitlementStatusEnumEnumMap[instance.status]!,
};

const _$SessionBootstrapEntitlementStatusEnumEnumMap = {
  SessionBootstrapEntitlementStatusEnum.active: 'active',
  SessionBootstrapEntitlementStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
