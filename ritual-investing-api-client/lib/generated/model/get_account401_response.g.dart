// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_account401_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetAccount401ResponseCWProxy {
  GetAccount401Response error(GetAccount401ResponseError error);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAccount401Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAccount401Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAccount401Response call({GetAccount401ResponseError error});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetAccount401Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetAccount401Response.copyWith.fieldName(...)`
class _$GetAccount401ResponseCWProxyImpl
    implements _$GetAccount401ResponseCWProxy {
  const _$GetAccount401ResponseCWProxyImpl(this._value);

  final GetAccount401Response _value;

  @override
  GetAccount401Response error(GetAccount401ResponseError error) =>
      this(error: error);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetAccount401Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetAccount401Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetAccount401Response call({Object? error = const $CopyWithPlaceholder()}) {
    return GetAccount401Response(
      error: error == const $CopyWithPlaceholder()
          ? _value.error
          // ignore: cast_nullable_to_non_nullable
          : error as GetAccount401ResponseError,
    );
  }
}

extension $GetAccount401ResponseCopyWith on GetAccount401Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetAccount401Response.copyWith(...)` or like so:`instanceOfGetAccount401Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetAccount401ResponseCWProxy get copyWith =>
      _$GetAccount401ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetAccount401Response _$GetAccount401ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetAccount401Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['error']);
  final val = GetAccount401Response(
    error: $checkedConvert(
      'error',
      (v) => GetAccount401ResponseError.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetAccount401ResponseToJson(
  GetAccount401Response instance,
) => <String, dynamic>{'error': instance.error.toJson()};
