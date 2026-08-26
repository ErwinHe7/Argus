// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_checkout_session.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DemoCheckoutSessionCWProxy {
  DemoCheckoutSession demo(SimulationDemoDisclosure demo);

  DemoCheckoutSession expiresAt(DateTime expiresAt);

  DemoCheckoutSession id(String id);

  DemoCheckoutSession planCode(DemoCheckoutSessionPlanCodeEnum planCode);

  DemoCheckoutSession status(DemoCheckoutSessionStatusEnum status);

  DemoCheckoutSession version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoCheckoutSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoCheckoutSession(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoCheckoutSession call({
    SimulationDemoDisclosure demo,
    DateTime expiresAt,
    String id,
    DemoCheckoutSessionPlanCodeEnum planCode,
    DemoCheckoutSessionStatusEnum status,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDemoCheckoutSession.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDemoCheckoutSession.copyWith.fieldName(...)`
class _$DemoCheckoutSessionCWProxyImpl implements _$DemoCheckoutSessionCWProxy {
  const _$DemoCheckoutSessionCWProxyImpl(this._value);

  final DemoCheckoutSession _value;

  @override
  DemoCheckoutSession demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  DemoCheckoutSession expiresAt(DateTime expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  DemoCheckoutSession id(String id) => this(id: id);

  @override
  DemoCheckoutSession planCode(DemoCheckoutSessionPlanCodeEnum planCode) =>
      this(planCode: planCode);

  @override
  DemoCheckoutSession status(DemoCheckoutSessionStatusEnum status) =>
      this(status: status);

  @override
  DemoCheckoutSession version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoCheckoutSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoCheckoutSession(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoCheckoutSession call({
    Object? demo = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? planCode = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return DemoCheckoutSession(
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      planCode: planCode == const $CopyWithPlaceholder()
          ? _value.planCode
          // ignore: cast_nullable_to_non_nullable
          : planCode as DemoCheckoutSessionPlanCodeEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as DemoCheckoutSessionStatusEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $DemoCheckoutSessionCopyWith on DemoCheckoutSession {
  /// Returns a callable class that can be used as follows: `instanceOfDemoCheckoutSession.copyWith(...)` or like so:`instanceOfDemoCheckoutSession.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DemoCheckoutSessionCWProxy get copyWith =>
      _$DemoCheckoutSessionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DemoCheckoutSession _$DemoCheckoutSessionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DemoCheckoutSession', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'demo',
          'expires_at',
          'id',
          'plan_code',
          'status',
          'version',
        ],
      );
      final val = DemoCheckoutSession(
        demo: $checkedConvert(
          'demo',
          (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
        ),
        expiresAt: $checkedConvert(
          'expires_at',
          (v) => DateTime.parse(v as String),
        ),
        id: $checkedConvert('id', (v) => v as String),
        planCode: $checkedConvert(
          'plan_code',
          (v) => $enumDecode(
            _$DemoCheckoutSessionPlanCodeEnumEnumMap,
            v,
            unknownValue: DemoCheckoutSessionPlanCodeEnum.unknownDefaultOpenApi,
          ),
        ),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$DemoCheckoutSessionStatusEnumEnumMap,
            v,
            unknownValue: DemoCheckoutSessionStatusEnum.unknownDefaultOpenApi,
          ),
        ),
        version: $checkedConvert('version', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'expiresAt': 'expires_at', 'planCode': 'plan_code'});

Map<String, dynamic> _$DemoCheckoutSessionToJson(
  DemoCheckoutSession instance,
) => <String, dynamic>{
  'demo': instance.demo.toJson(),
  'expires_at': instance.expiresAt.toIso8601String(),
  'id': instance.id,
  'plan_code': _$DemoCheckoutSessionPlanCodeEnumEnumMap[instance.planCode]!,
  'status': _$DemoCheckoutSessionStatusEnumEnumMap[instance.status]!,
  'version': instance.version,
};

const _$DemoCheckoutSessionPlanCodeEnumEnumMap = {
  DemoCheckoutSessionPlanCodeEnum.premiumDemo: 'premium_demo',
  DemoCheckoutSessionPlanCodeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$DemoCheckoutSessionStatusEnumEnumMap = {
  DemoCheckoutSessionStatusEnum.open: 'open',
  DemoCheckoutSessionStatusEnum.completed: 'completed',
  DemoCheckoutSessionStatusEnum.expired: 'expired',
  DemoCheckoutSessionStatusEnum.cancelled: 'cancelled',
  DemoCheckoutSessionStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
