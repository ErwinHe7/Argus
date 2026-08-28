// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hypothetical_future_mirror_point.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HypotheticalFutureMirrorPointCWProxy {
  HypotheticalFutureMirrorPoint highAmountMinor(String highAmountMinor);

  HypotheticalFutureMirrorPoint lowAmountMinor(String lowAmountMinor);

  HypotheticalFutureMirrorPoint midAmountMinor(String midAmountMinor);

  HypotheticalFutureMirrorPoint ordinal(int ordinal);

  HypotheticalFutureMirrorPoint projectedDate(DateTime projectedDate);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HypotheticalFutureMirrorPoint(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HypotheticalFutureMirrorPoint(...).copyWith(id: 12, name: "My name")
  /// ````
  HypotheticalFutureMirrorPoint call({
    String highAmountMinor,
    String lowAmountMinor,
    String midAmountMinor,
    int ordinal,
    DateTime projectedDate,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHypotheticalFutureMirrorPoint.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHypotheticalFutureMirrorPoint.copyWith.fieldName(...)`
class _$HypotheticalFutureMirrorPointCWProxyImpl
    implements _$HypotheticalFutureMirrorPointCWProxy {
  const _$HypotheticalFutureMirrorPointCWProxyImpl(this._value);

  final HypotheticalFutureMirrorPoint _value;

  @override
  HypotheticalFutureMirrorPoint highAmountMinor(String highAmountMinor) =>
      this(highAmountMinor: highAmountMinor);

  @override
  HypotheticalFutureMirrorPoint lowAmountMinor(String lowAmountMinor) =>
      this(lowAmountMinor: lowAmountMinor);

  @override
  HypotheticalFutureMirrorPoint midAmountMinor(String midAmountMinor) =>
      this(midAmountMinor: midAmountMinor);

  @override
  HypotheticalFutureMirrorPoint ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  HypotheticalFutureMirrorPoint projectedDate(DateTime projectedDate) =>
      this(projectedDate: projectedDate);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HypotheticalFutureMirrorPoint(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HypotheticalFutureMirrorPoint(...).copyWith(id: 12, name: "My name")
  /// ````
  HypotheticalFutureMirrorPoint call({
    Object? highAmountMinor = const $CopyWithPlaceholder(),
    Object? lowAmountMinor = const $CopyWithPlaceholder(),
    Object? midAmountMinor = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? projectedDate = const $CopyWithPlaceholder(),
  }) {
    return HypotheticalFutureMirrorPoint(
      highAmountMinor: highAmountMinor == const $CopyWithPlaceholder()
          ? _value.highAmountMinor
          // ignore: cast_nullable_to_non_nullable
          : highAmountMinor as String,
      lowAmountMinor: lowAmountMinor == const $CopyWithPlaceholder()
          ? _value.lowAmountMinor
          // ignore: cast_nullable_to_non_nullable
          : lowAmountMinor as String,
      midAmountMinor: midAmountMinor == const $CopyWithPlaceholder()
          ? _value.midAmountMinor
          // ignore: cast_nullable_to_non_nullable
          : midAmountMinor as String,
      ordinal: ordinal == const $CopyWithPlaceholder()
          ? _value.ordinal
          // ignore: cast_nullable_to_non_nullable
          : ordinal as int,
      projectedDate: projectedDate == const $CopyWithPlaceholder()
          ? _value.projectedDate
          // ignore: cast_nullable_to_non_nullable
          : projectedDate as DateTime,
    );
  }
}

extension $HypotheticalFutureMirrorPointCopyWith
    on HypotheticalFutureMirrorPoint {
  /// Returns a callable class that can be used as follows: `instanceOfHypotheticalFutureMirrorPoint.copyWith(...)` or like so:`instanceOfHypotheticalFutureMirrorPoint.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HypotheticalFutureMirrorPointCWProxy get copyWith =>
      _$HypotheticalFutureMirrorPointCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HypotheticalFutureMirrorPoint _$HypotheticalFutureMirrorPointFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'HypotheticalFutureMirrorPoint',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'high_amount_minor',
        'low_amount_minor',
        'mid_amount_minor',
        'ordinal',
        'projected_date',
      ],
    );
    final val = HypotheticalFutureMirrorPoint(
      highAmountMinor: $checkedConvert('high_amount_minor', (v) => v as String),
      lowAmountMinor: $checkedConvert('low_amount_minor', (v) => v as String),
      midAmountMinor: $checkedConvert('mid_amount_minor', (v) => v as String),
      ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
      projectedDate: $checkedConvert(
        'projected_date',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'highAmountMinor': 'high_amount_minor',
    'lowAmountMinor': 'low_amount_minor',
    'midAmountMinor': 'mid_amount_minor',
    'projectedDate': 'projected_date',
  },
);

Map<String, dynamic> _$HypotheticalFutureMirrorPointToJson(
  HypotheticalFutureMirrorPoint instance,
) => <String, dynamic>{
  'high_amount_minor': instance.highAmountMinor,
  'low_amount_minor': instance.lowAmountMinor,
  'mid_amount_minor': instance.midAmountMinor,
  'ordinal': instance.ordinal,
  'projected_date': instance.projectedDate.toIso8601String(),
};
