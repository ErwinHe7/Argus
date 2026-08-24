// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_daily_briefing202_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetDailyBriefing202ResponseDataCWProxy {
  GetDailyBriefing202ResponseData localDate(DateTime localDate);

  GetDailyBriefing202ResponseData status(
    GetDailyBriefing202ResponseDataStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetDailyBriefing202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetDailyBriefing202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  GetDailyBriefing202ResponseData call({
    DateTime localDate,
    GetDailyBriefing202ResponseDataStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetDailyBriefing202ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetDailyBriefing202ResponseData.copyWith.fieldName(...)`
class _$GetDailyBriefing202ResponseDataCWProxyImpl
    implements _$GetDailyBriefing202ResponseDataCWProxy {
  const _$GetDailyBriefing202ResponseDataCWProxyImpl(this._value);

  final GetDailyBriefing202ResponseData _value;

  @override
  GetDailyBriefing202ResponseData localDate(DateTime localDate) =>
      this(localDate: localDate);

  @override
  GetDailyBriefing202ResponseData status(
    GetDailyBriefing202ResponseDataStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetDailyBriefing202ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetDailyBriefing202ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  GetDailyBriefing202ResponseData call({
    Object? localDate = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return GetDailyBriefing202ResponseData(
      localDate: localDate == const $CopyWithPlaceholder()
          ? _value.localDate
          // ignore: cast_nullable_to_non_nullable
          : localDate as DateTime,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as GetDailyBriefing202ResponseDataStatusEnum,
    );
  }
}

extension $GetDailyBriefing202ResponseDataCopyWith
    on GetDailyBriefing202ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfGetDailyBriefing202ResponseData.copyWith(...)` or like so:`instanceOfGetDailyBriefing202ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetDailyBriefing202ResponseDataCWProxy get copyWith =>
      _$GetDailyBriefing202ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetDailyBriefing202ResponseData _$GetDailyBriefing202ResponseDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetDailyBriefing202ResponseData', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['local_date', 'status']);
  final val = GetDailyBriefing202ResponseData(
    localDate: $checkedConvert(
      'local_date',
      (v) => DateTime.parse(v as String),
    ),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$GetDailyBriefing202ResponseDataStatusEnumEnumMap,
        v,
        unknownValue:
            GetDailyBriefing202ResponseDataStatusEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'localDate': 'local_date'});

Map<String, dynamic> _$GetDailyBriefing202ResponseDataToJson(
  GetDailyBriefing202ResponseData instance,
) => <String, dynamic>{
  'local_date': instance.localDate.toIso8601String(),
  'status':
      _$GetDailyBriefing202ResponseDataStatusEnumEnumMap[instance.status]!,
};

const _$GetDailyBriefing202ResponseDataStatusEnumEnumMap = {
  GetDailyBriefing202ResponseDataStatusEnum.briefingPending: 'briefing_pending',
  GetDailyBriefing202ResponseDataStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
