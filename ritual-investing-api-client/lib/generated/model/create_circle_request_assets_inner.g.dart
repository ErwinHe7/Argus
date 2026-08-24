// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_circle_request_assets_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateCircleRequestAssetsInnerCWProxy {
  CreateCircleRequestAssetsInner assetId(String assetId);

  CreateCircleRequestAssetsInner note(String? note);

  CreateCircleRequestAssetsInner ordinal(int ordinal);

  CreateCircleRequestAssetsInner weightBps(int? weightBps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCircleRequestAssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCircleRequestAssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCircleRequestAssetsInner call({
    String assetId,
    String? note,
    int ordinal,
    int? weightBps,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateCircleRequestAssetsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateCircleRequestAssetsInner.copyWith.fieldName(...)`
class _$CreateCircleRequestAssetsInnerCWProxyImpl
    implements _$CreateCircleRequestAssetsInnerCWProxy {
  const _$CreateCircleRequestAssetsInnerCWProxyImpl(this._value);

  final CreateCircleRequestAssetsInner _value;

  @override
  CreateCircleRequestAssetsInner assetId(String assetId) =>
      this(assetId: assetId);

  @override
  CreateCircleRequestAssetsInner note(String? note) => this(note: note);

  @override
  CreateCircleRequestAssetsInner ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  CreateCircleRequestAssetsInner weightBps(int? weightBps) =>
      this(weightBps: weightBps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCircleRequestAssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCircleRequestAssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCircleRequestAssetsInner call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? weightBps = const $CopyWithPlaceholder(),
  }) {
    return CreateCircleRequestAssetsInner(
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

extension $CreateCircleRequestAssetsInnerCopyWith
    on CreateCircleRequestAssetsInner {
  /// Returns a callable class that can be used as follows: `instanceOfCreateCircleRequestAssetsInner.copyWith(...)` or like so:`instanceOfCreateCircleRequestAssetsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateCircleRequestAssetsInnerCWProxy get copyWith =>
      _$CreateCircleRequestAssetsInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCircleRequestAssetsInner _$CreateCircleRequestAssetsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateCircleRequestAssetsInner', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['asset_id', 'ordinal']);
  final val = CreateCircleRequestAssetsInner(
    assetId: $checkedConvert('asset_id', (v) => v as String),
    note: $checkedConvert('note', (v) => v as String?),
    ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
    weightBps: $checkedConvert('weight_bps', (v) => (v as num?)?.toInt()),
  );
  return val;
}, fieldKeyMap: const {'assetId': 'asset_id', 'weightBps': 'weight_bps'});

Map<String, dynamic> _$CreateCircleRequestAssetsInnerToJson(
  CreateCircleRequestAssetsInner instance,
) => <String, dynamic>{
  'asset_id': instance.assetId,
  'note': ?instance.note,
  'ordinal': instance.ordinal,
  'weight_bps': ?instance.weightBps,
};
