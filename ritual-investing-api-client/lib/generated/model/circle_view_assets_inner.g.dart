// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_view_assets_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleViewAssetsInnerCWProxy {
  CircleViewAssetsInner assetId(String assetId);

  CircleViewAssetsInner note(String? note);

  CircleViewAssetsInner ordinal(int ordinal);

  CircleViewAssetsInner weightBps(int? weightBps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleViewAssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleViewAssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleViewAssetsInner call({
    String assetId,
    String? note,
    int ordinal,
    int? weightBps,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleViewAssetsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleViewAssetsInner.copyWith.fieldName(...)`
class _$CircleViewAssetsInnerCWProxyImpl
    implements _$CircleViewAssetsInnerCWProxy {
  const _$CircleViewAssetsInnerCWProxyImpl(this._value);

  final CircleViewAssetsInner _value;

  @override
  CircleViewAssetsInner assetId(String assetId) => this(assetId: assetId);

  @override
  CircleViewAssetsInner note(String? note) => this(note: note);

  @override
  CircleViewAssetsInner ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  CircleViewAssetsInner weightBps(int? weightBps) => this(weightBps: weightBps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleViewAssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleViewAssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleViewAssetsInner call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? weightBps = const $CopyWithPlaceholder(),
  }) {
    return CircleViewAssetsInner(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String?,
      ordinal: ordinal == const $CopyWithPlaceholder()
          ? _value.ordinal
          // ignore: cast_nullable_to_non_nullable
          : ordinal as int,
      weightBps: weightBps == const $CopyWithPlaceholder()
          ? _value.weightBps
          // ignore: cast_nullable_to_non_nullable
          : weightBps as int?,
    );
  }
}

extension $CircleViewAssetsInnerCopyWith on CircleViewAssetsInner {
  /// Returns a callable class that can be used as follows: `instanceOfCircleViewAssetsInner.copyWith(...)` or like so:`instanceOfCircleViewAssetsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleViewAssetsInnerCWProxy get copyWith =>
      _$CircleViewAssetsInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleViewAssetsInner _$CircleViewAssetsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CircleViewAssetsInner', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['asset_id', 'note', 'ordinal', 'weight_bps'],
  );
  final val = CircleViewAssetsInner(
    assetId: $checkedConvert('asset_id', (v) => v as String),
    note: $checkedConvert('note', (v) => v as String?),
    ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
    weightBps: $checkedConvert('weight_bps', (v) => (v as num?)?.toInt()),
  );
  return val;
}, fieldKeyMap: const {'assetId': 'asset_id', 'weightBps': 'weight_bps'});

Map<String, dynamic> _$CircleViewAssetsInnerToJson(
  CircleViewAssetsInner instance,
) => <String, dynamic>{
  'asset_id': instance.assetId,
  'note': instance.note,
  'ordinal': instance.ordinal,
  'weight_bps': instance.weightBps,
};
