// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webull_completion.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebullCompletionCWProxy {
  WebullCompletion connectionId(String connectionId);

  WebullCompletion createdAt(DateTime createdAt);

  WebullCompletion outcome(WebullCompletionOutcomeEnum outcome);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullCompletion(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullCompletion(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullCompletion call({
    String connectionId,
    DateTime createdAt,
    WebullCompletionOutcomeEnum outcome,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebullCompletion.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebullCompletion.copyWith.fieldName(...)`
class _$WebullCompletionCWProxyImpl implements _$WebullCompletionCWProxy {
  const _$WebullCompletionCWProxyImpl(this._value);

  final WebullCompletion _value;

  @override
  WebullCompletion connectionId(String connectionId) =>
      this(connectionId: connectionId);

  @override
  WebullCompletion createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  WebullCompletion outcome(WebullCompletionOutcomeEnum outcome) =>
      this(outcome: outcome);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebullCompletion(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebullCompletion(...).copyWith(id: 12, name: "My name")
  /// ````
  WebullCompletion call({
    Object? connectionId = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? outcome = const $CopyWithPlaceholder(),
  }) {
    return WebullCompletion(
      connectionId: connectionId == const $CopyWithPlaceholder()
          ? _value.connectionId
          // ignore: cast_nullable_to_non_nullable
          : connectionId as String,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      outcome: outcome == const $CopyWithPlaceholder()
          ? _value.outcome
          // ignore: cast_nullable_to_non_nullable
          : outcome as WebullCompletionOutcomeEnum,
    );
  }
}

extension $WebullCompletionCopyWith on WebullCompletion {
  /// Returns a callable class that can be used as follows: `instanceOfWebullCompletion.copyWith(...)` or like so:`instanceOfWebullCompletion.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebullCompletionCWProxy get copyWith => _$WebullCompletionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebullCompletion _$WebullCompletionFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WebullCompletion',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['connection_id', 'created_at', 'outcome'],
        );
        final val = WebullCompletion(
          connectionId: $checkedConvert('connection_id', (v) => v as String),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          outcome: $checkedConvert(
            'outcome',
            (v) => $enumDecode(
              _$WebullCompletionOutcomeEnumEnumMap,
              v,
              unknownValue: WebullCompletionOutcomeEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'connectionId': 'connection_id',
        'createdAt': 'created_at',
      },
    );

Map<String, dynamic> _$WebullCompletionToJson(WebullCompletion instance) =>
    <String, dynamic>{
      'connection_id': instance.connectionId,
      'created_at': instance.createdAt.toIso8601String(),
      'outcome': _$WebullCompletionOutcomeEnumEnumMap[instance.outcome]!,
    };

const _$WebullCompletionOutcomeEnumEnumMap = {
  WebullCompletionOutcomeEnum.connected: 'connected',
  WebullCompletionOutcomeEnum.denied: 'denied',
  WebullCompletionOutcomeEnum.failed: 'failed',
  WebullCompletionOutcomeEnum.temporarilyUnavailable: 'temporarily_unavailable',
  WebullCompletionOutcomeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
