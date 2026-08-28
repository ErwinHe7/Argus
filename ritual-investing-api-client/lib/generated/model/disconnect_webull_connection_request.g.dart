// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'disconnect_webull_connection_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DisconnectWebullConnectionRequestCWProxy {
  DisconnectWebullConnectionRequest stepUpReceipt(String stepUpReceipt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DisconnectWebullConnectionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DisconnectWebullConnectionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DisconnectWebullConnectionRequest call({String stepUpReceipt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDisconnectWebullConnectionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDisconnectWebullConnectionRequest.copyWith.fieldName(...)`
class _$DisconnectWebullConnectionRequestCWProxyImpl
    implements _$DisconnectWebullConnectionRequestCWProxy {
  const _$DisconnectWebullConnectionRequestCWProxyImpl(this._value);

  final DisconnectWebullConnectionRequest _value;

  @override
  DisconnectWebullConnectionRequest stepUpReceipt(String stepUpReceipt) =>
      this(stepUpReceipt: stepUpReceipt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DisconnectWebullConnectionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DisconnectWebullConnectionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DisconnectWebullConnectionRequest call({
    Object? stepUpReceipt = const $CopyWithPlaceholder(),
  }) {
    return DisconnectWebullConnectionRequest(
      stepUpReceipt: stepUpReceipt == const $CopyWithPlaceholder()
          ? _value.stepUpReceipt
          // ignore: cast_nullable_to_non_nullable
          : stepUpReceipt as String,
    );
  }
}

extension $DisconnectWebullConnectionRequestCopyWith
    on DisconnectWebullConnectionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfDisconnectWebullConnectionRequest.copyWith(...)` or like so:`instanceOfDisconnectWebullConnectionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DisconnectWebullConnectionRequestCWProxy get copyWith =>
      _$DisconnectWebullConnectionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DisconnectWebullConnectionRequest _$DisconnectWebullConnectionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DisconnectWebullConnectionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['step_up_receipt']);
  final val = DisconnectWebullConnectionRequest(
    stepUpReceipt: $checkedConvert('step_up_receipt', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'stepUpReceipt': 'step_up_receipt'});

Map<String, dynamic> _$DisconnectWebullConnectionRequestToJson(
  DisconnectWebullConnectionRequest instance,
) => <String, dynamic>{'step_up_receipt': instance.stepUpReceipt};
