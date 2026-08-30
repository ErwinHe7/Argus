// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_session.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathSessionCWProxy {
  StarpathSession explicitStart(bool explicitStart);

  StarpathSession id(String id);

  StarpathSession lastActionAt(DateTime lastActionAt);

  StarpathSession replacementOfSessionId(String? replacementOfSessionId);

  StarpathSession startedAt(DateTime startedAt);

  StarpathSession state(StarpathSessionStateEnum state);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathSession(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathSession call({
    bool explicitStart,
    String id,
    DateTime lastActionAt,
    String? replacementOfSessionId,
    DateTime startedAt,
    StarpathSessionStateEnum state,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathSession.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathSession.copyWith.fieldName(...)`
class _$StarpathSessionCWProxyImpl implements _$StarpathSessionCWProxy {
  const _$StarpathSessionCWProxyImpl(this._value);

  final StarpathSession _value;

  @override
  StarpathSession explicitStart(bool explicitStart) =>
      this(explicitStart: explicitStart);

  @override
  StarpathSession id(String id) => this(id: id);

  @override
  StarpathSession lastActionAt(DateTime lastActionAt) =>
      this(lastActionAt: lastActionAt);

  @override
  StarpathSession replacementOfSessionId(String? replacementOfSessionId) =>
      this(replacementOfSessionId: replacementOfSessionId);

  @override
  StarpathSession startedAt(DateTime startedAt) => this(startedAt: startedAt);

  @override
  StarpathSession state(StarpathSessionStateEnum state) => this(state: state);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathSession(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathSession call({
    Object? explicitStart = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? lastActionAt = const $CopyWithPlaceholder(),
    Object? replacementOfSessionId = const $CopyWithPlaceholder(),
    Object? startedAt = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
  }) {
    return StarpathSession(
      explicitStart: explicitStart == const $CopyWithPlaceholder()
          ? _value.explicitStart
          // ignore: cast_nullable_to_non_nullable
          : explicitStart as bool,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      lastActionAt: lastActionAt == const $CopyWithPlaceholder()
          ? _value.lastActionAt
          // ignore: cast_nullable_to_non_nullable
          : lastActionAt as DateTime,
      replacementOfSessionId:
          replacementOfSessionId == const $CopyWithPlaceholder()
          ? _value.replacementOfSessionId
          // ignore: cast_nullable_to_non_nullable
          : replacementOfSessionId as String?,
      startedAt: startedAt == const $CopyWithPlaceholder()
          ? _value.startedAt
          // ignore: cast_nullable_to_non_nullable
          : startedAt as DateTime,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as StarpathSessionStateEnum,
    );
  }
}

extension $StarpathSessionCopyWith on StarpathSession {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathSession.copyWith(...)` or like so:`instanceOfStarpathSession.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathSessionCWProxy get copyWith => _$StarpathSessionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathSession _$StarpathSessionFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StarpathSession',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'explicit_start',
            'id',
            'last_action_at',
            'replacement_of_session_id',
            'started_at',
            'state',
          ],
        );
        final val = StarpathSession(
          explicitStart: $checkedConvert('explicit_start', (v) => v as bool),
          id: $checkedConvert('id', (v) => v as String),
          lastActionAt: $checkedConvert(
            'last_action_at',
            (v) => DateTime.parse(v as String),
          ),
          replacementOfSessionId: $checkedConvert(
            'replacement_of_session_id',
            (v) => v as String?,
          ),
          startedAt: $checkedConvert(
            'started_at',
            (v) => DateTime.parse(v as String),
          ),
          state: $checkedConvert(
            'state',
            (v) => $enumDecode(
              _$StarpathSessionStateEnumEnumMap,
              v,
              unknownValue: StarpathSessionStateEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'explicitStart': 'explicit_start',
        'lastActionAt': 'last_action_at',
        'replacementOfSessionId': 'replacement_of_session_id',
        'startedAt': 'started_at',
      },
    );

Map<String, dynamic> _$StarpathSessionToJson(StarpathSession instance) =>
    <String, dynamic>{
      'explicit_start': instance.explicitStart,
      'id': instance.id,
      'last_action_at': instance.lastActionAt.toIso8601String(),
      'replacement_of_session_id': instance.replacementOfSessionId,
      'started_at': instance.startedAt.toIso8601String(),
      'state': _$StarpathSessionStateEnumEnumMap[instance.state]!,
    };

const _$StarpathSessionStateEnumEnumMap = {
  StarpathSessionStateEnum.active: 'active',
  StarpathSessionStateEnum.closed: 'closed',
  StarpathSessionStateEnum.replaced: 'replaced',
  StarpathSessionStateEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
