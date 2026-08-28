// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_connection.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullConnectionCWProxy {
  WebullConnection authorizedAt(DateTime? authorizedAt);

  WebullConnection capabilityVersion(int? capabilityVersion);

  WebullConnection disconnectedAt(DateTime? disconnectedAt);

  WebullConnection id(String? id);

  WebullConnection lastErrorCode(String? lastErrorCode);

  WebullConnection status(WebullConnectionStatusEnum status);

  WebullConnection updatedAt(DateTime? updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullConnection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullConnection(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullConnection call({
    DateTime? authorizedAt,
    int? capabilityVersion,
    DateTime? disconnectedAt,
    String? id,
    String? lastErrorCode,
    WebullConnectionStatusEnum status,
    DateTime? updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullConnection.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullConnection.copyWith.fieldName(...)`
class _$WebullConnectionCWProxyImpl implements _$WebullConnectionCWProxy {
  const _$WebullConnectionCWProxyImpl(this._value);

  final WebullConnection _value;

  @override
  WebullConnection authorizedAt(DateTime? authorizedAt) =>
      this(authorizedAt: authorizedAt);

  @override
  WebullConnection capabilityVersion(int? capabilityVersion) =>
      this(capabilityVersion: capabilityVersion);

  @override
  WebullConnection disconnectedAt(DateTime? disconnectedAt) =>
      this(disconnectedAt: disconnectedAt);

  @override
  WebullConnection id(String? id) => this(id: id);

  @override
  WebullConnection lastErrorCode(String? lastErrorCode) =>
      this(lastErrorCode: lastErrorCode);

  @override
  WebullConnection status(WebullConnectionStatusEnum status) =>
      this(status: status);

  @override
  WebullConnection updatedAt(DateTime? updatedAt) => this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullConnection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullConnection(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullConnection call({
    Object? authorizedAt = const $CopyWithPlaceholder(),
    Object? capabilityVersion = const $CopyWithPlaceholder(),
    Object? disconnectedAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? lastErrorCode = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return WebullConnection(
      authorizedAt: authorizedAt == const $CopyWithPlaceholder()
          ? _value.authorizedAt
          // ignore: cast_nullable_to_non_nullable
          : authorizedAt as DateTime?,
      capabilityVersion: capabilityVersion == const $CopyWithPlaceholder()
          ? _value.capabilityVersion
          // ignore: cast_nullable_to_non_nullable
          : capabilityVersion as int?,
      disconnectedAt: disconnectedAt == const $CopyWithPlaceholder()
          ? _value.disconnectedAt
          // ignore: cast_nullable_to_non_nullable
          : disconnectedAt as DateTime?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String?,
      lastErrorCode: lastErrorCode == const $CopyWithPlaceholder()
          ? _value.lastErrorCode
          // ignore: cast_nullable_to_non_nullable
          : lastErrorCode as String?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as WebullConnectionStatusEnum,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime?,
    );
  }
}

extension $WebullConnectionCopyWith on WebullConnection {
  /// Returns a callable class that can be used as follows: `instanceOfWebullConnection.copyWith(...)` or like so:`instanceOfWebullConnection.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullConnectionCWProxy get copyWith => _$WebullConnectionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullConnection _$WebullConnectionFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WebullConnection',
      json,
      ($checkedConvert) {
        $checkKeys(json, requiredKeys: const ['status']);
        final val = WebullConnection(
          authorizedAt: $checkedConvert(
            'authorized_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          capabilityVersion: $checkedConvert(
            'capability_version',
            (v) => (v as num?)?.toInt(),
          ),
          disconnectedAt: $checkedConvert(
            'disconnected_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          id: $checkedConvert('id', (v) => v as String?),
          lastErrorCode: $checkedConvert(
            'last_error_code',
            (v) => v as String?,
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$WebullConnectionStatusEnumEnumMap,
              v,
              unknownValue: WebullConnectionStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'authorizedAt': 'authorized_at',
        'capabilityVersion': 'capability_version',
        'disconnectedAt': 'disconnected_at',
        'lastErrorCode': 'last_error_code',
        'updatedAt': 'updated_at',
      },
    );

Map<String, dynamic> _$WebullConnectionToJson(WebullConnection instance) =>
    <String, dynamic>{
      'authorized_at': ?instance.authorizedAt?.toIso8601String(),
      'capability_version': ?instance.capabilityVersion,
      'disconnected_at': ?instance.disconnectedAt?.toIso8601String(),
      'id': ?instance.id,
      'last_error_code': ?instance.lastErrorCode,
      'status': _$WebullConnectionStatusEnumEnumMap[instance.status]!,
      'updated_at': ?instance.updatedAt?.toIso8601String(),
    };

const _$WebullConnectionStatusEnumEnumMap = {
  WebullConnectionStatusEnum.disconnected: 'disconnected',
  WebullConnectionStatusEnum.pending: 'pending',
  WebullConnectionStatusEnum.connected: 'connected',
  WebullConnectionStatusEnum.denied: 'denied',
  WebullConnectionStatusEnum.failed: 'failed',
  WebullConnectionStatusEnum.temporarilyUnavailable: 'temporarily_unavailable',
  WebullConnectionStatusEnum.reauthorizationRequired:
      'reauthorization_required',
  WebullConnectionStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
