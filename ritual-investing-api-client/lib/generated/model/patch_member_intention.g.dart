// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_member_intention.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchMemberIntentionCWProxy {
  PatchMemberIntention target(ScenarioMoney? target);

  PatchMemberIntention targetDate(DateTime? targetDate);

  PatchMemberIntention title(String? title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchMemberIntention(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchMemberIntention(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchMemberIntention call({
    ScenarioMoney? target,
    DateTime? targetDate,
    String? title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchMemberIntention.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchMemberIntention.copyWith.fieldName(...)`
class _$PatchMemberIntentionCWProxyImpl
    implements _$PatchMemberIntentionCWProxy {
  const _$PatchMemberIntentionCWProxyImpl(this._value);

  final PatchMemberIntention _value;

  @override
  PatchMemberIntention target(ScenarioMoney? target) => this(target: target);

  @override
  PatchMemberIntention targetDate(DateTime? targetDate) =>
      this(targetDate: targetDate);

  @override
  PatchMemberIntention title(String? title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchMemberIntention(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchMemberIntention(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchMemberIntention call({
    Object? target = const $CopyWithPlaceholder(),
    Object? targetDate = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return PatchMemberIntention(
      target: target == const $CopyWithPlaceholder()
          ? _value.target
          // ignore: cast_nullable_to_non_nullable
          : target as ScenarioMoney?,
      targetDate: targetDate == const $CopyWithPlaceholder()
          ? _value.targetDate
          // ignore: cast_nullable_to_non_nullable
          : targetDate as DateTime?,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String?,
    );
  }
}

extension $PatchMemberIntentionCopyWith on PatchMemberIntention {
  /// Returns a callable class that can be used as follows: `instanceOfPatchMemberIntention.copyWith(...)` or like so:`instanceOfPatchMemberIntention.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchMemberIntentionCWProxy get copyWith =>
      _$PatchMemberIntentionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchMemberIntention _$PatchMemberIntentionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchMemberIntention', json, ($checkedConvert) {
  final val = PatchMemberIntention(
    target: $checkedConvert(
      'target',
      (v) =>
          v == null ? null : ScenarioMoney.fromJson(v as Map<String, dynamic>),
    ),
    targetDate: $checkedConvert(
      'target_date',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    title: $checkedConvert('title', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'targetDate': 'target_date'});

Map<String, dynamic> _$PatchMemberIntentionToJson(
  PatchMemberIntention instance,
) => <String, dynamic>{
  'target': ?instance.target?.toJson(),
  'target_date': ?instance.targetDate?.toIso8601String(),
  'title': ?instance.title,
};
