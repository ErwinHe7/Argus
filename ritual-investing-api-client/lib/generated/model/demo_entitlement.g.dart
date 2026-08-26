// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_entitlement.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DemoEntitlementCWProxy {
  DemoEntitlement demo(SimulationDemoDisclosure demo);

  DemoEntitlement endsAt(DateTime? endsAt);

  DemoEntitlement id(String id);

  DemoEntitlement planCode(DemoEntitlementPlanCodeEnum planCode);

  DemoEntitlement source_(DemoEntitlementSource_Enum source_);

  DemoEntitlement startsAt(DateTime startsAt);

  DemoEntitlement status(DemoEntitlementStatusEnum status);

  DemoEntitlement version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoEntitlement(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoEntitlement(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoEntitlement call({
    SimulationDemoDisclosure demo,
    DateTime? endsAt,
    String id,
    DemoEntitlementPlanCodeEnum planCode,
    DemoEntitlementSource_Enum source_,
    DateTime startsAt,
    DemoEntitlementStatusEnum status,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDemoEntitlement.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDemoEntitlement.copyWith.fieldName(...)`
class _$DemoEntitlementCWProxyImpl implements _$DemoEntitlementCWProxy {
  const _$DemoEntitlementCWProxyImpl(this._value);

  final DemoEntitlement _value;

  @override
  DemoEntitlement demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  DemoEntitlement endsAt(DateTime? endsAt) => this(endsAt: endsAt);

  @override
  DemoEntitlement id(String id) => this(id: id);

  @override
  DemoEntitlement planCode(DemoEntitlementPlanCodeEnum planCode) =>
      this(planCode: planCode);

  @override
  DemoEntitlement source_(DemoEntitlementSource_Enum source_) =>
      this(source_: source_);

  @override
  DemoEntitlement startsAt(DateTime startsAt) => this(startsAt: startsAt);

  @override
  DemoEntitlement status(DemoEntitlementStatusEnum status) =>
      this(status: status);

  @override
  DemoEntitlement version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoEntitlement(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoEntitlement(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoEntitlement call({
    Object? demo = const $CopyWithPlaceholder(),
    Object? endsAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? planCode = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
    Object? startsAt = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return DemoEntitlement(
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      endsAt: endsAt == const $CopyWithPlaceholder()
          ? _value.endsAt
          // ignore: cast_nullable_to_non_nullable
          : endsAt as DateTime?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      planCode: planCode == const $CopyWithPlaceholder()
          ? _value.planCode
          // ignore: cast_nullable_to_non_nullable
          : planCode as DemoEntitlementPlanCodeEnum,
      source_: source_ == const $CopyWithPlaceholder()
          ? _value.source_
          // ignore: cast_nullable_to_non_nullable
          : source_ as DemoEntitlementSource_Enum,
      startsAt: startsAt == const $CopyWithPlaceholder()
          ? _value.startsAt
          // ignore: cast_nullable_to_non_nullable
          : startsAt as DateTime,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as DemoEntitlementStatusEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $DemoEntitlementCopyWith on DemoEntitlement {
  /// Returns a callable class that can be used as follows: `instanceOfDemoEntitlement.copyWith(...)` or like so:`instanceOfDemoEntitlement.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DemoEntitlementCWProxy get copyWith => _$DemoEntitlementCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DemoEntitlement _$DemoEntitlementFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'DemoEntitlement',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'demo',
            'ends_at',
            'id',
            'plan_code',
            'source',
            'starts_at',
            'status',
            'version',
          ],
        );
        final val = DemoEntitlement(
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          endsAt: $checkedConvert(
            'ends_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          id: $checkedConvert('id', (v) => v as String),
          planCode: $checkedConvert(
            'plan_code',
            (v) => $enumDecode(
              _$DemoEntitlementPlanCodeEnumEnumMap,
              v,
              unknownValue: DemoEntitlementPlanCodeEnum.unknownDefaultOpenApi,
            ),
          ),
          source_: $checkedConvert(
            'source',
            (v) => $enumDecode(
              _$DemoEntitlementSource_EnumEnumMap,
              v,
              unknownValue: DemoEntitlementSource_Enum.unknownDefaultOpenApi,
            ),
          ),
          startsAt: $checkedConvert(
            'starts_at',
            (v) => DateTime.parse(v as String),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$DemoEntitlementStatusEnumEnumMap,
              v,
              unknownValue: DemoEntitlementStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'endsAt': 'ends_at',
        'planCode': 'plan_code',
        'source_': 'source',
        'startsAt': 'starts_at',
      },
    );

Map<String, dynamic> _$DemoEntitlementToJson(DemoEntitlement instance) =>
    <String, dynamic>{
      'demo': instance.demo.toJson(),
      'ends_at': instance.endsAt?.toIso8601String(),
      'id': instance.id,
      'plan_code': _$DemoEntitlementPlanCodeEnumEnumMap[instance.planCode]!,
      'source': _$DemoEntitlementSource_EnumEnumMap[instance.source_]!,
      'starts_at': instance.startsAt.toIso8601String(),
      'status': _$DemoEntitlementStatusEnumEnumMap[instance.status]!,
      'version': instance.version,
    };

const _$DemoEntitlementPlanCodeEnumEnumMap = {
  DemoEntitlementPlanCodeEnum.free: 'free',
  DemoEntitlementPlanCodeEnum.premiumDemo: 'premium_demo',
  DemoEntitlementPlanCodeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$DemoEntitlementSource_EnumEnumMap = {
  DemoEntitlementSource_Enum.demo: 'demo',
  DemoEntitlementSource_Enum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$DemoEntitlementStatusEnumEnumMap = {
  DemoEntitlementStatusEnum.active: 'active',
  DemoEntitlementStatusEnum.expired: 'expired',
  DemoEntitlementStatusEnum.revoked: 'revoked',
  DemoEntitlementStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
