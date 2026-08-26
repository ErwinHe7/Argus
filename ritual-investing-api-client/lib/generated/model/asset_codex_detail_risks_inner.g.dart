// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_codex_detail_risks_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetCodexDetailRisksInnerCWProxy {
  AssetCodexDetailRisksInner detail(String detail);

  AssetCodexDetailRisksInner severity(
    AssetCodexDetailRisksInnerSeverityEnum severity,
  );

  AssetCodexDetailRisksInner title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetCodexDetailRisksInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetCodexDetailRisksInner(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetCodexDetailRisksInner call({
    String detail,
    AssetCodexDetailRisksInnerSeverityEnum severity,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetCodexDetailRisksInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetCodexDetailRisksInner.copyWith.fieldName(...)`
class _$AssetCodexDetailRisksInnerCWProxyImpl
    implements _$AssetCodexDetailRisksInnerCWProxy {
  const _$AssetCodexDetailRisksInnerCWProxyImpl(this._value);

  final AssetCodexDetailRisksInner _value;

  @override
  AssetCodexDetailRisksInner detail(String detail) => this(detail: detail);

  @override
  AssetCodexDetailRisksInner severity(
    AssetCodexDetailRisksInnerSeverityEnum severity,
  ) => this(severity: severity);

  @override
  AssetCodexDetailRisksInner title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetCodexDetailRisksInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetCodexDetailRisksInner(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetCodexDetailRisksInner call({
    Object? detail = const $CopyWithPlaceholder(),
    Object? severity = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return AssetCodexDetailRisksInner(
      detail: detail == const $CopyWithPlaceholder()
          ? _value.detail
          // ignore: cast_nullable_to_non_nullable
          : detail as String,
      severity: severity == const $CopyWithPlaceholder()
          ? _value.severity
          // ignore: cast_nullable_to_non_nullable
          : severity as AssetCodexDetailRisksInnerSeverityEnum,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $AssetCodexDetailRisksInnerCopyWith on AssetCodexDetailRisksInner {
  /// Returns a callable class that can be used as follows: `instanceOfAssetCodexDetailRisksInner.copyWith(...)` or like so:`instanceOfAssetCodexDetailRisksInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetCodexDetailRisksInnerCWProxy get copyWith =>
      _$AssetCodexDetailRisksInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetCodexDetailRisksInner _$AssetCodexDetailRisksInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AssetCodexDetailRisksInner', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['detail', 'severity', 'title']);
  final val = AssetCodexDetailRisksInner(
    detail: $checkedConvert('detail', (v) => v as String),
    severity: $checkedConvert(
      'severity',
      (v) => $enumDecode(
        _$AssetCodexDetailRisksInnerSeverityEnumEnumMap,
        v,
        unknownValue:
            AssetCodexDetailRisksInnerSeverityEnum.unknownDefaultOpenApi,
      ),
    ),
    title: $checkedConvert('title', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$AssetCodexDetailRisksInnerToJson(
  AssetCodexDetailRisksInner instance,
) => <String, dynamic>{
  'detail': instance.detail,
  'severity':
      _$AssetCodexDetailRisksInnerSeverityEnumEnumMap[instance.severity]!,
  'title': instance.title,
};

const _$AssetCodexDetailRisksInnerSeverityEnumEnumMap = {
  AssetCodexDetailRisksInnerSeverityEnum.low: 'low',
  AssetCodexDetailRisksInnerSeverityEnum.medium: 'medium',
  AssetCodexDetailRisksInnerSeverityEnum.high: 'high',
  AssetCodexDetailRisksInnerSeverityEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
