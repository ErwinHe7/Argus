// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_demo_contribution_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateDemoContributionRequestCWProxy {
  CreateDemoContributionRequest amount(PositiveInputMoney amount);

  CreateDemoContributionRequest effectiveAt(DateTime? effectiveAt);

  CreateDemoContributionRequest sourceId(String sourceId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoContributionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoContributionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoContributionRequest call({
    PositiveInputMoney amount,
    DateTime? effectiveAt,
    String sourceId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateDemoContributionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateDemoContributionRequest.copyWith.fieldName(...)`
class _$CreateDemoContributionRequestCWProxyImpl
    implements _$CreateDemoContributionRequestCWProxy {
  const _$CreateDemoContributionRequestCWProxyImpl(this._value);

  final CreateDemoContributionRequest _value;

  @override
  CreateDemoContributionRequest amount(PositiveInputMoney amount) =>
      this(amount: amount);

  @override
  CreateDemoContributionRequest effectiveAt(DateTime? effectiveAt) =>
      this(effectiveAt: effectiveAt);

  @override
  CreateDemoContributionRequest sourceId(String sourceId) =>
      this(sourceId: sourceId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoContributionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoContributionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoContributionRequest call({
    Object? amount = const $CopyWithPlaceholder(),
    Object? effectiveAt = const $CopyWithPlaceholder(),
    Object? sourceId = const $CopyWithPlaceholder(),
  }) {
    return CreateDemoContributionRequest(
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as PositiveInputMoney,
      effectiveAt: effectiveAt == const $CopyWithPlaceholder()
          ? _value.effectiveAt
          // ignore: cast_nullable_to_non_nullable
          : effectiveAt as DateTime?,
      sourceId: sourceId == const $CopyWithPlaceholder()
          ? _value.sourceId
          // ignore: cast_nullable_to_non_nullable
          : sourceId as String,
    );
  }
}

extension $CreateDemoContributionRequestCopyWith
    on CreateDemoContributionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateDemoContributionRequest.copyWith(...)` or like so:`instanceOfCreateDemoContributionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateDemoContributionRequestCWProxy get copyWith =>
      _$CreateDemoContributionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateDemoContributionRequest _$CreateDemoContributionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateDemoContributionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['amount', 'source_id']);
  final val = CreateDemoContributionRequest(
    amount: $checkedConvert(
      'amount',
      (v) => PositiveInputMoney.fromJson(v as Map<String, dynamic>),
    ),
    effectiveAt: $checkedConvert(
      'effective_at',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    sourceId: $checkedConvert('source_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'effectiveAt': 'effective_at', 'sourceId': 'source_id'});

Map<String, dynamic> _$CreateDemoContributionRequestToJson(
  CreateDemoContributionRequest instance,
) => <String, dynamic>{
  'amount': instance.amount.toJson(),
  'effective_at': ?instance.effectiveAt?.toIso8601String(),
  'source_id': instance.sourceId,
};
