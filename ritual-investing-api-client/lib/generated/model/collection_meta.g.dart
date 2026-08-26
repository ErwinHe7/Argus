// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_meta.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CollectionMetaCWProxy {
  CollectionMeta hasMore(bool hasMore);

  CollectionMeta nextCursor(String? nextCursor);

  CollectionMeta requestId(String requestId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CollectionMeta(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CollectionMeta(...).copyWith(id: 12, name: "My name")
  /// ````
  CollectionMeta call({bool hasMore, String? nextCursor, String requestId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCollectionMeta.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCollectionMeta.copyWith.fieldName(...)`
class _$CollectionMetaCWProxyImpl implements _$CollectionMetaCWProxy {
  const _$CollectionMetaCWProxyImpl(this._value);

  final CollectionMeta _value;

  @override
  CollectionMeta hasMore(bool hasMore) => this(hasMore: hasMore);

  @override
  CollectionMeta nextCursor(String? nextCursor) => this(nextCursor: nextCursor);

  @override
  CollectionMeta requestId(String requestId) => this(requestId: requestId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CollectionMeta(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CollectionMeta(...).copyWith(id: 12, name: "My name")
  /// ````
  CollectionMeta call({
    Object? hasMore = const $CopyWithPlaceholder(),
    Object? nextCursor = const $CopyWithPlaceholder(),
    Object? requestId = const $CopyWithPlaceholder(),
  }) {
    return CollectionMeta(
      hasMore: hasMore == const $CopyWithPlaceholder()
          ? _value.hasMore
          // ignore: cast_nullable_to_non_nullable
          : hasMore as bool,
      nextCursor: nextCursor == const $CopyWithPlaceholder()
          ? _value.nextCursor
          // ignore: cast_nullable_to_non_nullable
          : nextCursor as String?,
      requestId: requestId == const $CopyWithPlaceholder()
          ? _value.requestId
          // ignore: cast_nullable_to_non_nullable
          : requestId as String,
    );
  }
}

extension $CollectionMetaCopyWith on CollectionMeta {
  /// Returns a callable class that can be used as follows: `instanceOfCollectionMeta.copyWith(...)` or like so:`instanceOfCollectionMeta.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CollectionMetaCWProxy get copyWith => _$CollectionMetaCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CollectionMeta _$CollectionMetaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CollectionMeta',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['has_more', 'next_cursor', 'request_id'],
        );
        final val = CollectionMeta(
          hasMore: $checkedConvert('has_more', (v) => v as bool),
          nextCursor: $checkedConvert('next_cursor', (v) => v as String?),
          requestId: $checkedConvert('request_id', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'hasMore': 'has_more',
        'nextCursor': 'next_cursor',
        'requestId': 'request_id',
      },
    );

Map<String, dynamic> _$CollectionMetaToJson(CollectionMeta instance) =>
    <String, dynamic>{
      'has_more': instance.hasMore,
      'next_cursor': instance.nextCursor,
      'request_id': instance.requestId,
    };
