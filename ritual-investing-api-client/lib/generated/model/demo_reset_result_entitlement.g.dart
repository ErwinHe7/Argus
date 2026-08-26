// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_reset_result_entitlement.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DemoResetResultEntitlementCWProxy {
  DemoResetResultEntitlement id(String id);

  DemoResetResultEntitlement planCode(
    DemoResetResultEntitlementPlanCodeEnum planCode,
  );

  DemoResetResultEntitlement source_(
    DemoResetResultEntitlementSource_Enum source_,
  );

  DemoResetResultEntitlement status(
    DemoResetResultEntitlementStatusEnum status,
  );

  DemoResetResultEntitlement version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoResetResultEntitlement(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoResetResultEntitlement(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoResetResultEntitlement call({
    String id,
    DemoResetResultEntitlementPlanCodeEnum planCode,
    DemoResetResultEntitlementSource_Enum source_,
    DemoResetResultEntitlementStatusEnum status,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDemoResetResultEntitlement.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDemoResetResultEntitlement.copyWith.fieldName(...)`
class _$DemoResetResultEntitlementCWProxyImpl
    implements _$DemoResetResultEntitlementCWProxy {
  const _$DemoResetResultEntitlementCWProxyImpl(this._value);

  final DemoResetResultEntitlement _value;

  @override
  DemoResetResultEntitlement id(String id) => this(id: id);

  @override
  DemoResetResultEntitlement planCode(
    DemoResetResultEntitlementPlanCodeEnum planCode,
  ) => this(planCode: planCode);

  @override
  DemoResetResultEntitlement source_(
    DemoResetResultEntitlementSource_Enum source_,
  ) => this(source_: source_);

  @override
  DemoResetResultEntitlement status(
    DemoResetResultEntitlementStatusEnum status,
  ) => this(status: status);

  @override
  DemoResetResultEntitlement version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoResetResultEntitlement(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoResetResultEntitlement(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoResetResultEntitlement call({
    Object? id = const $CopyWithPlaceholder(),
    Object? planCode = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return DemoResetResultEntitlement(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      planCode: planCode == const $CopyWithPlaceholder()
          ? _value.planCode
          // ignore: cast_nullable_to_non_nullable
          : planCode as DemoResetResultEntitlementPlanCodeEnum,
      source_: source_ == const $CopyWithPlaceholder()
          ? _value.source_
          // ignore: cast_nullable_to_non_nullable
          : source_ as DemoResetResultEntitlementSource_Enum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as DemoResetResultEntitlementStatusEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $DemoResetResultEntitlementCopyWith on DemoResetResultEntitlement {
  /// Returns a callable class that can be used as follows: `instanceOfDemoResetResultEntitlement.copyWith(...)` or like so:`instanceOfDemoResetResultEntitlement.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DemoResetResultEntitlementCWProxy get copyWith =>
      _$DemoResetResultEntitlementCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DemoResetResultEntitlement _$DemoResetResultEntitlementFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DemoResetResultEntitlement', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['id', 'plan_code', 'source', 'status', 'version'],
  );
  final val = DemoResetResultEntitlement(
    id: $checkedConvert('id', (v) => v as String),
    planCode: $checkedConvert(
      'plan_code',
      (v) => $enumDecode(
        _$DemoResetResultEntitlementPlanCodeEnumEnumMap,
        v,
        unknownValue:
            DemoResetResultEntitlementPlanCodeEnum.unknownDefaultOpenApi,
      ),
    ),
    source_: $checkedConvert(
      'source',
      (v) => $enumDecode(
        _$DemoResetResultEntitlementSource_EnumEnumMap,
        v,
        unknownValue:
            DemoResetResultEntitlementSource_Enum.unknownDefaultOpenApi,
      ),
    ),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$DemoResetResultEntitlementStatusEnumEnumMap,
        v,
        unknownValue:
            DemoResetResultEntitlementStatusEnum.unknownDefaultOpenApi,
      ),
    ),
    version: $checkedConvert('version', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'planCode': 'plan_code', 'source_': 'source'});

Map<String, dynamic> _$DemoResetResultEntitlementToJson(
  DemoResetResultEntitlement instance,
) => <String, dynamic>{
  'id': instance.id,
  'plan_code':
      _$DemoResetResultEntitlementPlanCodeEnumEnumMap[instance.planCode]!,
  'source': _$DemoResetResultEntitlementSource_EnumEnumMap[instance.source_]!,
  'status': _$DemoResetResultEntitlementStatusEnumEnumMap[instance.status]!,
  'version': instance.version,
};

const _$DemoResetResultEntitlementPlanCodeEnumEnumMap = {
  DemoResetResultEntitlementPlanCodeEnum.free: 'free',
  DemoResetResultEntitlementPlanCodeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$DemoResetResultEntitlementSource_EnumEnumMap = {
  DemoResetResultEntitlementSource_Enum.demo: 'demo',
  DemoResetResultEntitlementSource_Enum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$DemoResetResultEntitlementStatusEnumEnumMap = {
  DemoResetResultEntitlementStatusEnum.active: 'active',
  DemoResetResultEntitlementStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
