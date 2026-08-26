// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_plan.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DemoPlanCWProxy {
  DemoPlan code(DemoPlanCodeEnum code);

  DemoPlan demo(SimulationDemoDisclosure demo);

  DemoPlan displayName(String displayName);

  DemoPlan featureCodes(List<String> featureCodes);

  DemoPlan priceCopy(String priceCopy);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoPlan(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoPlan(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoPlan call({
    DemoPlanCodeEnum code,
    SimulationDemoDisclosure demo,
    String displayName,
    List<String> featureCodes,
    String priceCopy,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDemoPlan.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDemoPlan.copyWith.fieldName(...)`
class _$DemoPlanCWProxyImpl implements _$DemoPlanCWProxy {
  const _$DemoPlanCWProxyImpl(this._value);

  final DemoPlan _value;

  @override
  DemoPlan code(DemoPlanCodeEnum code) => this(code: code);

  @override
  DemoPlan demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  DemoPlan displayName(String displayName) => this(displayName: displayName);

  @override
  DemoPlan featureCodes(List<String> featureCodes) =>
      this(featureCodes: featureCodes);

  @override
  DemoPlan priceCopy(String priceCopy) => this(priceCopy: priceCopy);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoPlan(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoPlan(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoPlan call({
    Object? code = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? displayName = const $CopyWithPlaceholder(),
    Object? featureCodes = const $CopyWithPlaceholder(),
    Object? priceCopy = const $CopyWithPlaceholder(),
  }) {
    return DemoPlan(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as DemoPlanCodeEnum,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      displayName: displayName == const $CopyWithPlaceholder()
          ? _value.displayName
          // ignore: cast_nullable_to_non_nullable
          : displayName as String,
      featureCodes: featureCodes == const $CopyWithPlaceholder()
          ? _value.featureCodes
          // ignore: cast_nullable_to_non_nullable
          : featureCodes as List<String>,
      priceCopy: priceCopy == const $CopyWithPlaceholder()
          ? _value.priceCopy
          // ignore: cast_nullable_to_non_nullable
          : priceCopy as String,
    );
  }
}

extension $DemoPlanCopyWith on DemoPlan {
  /// Returns a callable class that can be used as follows: `instanceOfDemoPlan.copyWith(...)` or like so:`instanceOfDemoPlan.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DemoPlanCWProxy get copyWith => _$DemoPlanCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DemoPlan _$DemoPlanFromJson(Map<String, dynamic> json) => $checkedCreate(
  'DemoPlan',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'code',
        'demo',
        'display_name',
        'feature_codes',
        'price_copy',
      ],
    );
    final val = DemoPlan(
      code: $checkedConvert(
        'code',
        (v) => $enumDecode(
          _$DemoPlanCodeEnumEnumMap,
          v,
          unknownValue: DemoPlanCodeEnum.unknownDefaultOpenApi,
        ),
      ),
      demo: $checkedConvert(
        'demo',
        (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
      ),
      displayName: $checkedConvert('display_name', (v) => v as String),
      featureCodes: $checkedConvert(
        'feature_codes',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      priceCopy: $checkedConvert('price_copy', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'displayName': 'display_name',
    'featureCodes': 'feature_codes',
    'priceCopy': 'price_copy',
  },
);

Map<String, dynamic> _$DemoPlanToJson(DemoPlan instance) => <String, dynamic>{
  'code': _$DemoPlanCodeEnumEnumMap[instance.code]!,
  'demo': instance.demo.toJson(),
  'display_name': instance.displayName,
  'feature_codes': instance.featureCodes,
  'price_copy': instance.priceCopy,
};

const _$DemoPlanCodeEnumEnumMap = {
  DemoPlanCodeEnum.free: 'free',
  DemoPlanCodeEnum.premiumDemo: 'premium_demo',
  DemoPlanCodeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
