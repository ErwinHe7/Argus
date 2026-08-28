// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_asset_input.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleAssetInputCWProxy {
  CircleAssetInput assetId(String assetId);

  CircleAssetInput note(String? note);

  CircleAssetInput ordinal(int ordinal);

  CircleAssetInput weightBps(int? weightBps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleAssetInput(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleAssetInput(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleAssetInput call({
    String assetId,
    String? note,
    int ordinal,
    int? weightBps,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleAssetInput.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleAssetInput.copyWith.fieldName(...)`
class _$CircleAssetInputCWProxyImpl implements _$CircleAssetInputCWProxy {
  const _$CircleAssetInputCWProxyImpl(this._value);

  final CircleAssetInput _value;

  @override
  CircleAssetInput assetId(String assetId) => this(assetId: assetId);

  @override
  CircleAssetInput note(String? note) => this(note: note);

  @override
  CircleAssetInput ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  CircleAssetInput weightBps(int? weightBps) => this(weightBps: weightBps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleAssetInput(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleAssetInput(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleAssetInput call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? weightBps = const $CopyWithPlaceholder(),
  }) {
    return CircleAssetInput(
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

extension $CircleAssetInputCopyWith on CircleAssetInput {
  /// Returns a callable class that can be used as follows: `instanceOfCircleAssetInput.copyWith(...)` or like so:`instanceOfCircleAssetInput.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleAssetInputCWProxy get copyWith => _$CircleAssetInputCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleAssetInput _$CircleAssetInputFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CircleAssetInput', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['assetId', 'ordinal']);
      final val = CircleAssetInput(
        assetId: $checkedConvert('assetId', (v) => v as String),
        note: $checkedConvert('note', (v) => v as String?),
        ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
        weightBps: $checkedConvert('weightBps', (v) => (v as num?)?.toInt()),
      );
      return val;
    });

Map<String, dynamic> _$CircleAssetInputToJson(CircleAssetInput instance) =>
    <String, dynamic>{
      'assetId': instance.assetId,
      'note': ?instance.note,
      'ordinal': instance.ordinal,
      'weightBps': ?instance.weightBps,
    };
