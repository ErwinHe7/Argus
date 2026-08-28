// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hypothetical_future_mirror_annual_return_bps.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HypotheticalFutureMirrorAnnualReturnBpsCWProxy {
  HypotheticalFutureMirrorAnnualReturnBps high(int high);

  HypotheticalFutureMirrorAnnualReturnBps low(int low);

  HypotheticalFutureMirrorAnnualReturnBps mid(int mid);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HypotheticalFutureMirrorAnnualReturnBps(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HypotheticalFutureMirrorAnnualReturnBps(...).copyWith(id: 12, name: "My name")
  /// ````
  HypotheticalFutureMirrorAnnualReturnBps call({int high, int low, int mid});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHypotheticalFutureMirrorAnnualReturnBps.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHypotheticalFutureMirrorAnnualReturnBps.copyWith.fieldName(...)`
class _$HypotheticalFutureMirrorAnnualReturnBpsCWProxyImpl
    implements _$HypotheticalFutureMirrorAnnualReturnBpsCWProxy {
  const _$HypotheticalFutureMirrorAnnualReturnBpsCWProxyImpl(this._value);

  final HypotheticalFutureMirrorAnnualReturnBps _value;

  @override
  HypotheticalFutureMirrorAnnualReturnBps high(int high) => this(high: high);

  @override
  HypotheticalFutureMirrorAnnualReturnBps low(int low) => this(low: low);

  @override
  HypotheticalFutureMirrorAnnualReturnBps mid(int mid) => this(mid: mid);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HypotheticalFutureMirrorAnnualReturnBps(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HypotheticalFutureMirrorAnnualReturnBps(...).copyWith(id: 12, name: "My name")
  /// ````
  HypotheticalFutureMirrorAnnualReturnBps call({
    Object? high = const $CopyWithPlaceholder(),
    Object? low = const $CopyWithPlaceholder(),
    Object? mid = const $CopyWithPlaceholder(),
  }) {
    return HypotheticalFutureMirrorAnnualReturnBps(
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

extension $HypotheticalFutureMirrorAnnualReturnBpsCopyWith
    on HypotheticalFutureMirrorAnnualReturnBps {
  /// Returns a callable class that can be used as follows: `instanceOfHypotheticalFutureMirrorAnnualReturnBps.copyWith(...)` or like so:`instanceOfHypotheticalFutureMirrorAnnualReturnBps.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HypotheticalFutureMirrorAnnualReturnBpsCWProxy get copyWith =>
      _$HypotheticalFutureMirrorAnnualReturnBpsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HypotheticalFutureMirrorAnnualReturnBps
_$HypotheticalFutureMirrorAnnualReturnBpsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HypotheticalFutureMirrorAnnualReturnBps', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['high', 'low', 'mid']);
      final val = HypotheticalFutureMirrorAnnualReturnBps(
        high: $checkedConvert('high', (v) => (v as num).toInt()),
        low: $checkedConvert('low', (v) => (v as num).toInt()),
        mid: $checkedConvert('mid', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$HypotheticalFutureMirrorAnnualReturnBpsToJson(
  HypotheticalFutureMirrorAnnualReturnBps instance,
) => <String, dynamic>{
  'high': instance.high,
  'low': instance.low,
  'mid': instance.mid,
};
