// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_ritual_schedules200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminRitualSchedules200ResponseCWProxy {
  ListAdminRitualSchedules200Response data(List<AdminRitualSchedule> data);

  ListAdminRitualSchedules200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminRitualSchedules200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminRitualSchedules200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminRitualSchedules200Response call({
    List<AdminRitualSchedule> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminRitualSchedules200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminRitualSchedules200Response.copyWith.fieldName(...)`
class _$ListAdminRitualSchedules200ResponseCWProxyImpl
    implements _$ListAdminRitualSchedules200ResponseCWProxy {
  const _$ListAdminRitualSchedules200ResponseCWProxyImpl(this._value);

  final ListAdminRitualSchedules200Response _value;

  @override
  ListAdminRitualSchedules200Response data(List<AdminRitualSchedule> data) =>
      this(data: data);

  @override
  ListAdminRitualSchedules200Response meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminRitualSchedules200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminRitualSchedules200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminRitualSchedules200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminRitualSchedules200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<AdminRitualSchedule>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminRitualSchedules200ResponseCopyWith
    on ListAdminRitualSchedules200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminRitualSchedules200Response.copyWith(...)` or like so:`instanceOfListAdminRitualSchedules200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminRitualSchedules200ResponseCWProxy get copyWith =>
      _$ListAdminRitualSchedules200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminRitualSchedules200Response
_$ListAdminRitualSchedules200ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ListAdminRitualSchedules200Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = ListAdminRitualSchedules200Response(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map(
                (e) => AdminRitualSchedule.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ListAdminRitualSchedules200ResponseToJson(
  ListAdminRitualSchedules200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
