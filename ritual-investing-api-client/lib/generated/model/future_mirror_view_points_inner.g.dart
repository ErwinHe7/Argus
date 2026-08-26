// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'future_mirror_view_points_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FutureMirrorViewPointsInnerCWProxy {
  FutureMirrorViewPointsInner date(DateTime date);

  FutureMirrorViewPointsInner high(Money high);

  FutureMirrorViewPointsInner low(Money low);

  FutureMirrorViewPointsInner mid(Money mid);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FutureMirrorViewPointsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FutureMirrorViewPointsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  FutureMirrorViewPointsInner call({
    DateTime date,
    Money high,
    Money low,
    Money mid,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFutureMirrorViewPointsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFutureMirrorViewPointsInner.copyWith.fieldName(...)`
class _$FutureMirrorViewPointsInnerCWProxyImpl
    implements _$FutureMirrorViewPointsInnerCWProxy {
  const _$FutureMirrorViewPointsInnerCWProxyImpl(this._value);

  final FutureMirrorViewPointsInner _value;

  @override
  FutureMirrorViewPointsInner date(DateTime date) => this(date: date);

  @override
  FutureMirrorViewPointsInner high(Money high) => this(high: high);

  @override
  FutureMirrorViewPointsInner low(Money low) => this(low: low);

  @override
  FutureMirrorViewPointsInner mid(Money mid) => this(mid: mid);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FutureMirrorViewPointsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FutureMirrorViewPointsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  FutureMirrorViewPointsInner call({
    Object? date = const $CopyWithPlaceholder(),
    Object? high = const $CopyWithPlaceholder(),
    Object? low = const $CopyWithPlaceholder(),
    Object? mid = const $CopyWithPlaceholder(),
  }) {
    return FutureMirrorViewPointsInner(
      date: date == const $CopyWithPlaceholder()
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as DateTime,
      high: high == const $CopyWithPlaceholder()
          ? _value.high
          // ignore: cast_nullable_to_non_nullable
          : high as Money,
      low: low == const $CopyWithPlaceholder()
          ? _value.low
          // ignore: cast_nullable_to_non_nullable
          : low as Money,
      mid: mid == const $CopyWithPlaceholder()
          ? _value.mid
          // ignore: cast_nullable_to_non_nullable
          : mid as Money,
    );
  }
}

extension $FutureMirrorViewPointsInnerCopyWith on FutureMirrorViewPointsInner {
  /// Returns a callable class that can be used as follows: `instanceOfFutureMirrorViewPointsInner.copyWith(...)` or like so:`instanceOfFutureMirrorViewPointsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FutureMirrorViewPointsInnerCWProxy get copyWith =>
      _$FutureMirrorViewPointsInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FutureMirrorViewPointsInner _$FutureMirrorViewPointsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FutureMirrorViewPointsInner', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['date', 'high', 'low', 'mid']);
  final val = FutureMirrorViewPointsInner(
    date: $checkedConvert('date', (v) => DateTime.parse(v as String)),
    high: $checkedConvert(
      'high',
      (v) => Money.fromJson(v as Map<String, dynamic>),
    ),
    low: $checkedConvert(
      'low',
      (v) => Money.fromJson(v as Map<String, dynamic>),
    ),
    mid: $checkedConvert(
      'mid',
      (v) => Money.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$FutureMirrorViewPointsInnerToJson(
  FutureMirrorViewPointsInner instance,
) => <String, dynamic>{
  'date': instance.date.toIso8601String(),
  'high': instance.high.toJson(),
  'low': instance.low.toJson(),
  'mid': instance.mid.toJson(),
};
