// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_ritual_schedule201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminRitualSchedule201ResponseCWProxy {
  CreateAdminRitualSchedule201Response data(AdminRitualSchedule data);

  CreateAdminRitualSchedule201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminRitualSchedule201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminRitualSchedule201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminRitualSchedule201Response call({
    AdminRitualSchedule data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminRitualSchedule201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminRitualSchedule201Response.copyWith.fieldName(...)`
class _$CreateAdminRitualSchedule201ResponseCWProxyImpl
    implements _$CreateAdminRitualSchedule201ResponseCWProxy {
  const _$CreateAdminRitualSchedule201ResponseCWProxyImpl(this._value);

  final CreateAdminRitualSchedule201Response _value;

  @override
  CreateAdminRitualSchedule201Response data(AdminRitualSchedule data) =>
      this(data: data);

  @override
  CreateAdminRitualSchedule201Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminRitualSchedule201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminRitualSchedule201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminRitualSchedule201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminRitualSchedule201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminRitualSchedule,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateAdminRitualSchedule201ResponseCopyWith
    on CreateAdminRitualSchedule201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminRitualSchedule201Response.copyWith(...)` or like so:`instanceOfCreateAdminRitualSchedule201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminRitualSchedule201ResponseCWProxy get copyWith =>
      _$CreateAdminRitualSchedule201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminRitualSchedule201Response
_$CreateAdminRitualSchedule201ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateAdminRitualSchedule201Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = CreateAdminRitualSchedule201Response(
        data: $checkedConvert(
          'data',
          (v) => AdminRitualSchedule.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CreateAdminRitualSchedule201ResponseToJson(
  CreateAdminRitualSchedule201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
