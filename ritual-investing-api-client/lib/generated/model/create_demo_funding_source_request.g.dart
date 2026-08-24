// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_demo_funding_source_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateDemoFundingSourceRequestCWProxy {
  CreateDemoFundingSourceRequest fixtureKey(
    CreateDemoFundingSourceRequestFixtureKeyEnum fixtureKey,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoFundingSourceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoFundingSourceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoFundingSourceRequest call({
    CreateDemoFundingSourceRequestFixtureKeyEnum fixtureKey,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateDemoFundingSourceRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateDemoFundingSourceRequest.copyWith.fieldName(...)`
class _$CreateDemoFundingSourceRequestCWProxyImpl
    implements _$CreateDemoFundingSourceRequestCWProxy {
  const _$CreateDemoFundingSourceRequestCWProxyImpl(this._value);

  final CreateDemoFundingSourceRequest _value;

  @override
  CreateDemoFundingSourceRequest fixtureKey(
    CreateDemoFundingSourceRequestFixtureKeyEnum fixtureKey,
  ) => this(fixtureKey: fixtureKey);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoFundingSourceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoFundingSourceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoFundingSourceRequest call({
    Object? fixtureKey = const $CopyWithPlaceholder(),
  }) {
    return CreateDemoFundingSourceRequest(
      fixtureKey: fixtureKey == const $CopyWithPlaceholder()
          ? _value.fixtureKey
          // ignore: cast_nullable_to_non_nullable
          : fixtureKey as CreateDemoFundingSourceRequestFixtureKeyEnum,
    );
  }
}

extension $CreateDemoFundingSourceRequestCopyWith
    on CreateDemoFundingSourceRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateDemoFundingSourceRequest.copyWith(...)` or like so:`instanceOfCreateDemoFundingSourceRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateDemoFundingSourceRequestCWProxy get copyWith =>
      _$CreateDemoFundingSourceRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateDemoFundingSourceRequest _$CreateDemoFundingSourceRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateDemoFundingSourceRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['fixture_key']);
  final val = CreateDemoFundingSourceRequest(
    fixtureKey: $checkedConvert(
      'fixture_key',
      (v) => $enumDecode(
        _$CreateDemoFundingSourceRequestFixtureKeyEnumEnumMap,
        v,
        unknownValue:
            CreateDemoFundingSourceRequestFixtureKeyEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'fixtureKey': 'fixture_key'});

Map<String, dynamic> _$CreateDemoFundingSourceRequestToJson(
  CreateDemoFundingSourceRequest instance,
) => <String, dynamic>{
  'fixture_key':
      _$CreateDemoFundingSourceRequestFixtureKeyEnumEnumMap[instance
          .fixtureKey]!,
};

const _$CreateDemoFundingSourceRequestFixtureKeyEnumEnumMap = {
  CreateDemoFundingSourceRequestFixtureKeyEnum.moonReserve: 'moon_reserve',
  CreateDemoFundingSourceRequestFixtureKeyEnum.constellationSavings:
      'constellation_savings',
  CreateDemoFundingSourceRequestFixtureKeyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
