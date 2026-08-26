// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_default_portfolio.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapDefaultPortfolioCWProxy {
  SessionBootstrapDefaultPortfolio currency(
    SessionBootstrapDefaultPortfolioCurrencyEnum currency,
  );

  SessionBootstrapDefaultPortfolio id(String id);

  SessionBootstrapDefaultPortfolio name(String name);

  SessionBootstrapDefaultPortfolio status(
    SessionBootstrapDefaultPortfolioStatusEnum status,
  );

  SessionBootstrapDefaultPortfolio version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapDefaultPortfolio(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapDefaultPortfolio(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapDefaultPortfolio call({
    SessionBootstrapDefaultPortfolioCurrencyEnum currency,
    String id,
    String name,
    SessionBootstrapDefaultPortfolioStatusEnum status,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapDefaultPortfolio.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapDefaultPortfolio.copyWith.fieldName(...)`
class _$SessionBootstrapDefaultPortfolioCWProxyImpl
    implements _$SessionBootstrapDefaultPortfolioCWProxy {
  const _$SessionBootstrapDefaultPortfolioCWProxyImpl(this._value);

  final SessionBootstrapDefaultPortfolio _value;

  @override
  SessionBootstrapDefaultPortfolio currency(
    SessionBootstrapDefaultPortfolioCurrencyEnum currency,
  ) => this(currency: currency);

  @override
  SessionBootstrapDefaultPortfolio id(String id) => this(id: id);

  @override
  SessionBootstrapDefaultPortfolio name(String name) => this(name: name);

  @override
  SessionBootstrapDefaultPortfolio status(
    SessionBootstrapDefaultPortfolioStatusEnum status,
  ) => this(status: status);

  @override
  SessionBootstrapDefaultPortfolio version(int version) =>
      this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapDefaultPortfolio(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapDefaultPortfolio(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapDefaultPortfolio call({
    Object? currency = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapDefaultPortfolio(
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as SessionBootstrapDefaultPortfolioCurrencyEnum,
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
          : status as SessionBootstrapDefaultPortfolioStatusEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $SessionBootstrapDefaultPortfolioCopyWith
    on SessionBootstrapDefaultPortfolio {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrapDefaultPortfolio.copyWith(...)` or like so:`instanceOfSessionBootstrapDefaultPortfolio.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapDefaultPortfolioCWProxy get copyWith =>
      _$SessionBootstrapDefaultPortfolioCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrapDefaultPortfolio _$SessionBootstrapDefaultPortfolioFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SessionBootstrapDefaultPortfolio', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    requiredKeys: const ['currency', 'id', 'name', 'status', 'version'],
  );
  final val = SessionBootstrapDefaultPortfolio(
    currency: $checkedConvert(
      'currency',
      (v) => $enumDecode(
        _$SessionBootstrapDefaultPortfolioCurrencyEnumEnumMap,
        v,
        unknownValue:
            SessionBootstrapDefaultPortfolioCurrencyEnum.unknownDefaultOpenApi,
      ),
    ),
    id: $checkedConvert('id', (v) => v as String),
    name: $checkedConvert('name', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$SessionBootstrapDefaultPortfolioStatusEnumEnumMap,
        v,
        unknownValue:
            SessionBootstrapDefaultPortfolioStatusEnum.unknownDefaultOpenApi,
      ),
    ),
    version: $checkedConvert('version', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$SessionBootstrapDefaultPortfolioToJson(
  SessionBootstrapDefaultPortfolio instance,
) => <String, dynamic>{
  'currency':
      _$SessionBootstrapDefaultPortfolioCurrencyEnumEnumMap[instance.currency]!,
  'id': instance.id,
  'name': instance.name,
  'status':
      _$SessionBootstrapDefaultPortfolioStatusEnumEnumMap[instance.status]!,
  'version': instance.version,
};

const _$SessionBootstrapDefaultPortfolioCurrencyEnumEnumMap = {
  SessionBootstrapDefaultPortfolioCurrencyEnum.USD: 'USD',
  SessionBootstrapDefaultPortfolioCurrencyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$SessionBootstrapDefaultPortfolioStatusEnumEnumMap = {
  SessionBootstrapDefaultPortfolioStatusEnum.active: 'active',
  SessionBootstrapDefaultPortfolioStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
