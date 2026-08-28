// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_member_intention.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateMemberIntentionCWProxy {
  CreateMemberIntention target(ScenarioMoney target);

  CreateMemberIntention targetDate(DateTime targetDate);

  CreateMemberIntention title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateMemberIntention(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateMemberIntention(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateMemberIntention call({
    ScenarioMoney target,
    DateTime targetDate,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateMemberIntention.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateMemberIntention.copyWith.fieldName(...)`
class _$CreateMemberIntentionCWProxyImpl
    implements _$CreateMemberIntentionCWProxy {
  const _$CreateMemberIntentionCWProxyImpl(this._value);

  final CreateMemberIntention _value;

  @override
  CreateMemberIntention target(ScenarioMoney target) => this(target: target);

  @override
  CreateMemberIntention targetDate(DateTime targetDate) =>
      this(targetDate: targetDate);

  @override
  CreateMemberIntention title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateMemberIntention(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateMemberIntention(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateMemberIntention call({
    Object? target = const $CopyWithPlaceholder(),
    Object? targetDate = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CreateMemberIntention(
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
    );
  }
}

extension $CreateMemberIntentionCopyWith on CreateMemberIntention {
  /// Returns a callable class that can be used as follows: `instanceOfCreateMemberIntention.copyWith(...)` or like so:`instanceOfCreateMemberIntention.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateMemberIntentionCWProxy get copyWith =>
      _$CreateMemberIntentionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateMemberIntention _$CreateMemberIntentionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateMemberIntention', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['target', 'target_date', 'title']);
  final val = CreateMemberIntention(
    target: $checkedConvert(
      'target',
      (v) => ScenarioMoney.fromJson(v as Map<String, dynamic>),
    ),
    targetDate: $checkedConvert(
      'target_date',
      (v) => DateTime.parse(v as String),
    ),
    title: $checkedConvert('title', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'targetDate': 'target_date'});

Map<String, dynamic> _$CreateMemberIntentionToJson(
  CreateMemberIntention instance,
) => <String, dynamic>{
  'target': instance.target.toJson(),
  'target_date': instance.targetDate.toIso8601String(),
  'title': instance.title,
};
