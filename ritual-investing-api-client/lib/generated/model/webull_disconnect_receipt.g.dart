// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_disconnect_receipt.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullDisconnectReceiptCWProxy {
  WebullDisconnectReceipt connectionId(String connectionId);

  WebullDisconnectReceipt providerGrantRevoked(bool providerGrantRevoked);

  WebullDisconnectReceipt status(WebullDisconnectReceiptStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullDisconnectReceipt(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullDisconnectReceipt(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullDisconnectReceipt call({
    String connectionId,
    bool providerGrantRevoked,
    WebullDisconnectReceiptStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullDisconnectReceipt.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullDisconnectReceipt.copyWith.fieldName(...)`
class _$WebullDisconnectReceiptCWProxyImpl
    implements _$WebullDisconnectReceiptCWProxy {
  const _$WebullDisconnectReceiptCWProxyImpl(this._value);

  final WebullDisconnectReceipt _value;

  @override
  WebullDisconnectReceipt connectionId(String connectionId) =>
      this(connectionId: connectionId);

  @override
  WebullDisconnectReceipt providerGrantRevoked(bool providerGrantRevoked) =>
      this(providerGrantRevoked: providerGrantRevoked);

  @override
  WebullDisconnectReceipt status(WebullDisconnectReceiptStatusEnum status) =>
      this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullDisconnectReceipt(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullDisconnectReceipt(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullDisconnectReceipt call({
    Object? connectionId = const $CopyWithPlaceholder(),
    Object? providerGrantRevoked = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return WebullDisconnectReceipt(
      connectionId: connectionId == const $CopyWithPlaceholder()
          ? _value.connectionId
          // ignore: cast_nullable_to_non_nullable
          : connectionId as String,
      providerGrantRevoked: providerGrantRevoked == const $CopyWithPlaceholder()
          ? _value.providerGrantRevoked
          // ignore: cast_nullable_to_non_nullable
          : providerGrantRevoked as bool,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as WebullDisconnectReceiptStatusEnum,
    );
  }
}

extension $WebullDisconnectReceiptCopyWith on WebullDisconnectReceipt {
  /// Returns a callable class that can be used as follows: `instanceOfWebullDisconnectReceipt.copyWith(...)` or like so:`instanceOfWebullDisconnectReceipt.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullDisconnectReceiptCWProxy get copyWith =>
      _$WebullDisconnectReceiptCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullDisconnectReceipt _$WebullDisconnectReceiptFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'WebullDisconnectReceipt',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['connection_id', 'provider_grant_revoked', 'status'],
    );
    final val = WebullDisconnectReceipt(
      connectionId: $checkedConvert('connection_id', (v) => v as String),
      providerGrantRevoked: $checkedConvert(
        'provider_grant_revoked',
        (v) => v as bool,
      ),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$WebullDisconnectReceiptStatusEnumEnumMap,
          v,
          unknownValue: WebullDisconnectReceiptStatusEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'connectionId': 'connection_id',
    'providerGrantRevoked': 'provider_grant_revoked',
  },
);

Map<String, dynamic> _$WebullDisconnectReceiptToJson(
  WebullDisconnectReceipt instance,
) => <String, dynamic>{
  'connection_id': instance.connectionId,
  'provider_grant_revoked': instance.providerGrantRevoked,
  'status': _$WebullDisconnectReceiptStatusEnumEnumMap[instance.status]!,
};

const _$WebullDisconnectReceiptStatusEnumEnumMap = {
  WebullDisconnectReceiptStatusEnum.disconnected: 'disconnected',
  WebullDisconnectReceiptStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
