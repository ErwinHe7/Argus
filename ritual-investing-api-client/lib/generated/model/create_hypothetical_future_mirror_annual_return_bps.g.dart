// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_hypothetical_future_mirror_annual_return_bps.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateHypotheticalFutureMirrorAnnualReturnBpsCWProxy {
  CreateHypotheticalFutureMirrorAnnualReturnBps high(int high);

  CreateHypotheticalFutureMirrorAnnualReturnBps low(int low);

  CreateHypotheticalFutureMirrorAnnualReturnBps mid(int mid);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateHypotheticalFutureMirrorAnnualReturnBps(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateHypotheticalFutureMirrorAnnualReturnBps(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateHypotheticalFutureMirrorAnnualReturnBps call({
    int high,
    int low,
    int mid,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateHypotheticalFutureMirrorAnnualReturnBps.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateHypotheticalFutureMirrorAnnualReturnBps.copyWith.fieldName(...)`
class _$CreateHypotheticalFutureMirrorAnnualReturnBpsCWProxyImpl
    implements _$CreateHypotheticalFutureMirrorAnnualReturnBpsCWProxy {
  const _$CreateHypotheticalFutureMirrorAnnualReturnBpsCWProxyImpl(this._value);

  final CreateHypotheticalFutureMirrorAnnualReturnBps _value;

  @override
  CreateHypotheticalFutureMirrorAnnualReturnBps high(int high) =>
      this(high: high);

  @override
  CreateHypotheticalFutureMirrorAnnualReturnBps low(int low) => this(low: low);

  @override
  CreateHypotheticalFutureMirrorAnnualReturnBps mid(int mid) => this(mid: mid);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateHypotheticalFutureMirrorAnnualReturnBps(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateHypotheticalFutureMirrorAnnualReturnBps(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateHypotheticalFutureMirrorAnnualReturnBps call({
    Object? high = const $CopyWithPlaceholder(),
    Object? low = const $CopyWithPlaceholder(),
    Object? mid = const $CopyWithPlaceholder(),
  }) {
    return CreateHypotheticalFutureMirrorAnnualReturnBps(
      high: high == const $CopyWithPlaceholder()
          ? _value.high
          // ignore: cast_nullable_to_non_nullable
          : high as int,
      low: low == const $CopyWithPlaceholder()
          ? _value.low
          // ignore: cast_nullable_to_non_nullable
          : low as int,
      mid: mid == const $CopyWithPlaceholder()
          ? _value.mid
          // ignore: cast_nullable_to_non_nullable
          : mid as int,
    );
  }
}

extension $CreateHypotheticalFutureMirrorAnnualReturnBpsCopyWith
    on CreateHypotheticalFutureMirrorAnnualReturnBps {
  /// Returns a callable class that can be used as follows: `instanceOfCreateHypotheticalFutureMirrorAnnualReturnBps.copyWith(...)` or like so:`instanceOfCreateHypotheticalFutureMirrorAnnualReturnBps.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateHypotheticalFutureMirrorAnnualReturnBpsCWProxy get copyWith =>
      _$CreateHypotheticalFutureMirrorAnnualReturnBpsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateHypotheticalFutureMirrorAnnualReturnBps
_$CreateHypotheticalFutureMirrorAnnualReturnBpsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateHypotheticalFutureMirrorAnnualReturnBps', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['high', 'low', 'mid']);
  final val = CreateHypotheticalFutureMirrorAnnualReturnBps(
    high: $checkedConvert('high', (v) => (v as num).toInt()),
    low: $checkedConvert('low', (v) => (v as num).toInt()),
    mid: $checkedConvert('mid', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$CreateHypotheticalFutureMirrorAnnualReturnBpsToJson(
  CreateHypotheticalFutureMirrorAnnualReturnBps instance,
) => <String, dynamic>{
  'high': instance.high,
  'low': instance.low,
  'mid': instance.mid,
};
