// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_ritual_detail_revision.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DailyRitualDetailRevisionCWProxy {
  DailyRitualDetailRevision id(String id);

  DailyRitualDetailRevision number(int number);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DailyRitualDetailRevision(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DailyRitualDetailRevision(...).copyWith(id: 12, name: "My name")
  /// ````
  DailyRitualDetailRevision call({String id, int number});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDailyRitualDetailRevision.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDailyRitualDetailRevision.copyWith.fieldName(...)`
class _$DailyRitualDetailRevisionCWProxyImpl
    implements _$DailyRitualDetailRevisionCWProxy {
  const _$DailyRitualDetailRevisionCWProxyImpl(this._value);

  final DailyRitualDetailRevision _value;

  @override
  DailyRitualDetailRevision id(String id) => this(id: id);

  @override
  DailyRitualDetailRevision number(int number) => this(number: number);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DailyRitualDetailRevision(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DailyRitualDetailRevision(...).copyWith(id: 12, name: "My name")
  /// ````
  DailyRitualDetailRevision call({
    Object? id = const $CopyWithPlaceholder(),
    Object? number = const $CopyWithPlaceholder(),
  }) {
    return DailyRitualDetailRevision(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      number: number == const $CopyWithPlaceholder()
          ? _value.number
          // ignore: cast_nullable_to_non_nullable
          : number as int,
    );
  }
}

extension $DailyRitualDetailRevisionCopyWith on DailyRitualDetailRevision {
  /// Returns a callable class that can be used as follows: `instanceOfDailyRitualDetailRevision.copyWith(...)` or like so:`instanceOfDailyRitualDetailRevision.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DailyRitualDetailRevisionCWProxy get copyWith =>
      _$DailyRitualDetailRevisionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyRitualDetailRevision _$DailyRitualDetailRevisionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DailyRitualDetailRevision', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['id', 'number']);
  final val = DailyRitualDetailRevision(
    id: $checkedConvert('id', (v) => v as String),
    number: $checkedConvert('number', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$DailyRitualDetailRevisionToJson(
  DailyRitualDetailRevision instance,
) => <String, dynamic>{'id': instance.id, 'number': instance.number};
