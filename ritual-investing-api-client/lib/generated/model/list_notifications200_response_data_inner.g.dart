// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_notifications200_response_data_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListNotifications200ResponseDataInnerCWProxy {
  ListNotifications200ResponseDataInner body(String body);

  ListNotifications200ResponseDataInner deepLink(String? deepLink);

  ListNotifications200ResponseDataInner id(String id);

  ListNotifications200ResponseDataInner kind(String kind);

  ListNotifications200ResponseDataInner readAt(DateTime? readAt);

  ListNotifications200ResponseDataInner scheduledAt(DateTime? scheduledAt);

  ListNotifications200ResponseDataInner title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListNotifications200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListNotifications200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListNotifications200ResponseDataInner call({
    String body,
    String? deepLink,
    String id,
    String kind,
    DateTime? readAt,
    DateTime? scheduledAt,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListNotifications200ResponseDataInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListNotifications200ResponseDataInner.copyWith.fieldName(...)`
class _$ListNotifications200ResponseDataInnerCWProxyImpl
    implements _$ListNotifications200ResponseDataInnerCWProxy {
  const _$ListNotifications200ResponseDataInnerCWProxyImpl(this._value);

  final ListNotifications200ResponseDataInner _value;

  @override
  ListNotifications200ResponseDataInner body(String body) => this(body: body);

  @override
  ListNotifications200ResponseDataInner deepLink(String? deepLink) =>
      this(deepLink: deepLink);

  @override
  ListNotifications200ResponseDataInner id(String id) => this(id: id);

  @override
  ListNotifications200ResponseDataInner kind(String kind) => this(kind: kind);

  @override
  ListNotifications200ResponseDataInner readAt(DateTime? readAt) =>
      this(readAt: readAt);

  @override
  ListNotifications200ResponseDataInner scheduledAt(DateTime? scheduledAt) =>
      this(scheduledAt: scheduledAt);

  @override
  ListNotifications200ResponseDataInner title(String title) =>
      this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListNotifications200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListNotifications200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListNotifications200ResponseDataInner call({
    Object? body = const $CopyWithPlaceholder(),
    Object? deepLink = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? readAt = const $CopyWithPlaceholder(),
    Object? scheduledAt = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return ListNotifications200ResponseDataInner(
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
      deepLink: deepLink == const $CopyWithPlaceholder()
          ? _value.deepLink
          // ignore: cast_nullable_to_non_nullable
          : deepLink as String?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as String,
      readAt: readAt == const $CopyWithPlaceholder()
          ? _value.readAt
          // ignore: cast_nullable_to_non_nullable
          : readAt as DateTime?,
      scheduledAt: scheduledAt == const $CopyWithPlaceholder()
          ? _value.scheduledAt
          // ignore: cast_nullable_to_non_nullable
          : scheduledAt as DateTime?,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $ListNotifications200ResponseDataInnerCopyWith
    on ListNotifications200ResponseDataInner {
  /// Returns a callable class that can be used as follows: `instanceOfListNotifications200ResponseDataInner.copyWith(...)` or like so:`instanceOfListNotifications200ResponseDataInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListNotifications200ResponseDataInnerCWProxy get copyWith =>
      _$ListNotifications200ResponseDataInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListNotifications200ResponseDataInner
_$ListNotifications200ResponseDataInnerFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ListNotifications200ResponseDataInner',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'body',
            'deep_link',
            'id',
            'kind',
            'read_at',
            'scheduled_at',
            'title',
          ],
        );
        final val = ListNotifications200ResponseDataInner(
          body: $checkedConvert('body', (v) => v as String),
          deepLink: $checkedConvert('deep_link', (v) => v as String?),
          id: $checkedConvert('id', (v) => v as String),
          kind: $checkedConvert('kind', (v) => v as String),
          readAt: $checkedConvert(
            'read_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          scheduledAt: $checkedConvert(
            'scheduled_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          title: $checkedConvert('title', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'deepLink': 'deep_link',
        'readAt': 'read_at',
        'scheduledAt': 'scheduled_at',
      },
    );

Map<String, dynamic> _$ListNotifications200ResponseDataInnerToJson(
  ListNotifications200ResponseDataInner instance,
) => <String, dynamic>{
  'body': instance.body,
  'deep_link': instance.deepLink,
  'id': instance.id,
  'kind': instance.kind,
  'read_at': instance.readAt?.toIso8601String(),
  'scheduled_at': instance.scheduledAt?.toIso8601String(),
  'title': instance.title,
};
