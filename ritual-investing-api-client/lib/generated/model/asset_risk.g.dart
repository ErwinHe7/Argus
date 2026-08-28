// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_risk.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetRiskCWProxy {
  AssetRisk detail(String detail);

  AssetRisk severity(AssetRiskSeverityEnum severity);

  AssetRisk title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetRisk(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetRisk(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetRisk call({String detail, AssetRiskSeverityEnum severity, String title});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetRisk.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetRisk.copyWith.fieldName(...)`
class _$AssetRiskCWProxyImpl implements _$AssetRiskCWProxy {
  const _$AssetRiskCWProxyImpl(this._value);

  final AssetRisk _value;

  @override
  AssetRisk detail(String detail) => this(detail: detail);

  @override
  AssetRisk severity(AssetRiskSeverityEnum severity) =>
      this(severity: severity);

  @override
  AssetRisk title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetRisk(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetRisk(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetRisk call({
    Object? detail = const $CopyWithPlaceholder(),
    Object? severity = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return AssetRisk(
      detail: detail == const $CopyWithPlaceholder()
          ? _value.detail
          // ignore: cast_nullable_to_non_nullable
          : detail as String,
      severity: severity == const $CopyWithPlaceholder()
          ? _value.severity
          // ignore: cast_nullable_to_non_nullable
          : severity as AssetRiskSeverityEnum,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $AssetRiskCopyWith on AssetRisk {
  /// Returns a callable class that can be used as follows: `instanceOfAssetRisk.copyWith(...)` or like so:`instanceOfAssetRisk.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetRiskCWProxy get copyWith => _$AssetRiskCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetRisk _$AssetRiskFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AssetRisk', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['detail', 'severity', 'title']);
      final val = AssetRisk(
        detail: $checkedConvert('detail', (v) => v as String),
        severity: $checkedConvert(
          'severity',
          (v) => $enumDecode(
            _$AssetRiskSeverityEnumEnumMap,
            v,
            unknownValue: AssetRiskSeverityEnum.unknownDefaultOpenApi,
          ),
        ),
        title: $checkedConvert('title', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$AssetRiskToJson(AssetRisk instance) => <String, dynamic>{
  'detail': instance.detail,
  'severity': _$AssetRiskSeverityEnumEnumMap[instance.severity]!,
  'title': instance.title,
};

const _$AssetRiskSeverityEnumEnumMap = {
  AssetRiskSeverityEnum.low: 'low',
  AssetRiskSeverityEnum.medium: 'medium',
  AssetRiskSeverityEnum.high: 'high',
  AssetRiskSeverityEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
