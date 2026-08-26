// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_moderation_reports200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminModerationReports200ResponseCWProxy {
  ListAdminModerationReports200Response data(List<AdminModerationReport> data);

  ListAdminModerationReports200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminModerationReports200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminModerationReports200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminModerationReports200Response call({
    List<AdminModerationReport> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminModerationReports200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminModerationReports200Response.copyWith.fieldName(...)`
class _$ListAdminModerationReports200ResponseCWProxyImpl
    implements _$ListAdminModerationReports200ResponseCWProxy {
  const _$ListAdminModerationReports200ResponseCWProxyImpl(this._value);

  final ListAdminModerationReports200Response _value;

  @override
  ListAdminModerationReports200Response data(
    List<AdminModerationReport> data,
  ) => this(data: data);

  @override
  ListAdminModerationReports200Response meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminModerationReports200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminModerationReports200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminModerationReports200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminModerationReports200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<AdminModerationReport>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminModerationReports200ResponseCopyWith
    on ListAdminModerationReports200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminModerationReports200Response.copyWith(...)` or like so:`instanceOfListAdminModerationReports200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminModerationReports200ResponseCWProxy get copyWith =>
      _$ListAdminModerationReports200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminModerationReports200Response
_$ListAdminModerationReports200ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ListAdminModerationReports200Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = ListAdminModerationReports200Response(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map(
                (e) =>
                    AdminModerationReport.fromJson(e as Map<String, dynamic>),
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

Map<String, dynamic> _$ListAdminModerationReports200ResponseToJson(
  ListAdminModerationReports200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
