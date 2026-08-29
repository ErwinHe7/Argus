// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'published_editorial.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublishedEditorialCWProxy {
  PublishedEditorial id(String id);

  PublishedEditorial kind(String kind);

  PublishedEditorial payload(Map<String, Object?> payload);

  PublishedEditorial revisionId(String revisionId);

  PublishedEditorial revisionNumber(int revisionNumber);

  PublishedEditorial slug(String slug);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublishedEditorial(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublishedEditorial(...).copyWith(id: 12, name: "My name")
  /// ````
  PublishedEditorial call({
    String id,
    String kind,
    Map<String, Object?> payload,
    String revisionId,
    int revisionNumber,
    String slug,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublishedEditorial.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublishedEditorial.copyWith.fieldName(...)`
class _$PublishedEditorialCWProxyImpl implements _$PublishedEditorialCWProxy {
  const _$PublishedEditorialCWProxyImpl(this._value);

  final PublishedEditorial _value;

  @override
  PublishedEditorial id(String id) => this(id: id);

  @override
  PublishedEditorial kind(String kind) => this(kind: kind);

  @override
  PublishedEditorial payload(Map<String, Object?> payload) =>
      this(payload: payload);

  @override
  PublishedEditorial revisionId(String revisionId) =>
      this(revisionId: revisionId);

  @override
  PublishedEditorial revisionNumber(int revisionNumber) =>
      this(revisionNumber: revisionNumber);

  @override
  PublishedEditorial slug(String slug) => this(slug: slug);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublishedEditorial(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublishedEditorial(...).copyWith(id: 12, name: "My name")
  /// ````
  PublishedEditorial call({
    Object? id = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? payload = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? revisionNumber = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
  }) {
    return PublishedEditorial(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as String,
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload as Map<String, Object?>,
      revisionId: revisionId == const $CopyWithPlaceholder()
          ? _value.revisionId
          // ignore: cast_nullable_to_non_nullable
          : revisionId as String,
      revisionNumber: revisionNumber == const $CopyWithPlaceholder()
          ? _value.revisionNumber
          // ignore: cast_nullable_to_non_nullable
          : revisionNumber as int,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
    );
  }
}

extension $PublishedEditorialCopyWith on PublishedEditorial {
  /// Returns a callable class that can be used as follows: `instanceOfPublishedEditorial.copyWith(...)` or like so:`instanceOfPublishedEditorial.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublishedEditorialCWProxy get copyWith =>
      _$PublishedEditorialCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublishedEditorial _$PublishedEditorialFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PublishedEditorial',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'kind',
            'payload',
            'revision_id',
            'revision_number',
            'slug',
          ],
        );
        final val = PublishedEditorial(
          id: $checkedConvert('id', (v) => v as String),
          kind: $checkedConvert('kind', (v) => v as String),
          payload: $checkedConvert('payload', (v) => v as Map<String, dynamic>),
          revisionId: $checkedConvert('revision_id', (v) => v as String),
          revisionNumber: $checkedConvert(
            'revision_number',
            (v) => (v as num).toInt(),
          ),
          slug: $checkedConvert('slug', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'revisionId': 'revision_id',
        'revisionNumber': 'revision_number',
      },
    );

Map<String, dynamic> _$PublishedEditorialToJson(PublishedEditorial instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'payload': instance.payload,
      'revision_id': instance.revisionId,
      'revision_number': instance.revisionNumber,
      'slug': instance.slug,
    };
