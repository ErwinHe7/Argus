// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionResponseDataCWProxy {
  SessionResponseData contractVersion(
    SessionResponseDataContractVersionEnum contractVersion,
  );

  SessionResponseData serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionResponseData call({
    SessionResponseDataContractVersionEnum contractVersion,
    DateTime serverTime,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionResponseData.copyWith.fieldName(...)`
class _$SessionResponseDataCWProxyImpl implements _$SessionResponseDataCWProxy {
  const _$SessionResponseDataCWProxyImpl(this._value);

  final SessionResponseData _value;

  @override
  SessionResponseData contractVersion(
    SessionResponseDataContractVersionEnum contractVersion,
  ) => this(contractVersion: contractVersion);

  @override
  SessionResponseData serverTime(DateTime serverTime) =>
      this(serverTime: serverTime);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionResponseData call({
    Object? contractVersion = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return SessionResponseData(
      contractVersion: contractVersion == const $CopyWithPlaceholder()
          ? _value.contractVersion
          // ignore: cast_nullable_to_non_nullable
          : contractVersion as SessionResponseDataContractVersionEnum,
      serverTime: serverTime == const $CopyWithPlaceholder()
          ? _value.serverTime
          // ignore: cast_nullable_to_non_nullable
          : serverTime as DateTime,
    );
  }
}

extension $SessionResponseDataCopyWith on SessionResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfSessionResponseData.copyWith(...)` or like so:`instanceOfSessionResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionResponseDataCWProxy get copyWith =>
      _$SessionResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionResponseData _$SessionResponseDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SessionResponseData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['contract_version', 'server_time'],
        );
        final val = SessionResponseData(
          contractVersion: $checkedConvert(
            'contract_version',
            (v) => $enumDecode(
              _$SessionResponseDataContractVersionEnumEnumMap,
              v,
              unknownValue:
                  SessionResponseDataContractVersionEnum.unknownDefaultOpenApi,
            ),
          ),
          serverTime: $checkedConvert(
            'server_time',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'contractVersion': 'contract_version',
        'serverTime': 'server_time',
      },
    );

Map<String, dynamic> _$SessionResponseDataToJson(
  SessionResponseData instance,
) => <String, dynamic>{
  'contract_version':
      _$SessionResponseDataContractVersionEnumEnumMap[instance
          .contractVersion]!,
  'server_time': instance.serverTime.toIso8601String(),
};

const _$SessionResponseDataContractVersionEnumEnumMap = {
  SessionResponseDataContractVersionEnum.n1period0Period0: '1.0.0',
  SessionResponseDataContractVersionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
