// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_intention.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberIntentionCWProxy {
  MemberIntention createdAt(DateTime createdAt);

  MemberIntention id(String id);

  MemberIntention status(MemberIntentionStatusEnum status);

  MemberIntention target(ScenarioMoney target);

  MemberIntention targetDate(DateTime targetDate);

  MemberIntention title(String title);

  MemberIntention version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberIntention(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberIntention(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberIntention call({
    DateTime createdAt,
    String id,
    MemberIntentionStatusEnum status,
    ScenarioMoney target,
    DateTime targetDate,
    String title,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberIntention.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberIntention.copyWith.fieldName(...)`
class _$MemberIntentionCWProxyImpl implements _$MemberIntentionCWProxy {
  const _$MemberIntentionCWProxyImpl(this._value);

  final MemberIntention _value;

  @override
  MemberIntention createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  MemberIntention id(String id) => this(id: id);

  @override
  MemberIntention status(MemberIntentionStatusEnum status) =>
      this(status: status);

  @override
  MemberIntention target(ScenarioMoney target) => this(target: target);

  @override
  MemberIntention targetDate(DateTime targetDate) =>
      this(targetDate: targetDate);

  @override
  MemberIntention title(String title) => this(title: title);

  @override
  MemberIntention version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberIntention(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberIntention(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberIntention call({
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? target = const $CopyWithPlaceholder(),
    Object? targetDate = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return MemberIntention(
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as MemberIntentionStatusEnum,
      target: target == const $CopyWithPlaceholder()
          ? _value.target
          // ignore: cast_nullable_to_non_nullable
          : target as ScenarioMoney,
      targetDate: targetDate == const $CopyWithPlaceholder()
          ? _value.targetDate
          // ignore: cast_nullable_to_non_nullable
          : targetDate as DateTime,
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

extension $MemberIntentionCopyWith on MemberIntention {
  /// Returns a callable class that can be used as follows: `instanceOfMemberIntention.copyWith(...)` or like so:`instanceOfMemberIntention.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberIntentionCWProxy get copyWith => _$MemberIntentionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberIntention _$MemberIntentionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemberIntention', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'created_at',
      'id',
      'status',
      'target',
      'target_date',
      'title',
      'version',
    ],
  );
  final val = MemberIntention(
    createdAt: $checkedConvert(
      'created_at',
      (v) => DateTime.parse(v as String),
    ),
    id: $checkedConvert('id', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$MemberIntentionStatusEnumEnumMap,
        v,
        unknownValue: MemberIntentionStatusEnum.unknownDefaultOpenApi,
      ),
    ),
    target: $checkedConvert(
      'target',
      (v) => ScenarioMoney.fromJson(v as Map<String, dynamic>),
    ),
    targetDate: $checkedConvert(
      'target_date',
      (v) => DateTime.parse(v as String),
    ),
    title: $checkedConvert('title', (v) => v as String),
    version: $checkedConvert('version', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'createdAt': 'created_at', 'targetDate': 'target_date'});

Map<String, dynamic> _$MemberIntentionToJson(MemberIntention instance) =>
    <String, dynamic>{
      'created_at': instance.createdAt.toIso8601String(),
      'id': instance.id,
      'status': _$MemberIntentionStatusEnumEnumMap[instance.status]!,
      'target': instance.target.toJson(),
      'target_date': instance.targetDate.toIso8601String(),
      'title': instance.title,
      'version': instance.version,
    };

const _$MemberIntentionStatusEnumEnumMap = {
  MemberIntentionStatusEnum.active: 'active',
  MemberIntentionStatusEnum.archived: 'archived',
  MemberIntentionStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
