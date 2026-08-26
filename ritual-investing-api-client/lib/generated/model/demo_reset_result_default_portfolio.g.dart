// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_reset_result_default_portfolio.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DemoResetResultDefaultPortfolioCWProxy {
  DemoResetResultDefaultPortfolio currency(
    DemoResetResultDefaultPortfolioCurrencyEnum currency,
  );

  DemoResetResultDefaultPortfolio id(String id);

  DemoResetResultDefaultPortfolio name(String name);

  DemoResetResultDefaultPortfolio status(
    DemoResetResultDefaultPortfolioStatusEnum status,
  );

  DemoResetResultDefaultPortfolio version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoResetResultDefaultPortfolio(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoResetResultDefaultPortfolio(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoResetResultDefaultPortfolio call({
    DemoResetResultDefaultPortfolioCurrencyEnum currency,
    String id,
    String name,
    DemoResetResultDefaultPortfolioStatusEnum status,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDemoResetResultDefaultPortfolio.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDemoResetResultDefaultPortfolio.copyWith.fieldName(...)`
class _$DemoResetResultDefaultPortfolioCWProxyImpl
    implements _$DemoResetResultDefaultPortfolioCWProxy {
  const _$DemoResetResultDefaultPortfolioCWProxyImpl(this._value);

  final DemoResetResultDefaultPortfolio _value;

  @override
  DemoResetResultDefaultPortfolio currency(
    DemoResetResultDefaultPortfolioCurrencyEnum currency,
  ) => this(currency: currency);

  @override
  DemoResetResultDefaultPortfolio id(String id) => this(id: id);

  @override
  DemoResetResultDefaultPortfolio name(String name) => this(name: name);

  @override
  DemoResetResultDefaultPortfolio status(
    DemoResetResultDefaultPortfolioStatusEnum status,
  ) => this(status: status);

  @override
  DemoResetResultDefaultPortfolio version(int version) =>
      this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoResetResultDefaultPortfolio(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoResetResultDefaultPortfolio(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoResetResultDefaultPortfolio call({
    Object? currency = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return DemoResetResultDefaultPortfolio(
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as DemoResetResultDefaultPortfolioCurrencyEnum,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as DemoResetResultDefaultPortfolioStatusEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $DemoResetResultDefaultPortfolioCopyWith
    on DemoResetResultDefaultPortfolio {
  /// Returns a callable class that can be used as follows: `instanceOfDemoResetResultDefaultPortfolio.copyWith(...)` or like so:`instanceOfDemoResetResultDefaultPortfolio.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DemoResetResultDefaultPortfolioCWProxy get copyWith =>
      _$DemoResetResultDefaultPortfolioCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DemoResetResultDefaultPortfolio _$DemoResetResultDefaultPortfolioFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DemoResetResultDefaultPortfolio', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['currency', 'id', 'name', 'status', 'version'],
  );
  final val = DemoResetResultDefaultPortfolio(
    currency: $checkedConvert(
      'currency',
      (v) => $enumDecode(
        _$DemoResetResultDefaultPortfolioCurrencyEnumEnumMap,
        v,
        unknownValue:
            DemoResetResultDefaultPortfolioCurrencyEnum.unknownDefaultOpenApi,
      ),
    ),
    id: $checkedConvert('id', (v) => v as String),
    name: $checkedConvert('name', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$DemoResetResultDefaultPortfolioStatusEnumEnumMap,
        v,
        unknownValue:
            DemoResetResultDefaultPortfolioStatusEnum.unknownDefaultOpenApi,
      ),
    ),
    version: $checkedConvert('version', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$DemoResetResultDefaultPortfolioToJson(
  DemoResetResultDefaultPortfolio instance,
) => <String, dynamic>{
  'currency':
      _$DemoResetResultDefaultPortfolioCurrencyEnumEnumMap[instance.currency]!,
  'id': instance.id,
  'name': instance.name,
  'status':
      _$DemoResetResultDefaultPortfolioStatusEnumEnumMap[instance.status]!,
  'version': instance.version,
};

const _$DemoResetResultDefaultPortfolioCurrencyEnumEnumMap = {
  DemoResetResultDefaultPortfolioCurrencyEnum.USD: 'USD',
  DemoResetResultDefaultPortfolioCurrencyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$DemoResetResultDefaultPortfolioStatusEnumEnumMap = {
  DemoResetResultDefaultPortfolioStatusEnum.active: 'active',
  DemoResetResultDefaultPortfolioStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
