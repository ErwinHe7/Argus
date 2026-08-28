// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_order_preview.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrderPreviewCWProxy {
  BrokerageOrderPreview accountId(String accountId);

  BrokerageOrderPreview capabilityVersion(int capabilityVersion);

  BrokerageOrderPreview currency(String? currency);

  BrokerageOrderPreview estimatedTotal(String? estimatedTotal);

  BrokerageOrderPreview expiresAt(DateTime expiresAt);

  BrokerageOrderPreview id(String id);

  BrokerageOrderPreview operation(BrokerageOrderPreviewOperationEnum operation);

  BrokerageOrderPreview policyVersion(String policyVersion);

  BrokerageOrderPreview restrictionGeneration(int restrictionGeneration);

  BrokerageOrderPreview reviewedPayloadHash(String reviewedPayloadHash);

  BrokerageOrderPreview targetOrderId(String? targetOrderId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderPreview(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderPreview(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderPreview call({
    String accountId,
    int capabilityVersion,
    String? currency,
    String? estimatedTotal,
    DateTime expiresAt,
    String id,
    BrokerageOrderPreviewOperationEnum operation,
    String policyVersion,
    int restrictionGeneration,
    String reviewedPayloadHash,
    String? targetOrderId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrderPreview.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrderPreview.copyWith.fieldName(...)`
class _$BrokerageOrderPreviewCWProxyImpl
    implements _$BrokerageOrderPreviewCWProxy {
  const _$BrokerageOrderPreviewCWProxyImpl(this._value);

  final BrokerageOrderPreview _value;

  @override
  BrokerageOrderPreview accountId(String accountId) =>
      this(accountId: accountId);

  @override
  BrokerageOrderPreview capabilityVersion(int capabilityVersion) =>
      this(capabilityVersion: capabilityVersion);

  @override
  BrokerageOrderPreview currency(String? currency) => this(currency: currency);

  @override
  BrokerageOrderPreview estimatedTotal(String? estimatedTotal) =>
      this(estimatedTotal: estimatedTotal);

  @override
  BrokerageOrderPreview expiresAt(DateTime expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  BrokerageOrderPreview id(String id) => this(id: id);

  @override
  BrokerageOrderPreview operation(
    BrokerageOrderPreviewOperationEnum operation,
  ) => this(operation: operation);

  @override
  BrokerageOrderPreview policyVersion(String policyVersion) =>
      this(policyVersion: policyVersion);

  @override
  BrokerageOrderPreview restrictionGeneration(int restrictionGeneration) =>
      this(restrictionGeneration: restrictionGeneration);

  @override
  BrokerageOrderPreview reviewedPayloadHash(String reviewedPayloadHash) =>
      this(reviewedPayloadHash: reviewedPayloadHash);

  @override
  BrokerageOrderPreview targetOrderId(String? targetOrderId) =>
      this(targetOrderId: targetOrderId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrderPreview(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrderPreview(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrderPreview call({
    Object? accountId = const $CopyWithPlaceholder(),
    Object? capabilityVersion = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? estimatedTotal = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? operation = const $CopyWithPlaceholder(),
    Object? policyVersion = const $CopyWithPlaceholder(),
    Object? restrictionGeneration = const $CopyWithPlaceholder(),
    Object? reviewedPayloadHash = const $CopyWithPlaceholder(),
    Object? targetOrderId = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrderPreview(
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      capabilityVersion: capabilityVersion == const $CopyWithPlaceholder()
          ? _value.capabilityVersion
          // ignore: cast_nullable_to_non_nullable
          : capabilityVersion as int,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as String?,
      estimatedTotal: estimatedTotal == const $CopyWithPlaceholder()
          ? _value.estimatedTotal
          // ignore: cast_nullable_to_non_nullable
          : estimatedTotal as String?,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      operation: operation == const $CopyWithPlaceholder()
          ? _value.operation
          // ignore: cast_nullable_to_non_nullable
          : operation as BrokerageOrderPreviewOperationEnum,
      policyVersion: policyVersion == const $CopyWithPlaceholder()
          ? _value.policyVersion
          // ignore: cast_nullable_to_non_nullable
          : policyVersion as String,
      restrictionGeneration:
          restrictionGeneration == const $CopyWithPlaceholder()
          ? _value.restrictionGeneration
          // ignore: cast_nullable_to_non_nullable
          : restrictionGeneration as int,
      reviewedPayloadHash: reviewedPayloadHash == const $CopyWithPlaceholder()
          ? _value.reviewedPayloadHash
          // ignore: cast_nullable_to_non_nullable
          : reviewedPayloadHash as String,
      targetOrderId: targetOrderId == const $CopyWithPlaceholder()
          ? _value.targetOrderId
          // ignore: cast_nullable_to_non_nullable
          : targetOrderId as String?,
    );
  }
}

extension $BrokerageOrderPreviewCopyWith on BrokerageOrderPreview {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrderPreview.copyWith(...)` or like so:`instanceOfBrokerageOrderPreview.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrderPreviewCWProxy get copyWith =>
      _$BrokerageOrderPreviewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrderPreview _$BrokerageOrderPreviewFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'BrokerageOrderPreview',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'account_id',
        'capability_version',
        'currency',
        'estimated_total',
        'expires_at',
        'id',
        'operation',
        'policy_version',
        'restriction_generation',
        'reviewed_payload_hash',
        'target_order_id',
      ],
    );
    final val = BrokerageOrderPreview(
      accountId: $checkedConvert('account_id', (v) => v as String),
      capabilityVersion: $checkedConvert(
        'capability_version',
        (v) => (v as num).toInt(),
      ),
      currency: $checkedConvert('currency', (v) => v as String?),
      estimatedTotal: $checkedConvert('estimated_total', (v) => v as String?),
      expiresAt: $checkedConvert(
        'expires_at',
        (v) => DateTime.parse(v as String),
      ),
      id: $checkedConvert('id', (v) => v as String),
      operation: $checkedConvert(
        'operation',
        (v) => $enumDecode(
          _$BrokerageOrderPreviewOperationEnumEnumMap,
          v,
          unknownValue:
              BrokerageOrderPreviewOperationEnum.unknownDefaultOpenApi,
        ),
      ),
      policyVersion: $checkedConvert('policy_version', (v) => v as String),
      restrictionGeneration: $checkedConvert(
        'restriction_generation',
        (v) => (v as num).toInt(),
      ),
      reviewedPayloadHash: $checkedConvert(
        'reviewed_payload_hash',
        (v) => v as String,
      ),
      targetOrderId: $checkedConvert('target_order_id', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'accountId': 'account_id',
    'capabilityVersion': 'capability_version',
    'estimatedTotal': 'estimated_total',
    'expiresAt': 'expires_at',
    'policyVersion': 'policy_version',
    'restrictionGeneration': 'restriction_generation',
    'reviewedPayloadHash': 'reviewed_payload_hash',
    'targetOrderId': 'target_order_id',
  },
);

Map<String, dynamic> _$BrokerageOrderPreviewToJson(
  BrokerageOrderPreview instance,
) => <String, dynamic>{
  'account_id': instance.accountId,
  'capability_version': instance.capabilityVersion,
  'currency': instance.currency,
  'estimated_total': instance.estimatedTotal,
  'expires_at': instance.expiresAt.toIso8601String(),
  'id': instance.id,
  'operation': _$BrokerageOrderPreviewOperationEnumEnumMap[instance.operation]!,
  'policy_version': instance.policyVersion,
  'restriction_generation': instance.restrictionGeneration,
  'reviewed_payload_hash': instance.reviewedPayloadHash,
  'target_order_id': instance.targetOrderId,
};

const _$BrokerageOrderPreviewOperationEnumEnumMap = {
  BrokerageOrderPreviewOperationEnum.place: 'place',
  BrokerageOrderPreviewOperationEnum.modify: 'modify',
  BrokerageOrderPreviewOperationEnum.cancel: 'cancel',
  BrokerageOrderPreviewOperationEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
