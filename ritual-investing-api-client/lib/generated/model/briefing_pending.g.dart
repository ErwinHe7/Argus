// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'briefing_pending.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BriefingPendingCWProxy {
  BriefingPending localDate(DateTime localDate);

  BriefingPending status(BriefingPendingStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingPending(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingPending(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingPending call({DateTime localDate, BriefingPendingStatusEnum status});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBriefingPending.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBriefingPending.copyWith.fieldName(...)`
class _$BriefingPendingCWProxyImpl implements _$BriefingPendingCWProxy {
  const _$BriefingPendingCWProxyImpl(this._value);

  final BriefingPending _value;

  @override
  BriefingPending localDate(DateTime localDate) => this(localDate: localDate);

  @override
  BriefingPending status(BriefingPendingStatusEnum status) =>
      this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingPending(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingPending(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingPending call({
    Object? localDate = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return BriefingPending(
      localDate: localDate == const $CopyWithPlaceholder()
          ? _value.localDate
          // ignore: cast_nullable_to_non_nullable
          : localDate as DateTime,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as BriefingPendingStatusEnum,
    );
  }
}

extension $BriefingPendingCopyWith on BriefingPending {
  /// Returns a callable class that can be used as follows: `instanceOfBriefingPending.copyWith(...)` or like so:`instanceOfBriefingPending.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BriefingPendingCWProxy get copyWith => _$BriefingPendingCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BriefingPending _$BriefingPendingFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BriefingPending', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['local_date', 'status']);
      final val = BriefingPending(
        localDate: $checkedConvert(
          'local_date',
          (v) => DateTime.parse(v as String),
        ),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$BriefingPendingStatusEnumEnumMap,
            v,
            unknownValue: BriefingPendingStatusEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    }, fieldKeyMap: const {'localDate': 'local_date'});

Map<String, dynamic> _$BriefingPendingToJson(BriefingPending instance) =>
    <String, dynamic>{
      'local_date': instance.localDate.toIso8601String(),
      'status': _$BriefingPendingStatusEnumEnumMap[instance.status]!,
    };

const _$BriefingPendingStatusEnumEnumMap = {
  BriefingPendingStatusEnum.briefingPending: 'briefing_pending',
  BriefingPendingStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
