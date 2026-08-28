// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_authorization_session.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullAuthorizationSessionCWProxy {
  WebullAuthorizationSession authorizationUrl(String authorizationUrl);

  WebullAuthorizationSession connectionId(String connectionId);

  WebullAuthorizationSession expiresAt(DateTime expiresAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullAuthorizationSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullAuthorizationSession(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullAuthorizationSession call({
    String authorizationUrl,
    String connectionId,
    DateTime expiresAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullAuthorizationSession.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullAuthorizationSession.copyWith.fieldName(...)`
class _$WebullAuthorizationSessionCWProxyImpl
    implements _$WebullAuthorizationSessionCWProxy {
  const _$WebullAuthorizationSessionCWProxyImpl(this._value);

  final WebullAuthorizationSession _value;

  @override
  WebullAuthorizationSession authorizationUrl(String authorizationUrl) =>
      this(authorizationUrl: authorizationUrl);

  @override
  WebullAuthorizationSession connectionId(String connectionId) =>
      this(connectionId: connectionId);

  @override
  WebullAuthorizationSession expiresAt(DateTime expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullAuthorizationSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullAuthorizationSession(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullAuthorizationSession call({
    Object? authorizationUrl = const $CopyWithPlaceholder(),
    Object? connectionId = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
  }) {
    return WebullAuthorizationSession(
      authorizationUrl: authorizationUrl == const $CopyWithPlaceholder()
          ? _value.authorizationUrl
          // ignore: cast_nullable_to_non_nullable
          : authorizationUrl as String,
      connectionId: connectionId == const $CopyWithPlaceholder()
          ? _value.connectionId
          // ignore: cast_nullable_to_non_nullable
          : connectionId as String,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
    );
  }
}

extension $WebullAuthorizationSessionCopyWith on WebullAuthorizationSession {
  /// Returns a callable class that can be used as follows: `instanceOfWebullAuthorizationSession.copyWith(...)` or like so:`instanceOfWebullAuthorizationSession.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullAuthorizationSessionCWProxy get copyWith =>
      _$WebullAuthorizationSessionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullAuthorizationSession _$WebullAuthorizationSessionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'WebullAuthorizationSession',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['authorization_url', 'connection_id', 'expires_at'],
    );
    final val = WebullAuthorizationSession(
      authorizationUrl: $checkedConvert(
        'authorization_url',
        (v) => v as String,
      ),
      connectionId: $checkedConvert('connection_id', (v) => v as String),
      expiresAt: $checkedConvert(
        'expires_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'authorizationUrl': 'authorization_url',
    'connectionId': 'connection_id',
    'expiresAt': 'expires_at',
  },
);

Map<String, dynamic> _$WebullAuthorizationSessionToJson(
  WebullAuthorizationSession instance,
) => <String, dynamic>{
  'authorization_url': instance.authorizationUrl,
  'connection_id': instance.connectionId,
  'expires_at': instance.expiresAt.toIso8601String(),
};
