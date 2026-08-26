// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_asset_metric_snapshot_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminAssetMetricSnapshotRequestCWProxy {
  CreateAdminAssetMetricSnapshotRequest changeBps(int? changeBps);

  CreateAdminAssetMetricSnapshotRequest expenseRatioBps(int? expenseRatioBps);

  CreateAdminAssetMetricSnapshotRequest observedAt(DateTime observedAt);

  CreateAdminAssetMetricSnapshotRequest priceMinor(int priceMinor);

  CreateAdminAssetMetricSnapshotRequest sourceLabel(String sourceLabel);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAssetMetricSnapshotRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAssetMetricSnapshotRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAssetMetricSnapshotRequest call({
    int? changeBps,
    int? expenseRatioBps,
    DateTime observedAt,
    int priceMinor,
    String sourceLabel,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminAssetMetricSnapshotRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminAssetMetricSnapshotRequest.copyWith.fieldName(...)`
class _$CreateAdminAssetMetricSnapshotRequestCWProxyImpl
    implements _$CreateAdminAssetMetricSnapshotRequestCWProxy {
  const _$CreateAdminAssetMetricSnapshotRequestCWProxyImpl(this._value);

  final CreateAdminAssetMetricSnapshotRequest _value;

  @override
  CreateAdminAssetMetricSnapshotRequest changeBps(int? changeBps) =>
      this(changeBps: changeBps);

  @override
  CreateAdminAssetMetricSnapshotRequest expenseRatioBps(int? expenseRatioBps) =>
      this(expenseRatioBps: expenseRatioBps);

  @override
  CreateAdminAssetMetricSnapshotRequest observedAt(DateTime observedAt) =>
      this(observedAt: observedAt);

  @override
  CreateAdminAssetMetricSnapshotRequest priceMinor(int priceMinor) =>
      this(priceMinor: priceMinor);

  @override
  CreateAdminAssetMetricSnapshotRequest sourceLabel(String sourceLabel) =>
      this(sourceLabel: sourceLabel);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAssetMetricSnapshotRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAssetMetricSnapshotRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAssetMetricSnapshotRequest call({
    Object? changeBps = const $CopyWithPlaceholder(),
    Object? expenseRatioBps = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? priceMinor = const $CopyWithPlaceholder(),
    Object? sourceLabel = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminAssetMetricSnapshotRequest(
      changeBps: changeBps == const $CopyWithPlaceholder()
          ? _value.changeBps
          // ignore: cast_nullable_to_non_nullable
          : changeBps as int?,
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

extension $CreateAdminAssetMetricSnapshotRequestCopyWith
    on CreateAdminAssetMetricSnapshotRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminAssetMetricSnapshotRequest.copyWith(...)` or like so:`instanceOfCreateAdminAssetMetricSnapshotRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminAssetMetricSnapshotRequestCWProxy get copyWith =>
      _$CreateAdminAssetMetricSnapshotRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminAssetMetricSnapshotRequest
_$CreateAdminAssetMetricSnapshotRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CreateAdminAssetMetricSnapshotRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'change_bps',
            'expense_ratio_bps',
            'observed_at',
            'price_minor',
            'source_label',
          ],
        );
        final val = CreateAdminAssetMetricSnapshotRequest(
          changeBps: $checkedConvert('change_bps', (v) => (v as num?)?.toInt()),
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

Map<String, dynamic> _$CreateAdminAssetMetricSnapshotRequestToJson(
  CreateAdminAssetMetricSnapshotRequest instance,
) => <String, dynamic>{
  'change_bps': instance.changeBps,
  'expense_ratio_bps': instance.expenseRatioBps,
  'observed_at': instance.observedAt.toIso8601String(),
  'price_minor': instance.priceMinor,
  'source_label': instance.sourceLabel,
};
