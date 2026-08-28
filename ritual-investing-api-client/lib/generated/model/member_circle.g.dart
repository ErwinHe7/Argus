// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_circle.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberCircleCWProxy {
  MemberCircle archivedAt(DateTime? archivedAt);

  MemberCircle assets(List<MemberCircleAssetsInner>? assets);

  MemberCircle deletionEpoch(int? deletionEpoch);

  MemberCircle description(String description);

  MemberCircle id(String id);

  MemberCircle private(bool private);

  MemberCircle sourceRevisionId(String? sourceRevisionId);

  MemberCircle sourceTemplateId(String? sourceTemplateId);

  MemberCircle title(String title);

  MemberCircle userId(String userId);

  MemberCircle version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberCircle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberCircle(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberCircle call({
    DateTime? archivedAt,
    List<MemberCircleAssetsInner>? assets,
    int? deletionEpoch,
    String description,
    String id,
    bool private,
    String? sourceRevisionId,
    String? sourceTemplateId,
    String title,
    String userId,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberCircle.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberCircle.copyWith.fieldName(...)`
class _$MemberCircleCWProxyImpl implements _$MemberCircleCWProxy {
  const _$MemberCircleCWProxyImpl(this._value);

  final MemberCircle _value;

  @override
  MemberCircle archivedAt(DateTime? archivedAt) => this(archivedAt: archivedAt);

  @override
  MemberCircle assets(List<MemberCircleAssetsInner>? assets) =>
      this(assets: assets);

  @override
  MemberCircle deletionEpoch(int? deletionEpoch) =>
      this(deletionEpoch: deletionEpoch);

  @override
  MemberCircle description(String description) =>
      this(description: description);

  @override
  MemberCircle id(String id) => this(id: id);

  @override
  MemberCircle private(bool private) => this(private: private);

  @override
  MemberCircle sourceRevisionId(String? sourceRevisionId) =>
      this(sourceRevisionId: sourceRevisionId);

  @override
  MemberCircle sourceTemplateId(String? sourceTemplateId) =>
      this(sourceTemplateId: sourceTemplateId);

  @override
  MemberCircle title(String title) => this(title: title);

  @override
  MemberCircle userId(String userId) => this(userId: userId);

  @override
  MemberCircle version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberCircle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberCircle(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberCircle call({
    Object? archivedAt = const $CopyWithPlaceholder(),
    Object? assets = const $CopyWithPlaceholder(),
    Object? deletionEpoch = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? private = const $CopyWithPlaceholder(),
    Object? sourceRevisionId = const $CopyWithPlaceholder(),
    Object? sourceTemplateId = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return MemberCircle(
      archivedAt: archivedAt == const $CopyWithPlaceholder()
          ? _value.archivedAt
          // ignore: cast_nullable_to_non_nullable
          : archivedAt as DateTime?,
      assets: assets == const $CopyWithPlaceholder()
          ? _value.assets
          // ignore: cast_nullable_to_non_nullable
          : assets as List<MemberCircleAssetsInner>?,
      deletionEpoch: deletionEpoch == const $CopyWithPlaceholder()
          ? _value.deletionEpoch
          // ignore: cast_nullable_to_non_nullable
          : deletionEpoch as int?,
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
      userId: userId == const $CopyWithPlaceholder()
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as String,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $MemberCircleCopyWith on MemberCircle {
  /// Returns a callable class that can be used as follows: `instanceOfMemberCircle.copyWith(...)` or like so:`instanceOfMemberCircle.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberCircleCWProxy get copyWith => _$MemberCircleCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberCircle _$MemberCircleFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'MemberCircle',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'archived_at',
            'deletion_epoch',
            'description',
            'id',
            'private',
            'source_revision_id',
            'source_template_id',
            'title',
            'user_id',
            'version',
          ],
        );
        final val = MemberCircle(
          archivedAt: $checkedConvert(
            'archived_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          assets: $checkedConvert(
            'assets',
            (v) => (v as List<dynamic>?)
                ?.map(
                  (e) => MemberCircleAssetsInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
          ),
          deletionEpoch: $checkedConvert(
            'deletion_epoch',
            (v) => (v as num?)?.toInt(),
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
          userId: $checkedConvert('user_id', (v) => v as String),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'archivedAt': 'archived_at',
        'deletionEpoch': 'deletion_epoch',
        'sourceRevisionId': 'source_revision_id',
        'sourceTemplateId': 'source_template_id',
        'userId': 'user_id',
      },
    );

Map<String, dynamic> _$MemberCircleToJson(MemberCircle instance) =>
    <String, dynamic>{
      'archived_at': instance.archivedAt?.toIso8601String(),
      'assets': ?instance.assets?.map((e) => e.toJson()).toList(),
      'deletion_epoch': instance.deletionEpoch,
      'description': instance.description,
      'id': instance.id,
      'private': instance.private,
      'source_revision_id': instance.sourceRevisionId,
      'source_template_id': instance.sourceTemplateId,
      'title': instance.title,
      'user_id': instance.userId,
      'version': instance.version,
    };
