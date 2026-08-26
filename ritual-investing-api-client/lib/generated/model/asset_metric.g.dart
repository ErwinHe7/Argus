// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_metric.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetMetricCWProxy {
  AssetMetric changeBps(int? changeBps);

  AssetMetric demo(DemoDisclosure demo);

  AssetMetric expenseRatioBps(int? expenseRatioBps);

  AssetMetric observedAt(DateTime observedAt);

  AssetMetric priceMinor(int priceMinor);

  AssetMetric sourceLabel(String sourceLabel);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetMetric(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetMetric(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetMetric call({
    int? changeBps,
    DemoDisclosure demo,
    int? expenseRatioBps,
    DateTime observedAt,
    int priceMinor,
    String sourceLabel,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetMetric.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetMetric.copyWith.fieldName(...)`
class _$AssetMetricCWProxyImpl implements _$AssetMetricCWProxy {
  const _$AssetMetricCWProxyImpl(this._value);

  final AssetMetric _value;

  @override
  AssetMetric changeBps(int? changeBps) => this(changeBps: changeBps);

  @override
  AssetMetric demo(DemoDisclosure demo) => this(demo: demo);

  @override
  AssetMetric expenseRatioBps(int? expenseRatioBps) =>
      this(expenseRatioBps: expenseRatioBps);

  @override
  AssetMetric observedAt(DateTime observedAt) => this(observedAt: observedAt);

  @override
  AssetMetric priceMinor(int priceMinor) => this(priceMinor: priceMinor);

  @override
  AssetMetric sourceLabel(String sourceLabel) => this(sourceLabel: sourceLabel);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetMetric(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetMetric(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetMetric call({
    Object? changeBps = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? expenseRatioBps = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? priceMinor = const $CopyWithPlaceholder(),
    Object? sourceLabel = const $CopyWithPlaceholder(),
  }) {
    return AssetMetric(
      changeBps: changeBps == const $CopyWithPlaceholder()
          ? _value.changeBps
          // ignore: cast_nullable_to_non_nullable
          : changeBps as int?,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      expenseRatioBps: expenseRatioBps == const $CopyWithPlaceholder()
          ? _value.expenseRatioBps
          // ignore: cast_nullable_to_non_nullable
          : expenseRatioBps as int?,
      observedAt: observedAt == const $CopyWithPlaceholder()
          ? _value.observedAt
          // ignore: cast_nullable_to_non_nullable
          : observedAt as DateTime,
      priceMinor: priceMinor == const $CopyWithPlaceholder()
          ? _value.priceMinor
          // ignore: cast_nullable_to_non_nullable
          : priceMinor as int,
      sourceLabel: sourceLabel == const $CopyWithPlaceholder()
          ? _value.sourceLabel
          // ignore: cast_nullable_to_non_nullable
          : sourceLabel as String,
    );
  }
}

extension $AssetMetricCopyWith on AssetMetric {
  /// Returns a callable class that can be used as follows: `instanceOfAssetMetric.copyWith(...)` or like so:`instanceOfAssetMetric.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetMetricCWProxy get copyWith => _$AssetMetricCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetMetric _$AssetMetricFromJson(Map<String, dynamic> json) => $checkedCreate(
  'AssetMetric',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'change_bps',
        'demo',
        'expense_ratio_bps',
        'observed_at',
        'price_minor',
        'source_label',
      ],
    );
    final val = AssetMetric(
      changeBps: $checkedConvert('change_bps', (v) => (v as num?)?.toInt()),
      demo: $checkedConvert(
        'demo',
        (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
      ),
      expenseRatioBps: $checkedConvert(
        'expense_ratio_bps',
        (v) => (v as num?)?.toInt(),
      ),
      observedAt: $checkedConvert(
        'observed_at',
        (v) => DateTime.parse(v as String),
      ),
      priceMinor: $checkedConvert('price_minor', (v) => (v as num).toInt()),
      sourceLabel: $checkedConvert('source_label', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'changeBps': 'change_bps',
    'expenseRatioBps': 'expense_ratio_bps',
    'observedAt': 'observed_at',
    'priceMinor': 'price_minor',
    'sourceLabel': 'source_label',
  },
);

Map<String, dynamic> _$AssetMetricToJson(AssetMetric instance) =>
    <String, dynamic>{
      'change_bps': instance.changeBps,
      'demo': instance.demo.toJson(),
      'expense_ratio_bps': instance.expenseRatioBps,
      'observed_at': instance.observedAt.toIso8601String(),
      'price_minor': instance.priceMinor,
      'source_label': instance.sourceLabel,
    };
