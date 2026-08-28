// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_detail_source.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EvidenceDetailSourceCWProxy {
  EvidenceDetailSource publishedAt(DateTime? publishedAt);

  EvidenceDetailSource publisher(String publisher);

  EvidenceDetailSource title(String title);

  EvidenceDetailSource url(String? url);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceDetailSource(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceDetailSource(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceDetailSource call({
    DateTime? publishedAt,
    String publisher,
    String title,
    String? url,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEvidenceDetailSource.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEvidenceDetailSource.copyWith.fieldName(...)`
class _$EvidenceDetailSourceCWProxyImpl
    implements _$EvidenceDetailSourceCWProxy {
  const _$EvidenceDetailSourceCWProxyImpl(this._value);

  final EvidenceDetailSource _value;

  @override
  EvidenceDetailSource publishedAt(DateTime? publishedAt) =>
      this(publishedAt: publishedAt);

  @override
  EvidenceDetailSource publisher(String publisher) =>
      this(publisher: publisher);

  @override
  EvidenceDetailSource title(String title) => this(title: title);

  @override
  EvidenceDetailSource url(String? url) => this(url: url);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceDetailSource(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceDetailSource(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceDetailSource call({
    Object? publishedAt = const $CopyWithPlaceholder(),
    Object? publisher = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? url = const $CopyWithPlaceholder(),
  }) {
    return EvidenceDetailSource(
      publishedAt: publishedAt == const $CopyWithPlaceholder()
          ? _value.publishedAt
          // ignore: cast_nullable_to_non_nullable
          : publishedAt as DateTime?,
      publisher: publisher == const $CopyWithPlaceholder()
          ? _value.publisher
          // ignore: cast_nullable_to_non_nullable
          : publisher as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      url: url == const $CopyWithPlaceholder()
          ? _value.url
          // ignore: cast_nullable_to_non_nullable
          : url as String?,
    );
  }
}

extension $EvidenceDetailSourceCopyWith on EvidenceDetailSource {
  /// Returns a callable class that can be used as follows: `instanceOfEvidenceDetailSource.copyWith(...)` or like so:`instanceOfEvidenceDetailSource.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EvidenceDetailSourceCWProxy get copyWith =>
      _$EvidenceDetailSourceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EvidenceDetailSource _$EvidenceDetailSourceFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('EvidenceDetailSource', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['published_at', 'publisher', 'title', 'url'],
  );
  final val = EvidenceDetailSource(
    publishedAt: $checkedConvert(
      'published_at',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    publisher: $checkedConvert('publisher', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    url: $checkedConvert('url', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'publishedAt': 'published_at'});

Map<String, dynamic> _$EvidenceDetailSourceToJson(
  EvidenceDetailSource instance,
) => <String, dynamic>{
  'published_at': instance.publishedAt?.toIso8601String(),
  'publisher': instance.publisher,
  'title': instance.title,
  'url': instance.url,
};
