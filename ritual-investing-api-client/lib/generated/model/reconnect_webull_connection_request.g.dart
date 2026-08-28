// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconnect_webull_connection_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReconnectWebullConnectionRequestCWProxy {
  ReconnectWebullConnectionRequest returnTarget(
    ReconnectWebullConnectionRequestReturnTargetEnum returnTarget,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReconnectWebullConnectionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReconnectWebullConnectionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReconnectWebullConnectionRequest call({
    ReconnectWebullConnectionRequestReturnTargetEnum returnTarget,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReconnectWebullConnectionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReconnectWebullConnectionRequest.copyWith.fieldName(...)`
class _$ReconnectWebullConnectionRequestCWProxyImpl
    implements _$ReconnectWebullConnectionRequestCWProxy {
  const _$ReconnectWebullConnectionRequestCWProxyImpl(this._value);

  final ReconnectWebullConnectionRequest _value;

  @override
  ReconnectWebullConnectionRequest returnTarget(
    ReconnectWebullConnectionRequestReturnTargetEnum returnTarget,
  ) => this(returnTarget: returnTarget);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReconnectWebullConnectionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReconnectWebullConnectionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReconnectWebullConnectionRequest call({
    Object? returnTarget = const $CopyWithPlaceholder(),
  }) {
    return ReconnectWebullConnectionRequest(
      returnTarget: returnTarget == const $CopyWithPlaceholder()
          ? _value.returnTarget
          // ignore: cast_nullable_to_non_nullable
          : returnTarget as ReconnectWebullConnectionRequestReturnTargetEnum,
    );
  }
}

extension $ReconnectWebullConnectionRequestCopyWith
    on ReconnectWebullConnectionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfReconnectWebullConnectionRequest.copyWith(...)` or like so:`instanceOfReconnectWebullConnectionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReconnectWebullConnectionRequestCWProxy get copyWith =>
      _$ReconnectWebullConnectionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReconnectWebullConnectionRequest _$ReconnectWebullConnectionRequestFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('ReconnectWebullConnectionRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['return_target']);
      final val = ReconnectWebullConnectionRequest(
        returnTarget: $checkedConvert(
          'return_target',
          (v) => $enumDecode(
            _$ReconnectWebullConnectionRequestReturnTargetEnumEnumMap,
            v,
            unknownValue: ReconnectWebullConnectionRequestReturnTargetEnum
                .unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    }, fieldKeyMap: const {'returnTarget': 'return_target'});

Map<String, dynamic> _$ReconnectWebullConnectionRequestToJson(
  ReconnectWebullConnectionRequest instance,
) => <String, dynamic>{
  'return_target':
      _$ReconnectWebullConnectionRequestReturnTargetEnumEnumMap[instance
          .returnTarget]!,
};

const _$ReconnectWebullConnectionRequestReturnTargetEnumEnumMap = {
  ReconnectWebullConnectionRequestReturnTargetEnum.webullHttps: 'webull_https',
  ReconnectWebullConnectionRequestReturnTargetEnum.webullNative:
      'webull_native',
  ReconnectWebullConnectionRequestReturnTargetEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
