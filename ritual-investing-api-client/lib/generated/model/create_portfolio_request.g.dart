// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_portfolio_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreatePortfolioRequestCWProxy {
  CreatePortfolioRequest currency(CreatePortfolioRequestCurrencyEnum currency);

  CreatePortfolioRequest name(String name);

  CreatePortfolioRequest targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner>? targetAllocation,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatePortfolioRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatePortfolioRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatePortfolioRequest call({
    CreatePortfolioRequestCurrencyEnum currency,
    String name,
    List<CreatePortfolioRequestTargetAllocationInner>? targetAllocation,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreatePortfolioRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreatePortfolioRequest.copyWith.fieldName(...)`
class _$CreatePortfolioRequestCWProxyImpl
    implements _$CreatePortfolioRequestCWProxy {
  const _$CreatePortfolioRequestCWProxyImpl(this._value);

  final CreatePortfolioRequest _value;

  @override
  CreatePortfolioRequest currency(
    CreatePortfolioRequestCurrencyEnum currency,
  ) => this(currency: currency);

  @override
  CreatePortfolioRequest name(String name) => this(name: name);

  @override
  CreatePortfolioRequest targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner>? targetAllocation,
  ) => this(targetAllocation: targetAllocation);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatePortfolioRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatePortfolioRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatePortfolioRequest call({
    Object? currency = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? targetAllocation = const $CopyWithPlaceholder(),
  }) {
    return CreatePortfolioRequest(
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as CreatePortfolioRequestCurrencyEnum,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      targetAllocation: targetAllocation == const $CopyWithPlaceholder()
          ? _value.targetAllocation
          // ignore: cast_nullable_to_non_nullable
          : targetAllocation
                as List<CreatePortfolioRequestTargetAllocationInner>?,
    );
  }
}

extension $CreatePortfolioRequestCopyWith on CreatePortfolioRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreatePortfolioRequest.copyWith(...)` or like so:`instanceOfCreatePortfolioRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreatePortfolioRequestCWProxy get copyWith =>
      _$CreatePortfolioRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePortfolioRequest _$CreatePortfolioRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreatePortfolioRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['currency', 'name']);
  final val = CreatePortfolioRequest(
    currency: $checkedConvert(
      'currency',
      (v) => $enumDecode(
        _$CreatePortfolioRequestCurrencyEnumEnumMap,
        v,
        unknownValue: CreatePortfolioRequestCurrencyEnum.unknownDefaultOpenApi,
      ),
    ),
    name: $checkedConvert('name', (v) => v as String),
    targetAllocation: $checkedConvert(
      'target_allocation',
      (v) => (v as List<dynamic>?)
          ?.map(
            (e) => CreatePortfolioRequestTargetAllocationInner.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'targetAllocation': 'target_allocation'});

Map<String, dynamic> _$CreatePortfolioRequestToJson(
  CreatePortfolioRequest instance,
) => <String, dynamic>{
  'currency': _$CreatePortfolioRequestCurrencyEnumEnumMap[instance.currency]!,
  'name': instance.name,
  'target_allocation': ?instance.targetAllocation
      ?.map((e) => e.toJson())
      .toList(),
};

const _$CreatePortfolioRequestCurrencyEnumEnumMap = {
  CreatePortfolioRequestCurrencyEnum.USD: 'USD',
  CreatePortfolioRequestCurrencyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
