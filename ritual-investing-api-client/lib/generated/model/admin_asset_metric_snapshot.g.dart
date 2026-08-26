// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_asset_metric_snapshot.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminAssetMetricSnapshotCWProxy {
  AdminAssetMetricSnapshot assetId(String assetId);

  AdminAssetMetricSnapshot changeBps(int? changeBps);

  AdminAssetMetricSnapshot expenseRatioBps(int? expenseRatioBps);

  AdminAssetMetricSnapshot id(String id);

  AdminAssetMetricSnapshot isDemo(bool isDemo);

  AdminAssetMetricSnapshot observedAt(DateTime observedAt);

  AdminAssetMetricSnapshot priceMinor(int priceMinor);

  AdminAssetMetricSnapshot sourceLabel(String sourceLabel);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminAssetMetricSnapshot(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminAssetMetricSnapshot(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminAssetMetricSnapshot call({
    String assetId,
    int? changeBps,
    int? expenseRatioBps,
    String id,
    bool isDemo,
    DateTime observedAt,
    int priceMinor,
    String sourceLabel,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminAssetMetricSnapshot.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminAssetMetricSnapshot.copyWith.fieldName(...)`
class _$AdminAssetMetricSnapshotCWProxyImpl
    implements _$AdminAssetMetricSnapshotCWProxy {
  const _$AdminAssetMetricSnapshotCWProxyImpl(this._value);

  final AdminAssetMetricSnapshot _value;

  @override
  AdminAssetMetricSnapshot assetId(String assetId) => this(assetId: assetId);

  @override
  AdminAssetMetricSnapshot changeBps(int? changeBps) =>
      this(changeBps: changeBps);

  @override
  AdminAssetMetricSnapshot expenseRatioBps(int? expenseRatioBps) =>
      this(expenseRatioBps: expenseRatioBps);

  @override
  AdminAssetMetricSnapshot id(String id) => this(id: id);

  @override
  AdminAssetMetricSnapshot isDemo(bool isDemo) => this(isDemo: isDemo);

  @override
  AdminAssetMetricSnapshot observedAt(DateTime observedAt) =>
      this(observedAt: observedAt);

  @override
  AdminAssetMetricSnapshot priceMinor(int priceMinor) =>
      this(priceMinor: priceMinor);

  @override
  AdminAssetMetricSnapshot sourceLabel(String sourceLabel) =>
      this(sourceLabel: sourceLabel);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminAssetMetricSnapshot(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminAssetMetricSnapshot(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminAssetMetricSnapshot call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? changeBps = const $CopyWithPlaceholder(),
    Object? expenseRatioBps = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? isDemo = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? priceMinor = const $CopyWithPlaceholder(),
    Object? sourceLabel = const $CopyWithPlaceholder(),
  }) {
    return AdminAssetMetricSnapshot(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      changeBps: changeBps == const $CopyWithPlaceholder()
          ? _value.changeBps
          // ignore: cast_nullable_to_non_nullable
          : changeBps as int?,
      expenseRatioBps: expenseRatioBps == const $CopyWithPlaceholder()
          ? _value.expenseRatioBps
          // ignore: cast_nullable_to_non_nullable
          : expenseRatioBps as int?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      isDemo: isDemo == const $CopyWithPlaceholder()
          ? _value.isDemo
          // ignore: cast_nullable_to_non_nullable
          : isDemo as bool,
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

extension $AdminAssetMetricSnapshotCopyWith on AdminAssetMetricSnapshot {
  /// Returns a callable class that can be used as follows: `instanceOfAdminAssetMetricSnapshot.copyWith(...)` or like so:`instanceOfAdminAssetMetricSnapshot.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminAssetMetricSnapshotCWProxy get copyWith =>
      _$AdminAssetMetricSnapshotCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminAssetMetricSnapshot _$AdminAssetMetricSnapshotFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'AdminAssetMetricSnapshot',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'asset_id',
        'change_bps',
        'expense_ratio_bps',
        'id',
        'is_demo',
        'observed_at',
        'price_minor',
        'source_label',
      ],
    );
    final val = AdminAssetMetricSnapshot(
      assetId: $checkedConvert('asset_id', (v) => v as String),
      changeBps: $checkedConvert('change_bps', (v) => (v as num?)?.toInt()),
      expenseRatioBps: $checkedConvert(
        'expense_ratio_bps',
        (v) => (v as num?)?.toInt(),
      ),
      id: $checkedConvert('id', (v) => v as String),
      isDemo: $checkedConvert('is_demo', (v) => v as bool),
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
    'assetId': 'asset_id',
    'changeBps': 'change_bps',
    'expenseRatioBps': 'expense_ratio_bps',
    'isDemo': 'is_demo',
    'observedAt': 'observed_at',
    'priceMinor': 'price_minor',
    'sourceLabel': 'source_label',
  },
);

Map<String, dynamic> _$AdminAssetMetricSnapshotToJson(
  AdminAssetMetricSnapshot instance,
) => <String, dynamic>{
  'asset_id': instance.assetId,
  'change_bps': instance.changeBps,
  'expense_ratio_bps': instance.expenseRatioBps,
  'id': instance.id,
  'is_demo': instance.isDemo,
  'observed_at': instance.observedAt.toIso8601String(),
  'price_minor': instance.priceMinor,
  'source_label': instance.sourceLabel,
};
