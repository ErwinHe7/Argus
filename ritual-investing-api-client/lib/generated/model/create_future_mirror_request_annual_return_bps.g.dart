// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_future_mirror_request_annual_return_bps.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateFutureMirrorRequestAnnualReturnBpsCWProxy {
  CreateFutureMirrorRequestAnnualReturnBps high(int high);

  CreateFutureMirrorRequestAnnualReturnBps low(int low);

  CreateFutureMirrorRequestAnnualReturnBps mid(int mid);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateFutureMirrorRequestAnnualReturnBps(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateFutureMirrorRequestAnnualReturnBps(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateFutureMirrorRequestAnnualReturnBps call({int high, int low, int mid});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateFutureMirrorRequestAnnualReturnBps.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateFutureMirrorRequestAnnualReturnBps.copyWith.fieldName(...)`
class _$CreateFutureMirrorRequestAnnualReturnBpsCWProxyImpl
    implements _$CreateFutureMirrorRequestAnnualReturnBpsCWProxy {
  const _$CreateFutureMirrorRequestAnnualReturnBpsCWProxyImpl(this._value);

  final CreateFutureMirrorRequestAnnualReturnBps _value;

  @override
  CreateFutureMirrorRequestAnnualReturnBps high(int high) => this(high: high);

  @override
  CreateFutureMirrorRequestAnnualReturnBps low(int low) => this(low: low);

  @override
  CreateFutureMirrorRequestAnnualReturnBps mid(int mid) => this(mid: mid);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateFutureMirrorRequestAnnualReturnBps(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateFutureMirrorRequestAnnualReturnBps(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateFutureMirrorRequestAnnualReturnBps call({
    Object? high = const $CopyWithPlaceholder(),
    Object? low = const $CopyWithPlaceholder(),
    Object? mid = const $CopyWithPlaceholder(),
  }) {
    return CreateFutureMirrorRequestAnnualReturnBps(
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

extension $CreateFutureMirrorRequestAnnualReturnBpsCopyWith
    on CreateFutureMirrorRequestAnnualReturnBps {
  /// Returns a callable class that can be used as follows: `instanceOfCreateFutureMirrorRequestAnnualReturnBps.copyWith(...)` or like so:`instanceOfCreateFutureMirrorRequestAnnualReturnBps.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateFutureMirrorRequestAnnualReturnBpsCWProxy get copyWith =>
      _$CreateFutureMirrorRequestAnnualReturnBpsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateFutureMirrorRequestAnnualReturnBps
_$CreateFutureMirrorRequestAnnualReturnBpsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateFutureMirrorRequestAnnualReturnBps', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['high', 'low', 'mid']);
      final val = CreateFutureMirrorRequestAnnualReturnBps(
        high: $checkedConvert('high', (v) => (v as num).toInt()),
        low: $checkedConvert('low', (v) => (v as num).toInt()),
        mid: $checkedConvert('mid', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$CreateFutureMirrorRequestAnnualReturnBpsToJson(
  CreateFutureMirrorRequestAnnualReturnBps instance,
) => <String, dynamic>{
  'high': instance.high,
  'low': instance.low,
  'mid': instance.mid,
};
