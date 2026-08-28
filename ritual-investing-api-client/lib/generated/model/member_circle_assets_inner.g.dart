// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_circle_assets_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberCircleAssetsInnerCWProxy {
  MemberCircleAssetsInner assetId(String assetId);

  MemberCircleAssetsInner id(String id);

  MemberCircleAssetsInner note(String? note);

  MemberCircleAssetsInner ordinal(int ordinal);

  MemberCircleAssetsInner weightBps(int? weightBps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberCircleAssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberCircleAssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberCircleAssetsInner call({
    String assetId,
    String id,
    String? note,
    int ordinal,
    int? weightBps,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberCircleAssetsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberCircleAssetsInner.copyWith.fieldName(...)`
class _$MemberCircleAssetsInnerCWProxyImpl
    implements _$MemberCircleAssetsInnerCWProxy {
  const _$MemberCircleAssetsInnerCWProxyImpl(this._value);

  final MemberCircleAssetsInner _value;

  @override
  MemberCircleAssetsInner assetId(String assetId) => this(assetId: assetId);

  @override
  MemberCircleAssetsInner id(String id) => this(id: id);

  @override
  MemberCircleAssetsInner note(String? note) => this(note: note);

  @override
  MemberCircleAssetsInner ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  MemberCircleAssetsInner weightBps(int? weightBps) =>
      this(weightBps: weightBps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberCircleAssetsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberCircleAssetsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberCircleAssetsInner call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? weightBps = const $CopyWithPlaceholder(),
  }) {
    return MemberCircleAssetsInner(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
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

extension $MemberCircleAssetsInnerCopyWith on MemberCircleAssetsInner {
  /// Returns a callable class that can be used as follows: `instanceOfMemberCircleAssetsInner.copyWith(...)` or like so:`instanceOfMemberCircleAssetsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberCircleAssetsInnerCWProxy get copyWith =>
      _$MemberCircleAssetsInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberCircleAssetsInner _$MemberCircleAssetsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemberCircleAssetsInner', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['asset_id', 'id', 'note', 'ordinal', 'weight_bps'],
  );
  final val = MemberCircleAssetsInner(
    assetId: $checkedConvert('asset_id', (v) => v as String),
    id: $checkedConvert('id', (v) => v as String),
    note: $checkedConvert('note', (v) => v as String?),
    ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
    weightBps: $checkedConvert('weight_bps', (v) => (v as num?)?.toInt()),
  );
  return val;
}, fieldKeyMap: const {'assetId': 'asset_id', 'weightBps': 'weight_bps'});

Map<String, dynamic> _$MemberCircleAssetsInnerToJson(
  MemberCircleAssetsInner instance,
) => <String, dynamic>{
  'asset_id': instance.assetId,
  'id': instance.id,
  'note': instance.note,
  'ordinal': instance.ordinal,
  'weight_bps': instance.weightBps,
};
