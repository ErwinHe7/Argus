// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ritual_history_item.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RitualHistoryItemCWProxy {
  RitualHistoryItem assignmentId(String assignmentId);

  RitualHistoryItem date(DateTime date);

  RitualHistoryItem demo(DemoDisclosure demo);

  RitualHistoryItem mode(RitualHistoryItemModeEnum mode);

  RitualHistoryItem state(RitualHistoryItemStateEnum state);

  RitualHistoryItem title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RitualHistoryItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RitualHistoryItem(...).copyWith(id: 12, name: "My name")
  /// ````
  RitualHistoryItem call({
    String assignmentId,
    DateTime date,
    DemoDisclosure demo,
    RitualHistoryItemModeEnum mode,
    RitualHistoryItemStateEnum state,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRitualHistoryItem.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRitualHistoryItem.copyWith.fieldName(...)`
class _$RitualHistoryItemCWProxyImpl implements _$RitualHistoryItemCWProxy {
  const _$RitualHistoryItemCWProxyImpl(this._value);

  final RitualHistoryItem _value;

  @override
  RitualHistoryItem assignmentId(String assignmentId) =>
      this(assignmentId: assignmentId);

  @override
  RitualHistoryItem date(DateTime date) => this(date: date);

  @override
  RitualHistoryItem demo(DemoDisclosure demo) => this(demo: demo);

  @override
  RitualHistoryItem mode(RitualHistoryItemModeEnum mode) => this(mode: mode);

  @override
  RitualHistoryItem state(RitualHistoryItemStateEnum state) =>
      this(state: state);

  @override
  RitualHistoryItem title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RitualHistoryItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RitualHistoryItem(...).copyWith(id: 12, name: "My name")
  /// ````
  RitualHistoryItem call({
    Object? assignmentId = const $CopyWithPlaceholder(),
    Object? date = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? mode = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return RitualHistoryItem(
      assignmentId: assignmentId == const $CopyWithPlaceholder()
          ? _value.assignmentId
          // ignore: cast_nullable_to_non_nullable
          : assignmentId as String,
      date: date == const $CopyWithPlaceholder()
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as DateTime,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      mode: mode == const $CopyWithPlaceholder()
          ? _value.mode
          // ignore: cast_nullable_to_non_nullable
          : mode as RitualHistoryItemModeEnum,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as RitualHistoryItemStateEnum,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $RitualHistoryItemCopyWith on RitualHistoryItem {
  /// Returns a callable class that can be used as follows: `instanceOfRitualHistoryItem.copyWith(...)` or like so:`instanceOfRitualHistoryItem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RitualHistoryItemCWProxy get copyWith =>
      _$RitualHistoryItemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RitualHistoryItem _$RitualHistoryItemFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RitualHistoryItem', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'assignment_id',
          'date',
          'demo',
          'mode',
          'state',
          'title',
        ],
      );
      final val = RitualHistoryItem(
        assignmentId: $checkedConvert('assignment_id', (v) => v as String),
        date: $checkedConvert('date', (v) => DateTime.parse(v as String)),
        demo: $checkedConvert(
          'demo',
          (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
        ),
        mode: $checkedConvert(
          'mode',
          (v) => $enumDecode(
            _$RitualHistoryItemModeEnumEnumMap,
            v,
            unknownValue: RitualHistoryItemModeEnum.unknownDefaultOpenApi,
          ),
        ),
        state: $checkedConvert(
          'state',
          (v) => $enumDecode(
            _$RitualHistoryItemStateEnumEnumMap,
            v,
            unknownValue: RitualHistoryItemStateEnum.unknownDefaultOpenApi,
          ),
        ),
        title: $checkedConvert('title', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'assignmentId': 'assignment_id'});

Map<String, dynamic> _$RitualHistoryItemToJson(RitualHistoryItem instance) =>
    <String, dynamic>{
      'assignment_id': instance.assignmentId,
      'date': instance.date.toIso8601String(),
      'demo': instance.demo.toJson(),
      'mode': _$RitualHistoryItemModeEnumEnumMap[instance.mode]!,
      'state': _$RitualHistoryItemStateEnumEnumMap[instance.state]!,
      'title': instance.title,
    };

const _$RitualHistoryItemModeEnumEnumMap = {
  RitualHistoryItemModeEnum.tarot: 'tarot',
  RitualHistoryItemModeEnum.astrology: 'astrology',
  RitualHistoryItemModeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$RitualHistoryItemStateEnumEnumMap = {
  RitualHistoryItemStateEnum.assigned: 'assigned',
  RitualHistoryItemStateEnum.revealed: 'revealed',
  RitualHistoryItemStateEnum.completed: 'completed',
  RitualHistoryItemStateEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
