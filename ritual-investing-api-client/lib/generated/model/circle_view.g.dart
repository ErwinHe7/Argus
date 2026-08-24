// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_view.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleViewCWProxy {
  CircleView archivedAt(DateTime? archivedAt);

  CircleView assets(List<CircleViewAssetsInner> assets);

  CircleView description(String description);

  CircleView id(String id);

  CircleView private(bool private);

  CircleView sourceRevisionId(String? sourceRevisionId);

  CircleView sourceTemplateId(String? sourceTemplateId);

  CircleView title(String title);

  CircleView version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleView(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleView(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleView call({
    DateTime? archivedAt,
    List<CircleViewAssetsInner> assets,
    String description,
    String id,
    bool private,
    String? sourceRevisionId,
    String? sourceTemplateId,
    String title,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleView.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleView.copyWith.fieldName(...)`
class _$CircleViewCWProxyImpl implements _$CircleViewCWProxy {
  const _$CircleViewCWProxyImpl(this._value);

  final CircleView _value;

  @override
  CircleView archivedAt(DateTime? archivedAt) => this(archivedAt: archivedAt);

  @override
  CircleView assets(List<CircleViewAssetsInner> assets) => this(assets: assets);

  @override
  CircleView description(String description) => this(description: description);

  @override
  CircleView id(String id) => this(id: id);

  @override
  CircleView private(bool private) => this(private: private);

  @override
  CircleView sourceRevisionId(String? sourceRevisionId) =>
      this(sourceRevisionId: sourceRevisionId);

  @override
  CircleView sourceTemplateId(String? sourceTemplateId) =>
      this(sourceTemplateId: sourceTemplateId);

  @override
  CircleView title(String title) => this(title: title);

  @override
  CircleView version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleView(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleView(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleView call({
    Object? archivedAt = const $CopyWithPlaceholder(),
    Object? assets = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? private = const $CopyWithPlaceholder(),
    Object? sourceRevisionId = const $CopyWithPlaceholder(),
    Object? sourceTemplateId = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return CircleView(
      archivedAt: archivedAt == const $CopyWithPlaceholder()
          ? _value.archivedAt
          // ignore: cast_nullable_to_non_nullable
          : archivedAt as DateTime?,
      assets: assets == const $CopyWithPlaceholder()
          ? _value.assets
          // ignore: cast_nullable_to_non_nullable
          : assets as List<CircleViewAssetsInner>,
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      private: private == const $CopyWithPlaceholder()
          ? _value.private
          // ignore: cast_nullable_to_non_nullable
          : private as bool,
      sourceRevisionId: sourceRevisionId == const $CopyWithPlaceholder()
          ? _value.sourceRevisionId
          // ignore: cast_nullable_to_non_nullable
          : sourceRevisionId as String?,
      sourceTemplateId: sourceTemplateId == const $CopyWithPlaceholder()
          ? _value.sourceTemplateId
          // ignore: cast_nullable_to_non_nullable
          : sourceTemplateId as String?,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $CircleViewCopyWith on CircleView {
  /// Returns a callable class that can be used as follows: `instanceOfCircleView.copyWith(...)` or like so:`instanceOfCircleView.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleViewCWProxy get copyWith => _$CircleViewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleView _$CircleViewFromJson(Map<String, dynamic> json) => $checkedCreate(
  'CircleView',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'archived_at',
        'assets',
        'description',
        'id',
        'private',
        'source_revision_id',
        'source_template_id',
        'title',
        'version',
      ],
    );
    final val = CircleView(
      archivedAt: $checkedConvert(
        'archived_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      assets: $checkedConvert(
        'assets',
        (v) => (v as List<dynamic>)
            .map(
              (e) => CircleViewAssetsInner.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
      description: $checkedConvert('description', (v) => v as String),
      id: $checkedConvert('id', (v) => v as String),
      private: $checkedConvert('private', (v) => v as bool),
      sourceRevisionId: $checkedConvert(
        'source_revision_id',
        (v) => v as String?,
      ),
      sourceTemplateId: $checkedConvert(
        'source_template_id',
        (v) => v as String?,
      ),
      title: $checkedConvert('title', (v) => v as String),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'archivedAt': 'archived_at',
    'sourceRevisionId': 'source_revision_id',
    'sourceTemplateId': 'source_template_id',
  },
);

Map<String, dynamic> _$CircleViewToJson(CircleView instance) =>
    <String, dynamic>{
      'archived_at': instance.archivedAt?.toIso8601String(),
      'assets': instance.assets.map((e) => e.toJson()).toList(),
      'description': instance.description,
      'id': instance.id,
      'private': instance.private,
      'source_revision_id': instance.sourceRevisionId,
      'source_template_id': instance.sourceTemplateId,
      'title': instance.title,
      'version': instance.version,
    };
