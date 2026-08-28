// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_circle_asset_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PutCircleAssetRequestCWProxy {
  PutCircleAssetRequest note(String? note);

  PutCircleAssetRequest ordinal(int ordinal);

  PutCircleAssetRequest weightBps(int? weightBps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutCircleAssetRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutCircleAssetRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PutCircleAssetRequest call({String? note, int ordinal, int? weightBps});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPutCircleAssetRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPutCircleAssetRequest.copyWith.fieldName(...)`
class _$PutCircleAssetRequestCWProxyImpl
    implements _$PutCircleAssetRequestCWProxy {
  const _$PutCircleAssetRequestCWProxyImpl(this._value);

  final PutCircleAssetRequest _value;

  @override
  PutCircleAssetRequest note(String? note) => this(note: note);

  @override
  PutCircleAssetRequest ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  PutCircleAssetRequest weightBps(int? weightBps) => this(weightBps: weightBps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutCircleAssetRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutCircleAssetRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PutCircleAssetRequest call({
    Object? note = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? weightBps = const $CopyWithPlaceholder(),
  }) {
    return PutCircleAssetRequest(
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

extension $PutCircleAssetRequestCopyWith on PutCircleAssetRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPutCircleAssetRequest.copyWith(...)` or like so:`instanceOfPutCircleAssetRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PutCircleAssetRequestCWProxy get copyWith =>
      _$PutCircleAssetRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutCircleAssetRequest _$PutCircleAssetRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PutCircleAssetRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['ordinal']);
  final val = PutCircleAssetRequest(
    note: $checkedConvert('note', (v) => v as String?),
    ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
    weightBps: $checkedConvert('weightBps', (v) => (v as num?)?.toInt()),
  );
  return val;
});

Map<String, dynamic> _$PutCircleAssetRequestToJson(
  PutCircleAssetRequest instance,
) => <String, dynamic>{
  'note': ?instance.note,
  'ordinal': instance.ordinal,
  'weightBps': ?instance.weightBps,
};
