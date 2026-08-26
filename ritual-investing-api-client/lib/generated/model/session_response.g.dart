// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionResponseCWProxy {
  SessionResponse data(SessionResponseData data);

  SessionResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionResponse call({SessionResponseData data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionResponse.copyWith.fieldName(...)`
class _$SessionResponseCWProxyImpl implements _$SessionResponseCWProxy {
  const _$SessionResponseCWProxyImpl(this._value);

  final SessionResponse _value;

  @override
  SessionResponse data(SessionResponseData data) => this(data: data);

  @override
  SessionResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return SessionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as SessionResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $SessionResponseCopyWith on SessionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfSessionResponse.copyWith(...)` or like so:`instanceOfSessionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionResponseCWProxy get copyWith => _$SessionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionResponse _$SessionResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SessionResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = SessionResponse(
        data: $checkedConvert(
          'data',
          (v) => SessionResponseData.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SessionResponseToJson(SessionResponse instance) =>
    <String, dynamic>{
      'data': instance.data.toJson(),
      'meta': instance.meta.toJson(),
    };
