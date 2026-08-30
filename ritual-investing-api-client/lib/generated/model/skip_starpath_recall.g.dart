// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skip_starpath_recall.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkipStarpathRecallCWProxy {
  SkipStarpathRecall sessionId(String sessionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkipStarpathRecall(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkipStarpathRecall(...).copyWith(id: 12, name: "My name")
  /// ````
  SkipStarpathRecall call({String sessionId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSkipStarpathRecall.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSkipStarpathRecall.copyWith.fieldName(...)`
class _$SkipStarpathRecallCWProxyImpl implements _$SkipStarpathRecallCWProxy {
  const _$SkipStarpathRecallCWProxyImpl(this._value);

  final SkipStarpathRecall _value;

  @override
  SkipStarpathRecall sessionId(String sessionId) => this(sessionId: sessionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkipStarpathRecall(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkipStarpathRecall(...).copyWith(id: 12, name: "My name")
  /// ````
  SkipStarpathRecall call({Object? sessionId = const $CopyWithPlaceholder()}) {
    return SkipStarpathRecall(
      sessionId: sessionId == const $CopyWithPlaceholder()
          ? _value.sessionId
          // ignore: cast_nullable_to_non_nullable
          : sessionId as String,
    );
  }
}

extension $SkipStarpathRecallCopyWith on SkipStarpathRecall {
  /// Returns a callable class that can be used as follows: `instanceOfSkipStarpathRecall.copyWith(...)` or like so:`instanceOfSkipStarpathRecall.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SkipStarpathRecallCWProxy get copyWith =>
      _$SkipStarpathRecallCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkipStarpathRecall _$SkipStarpathRecallFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SkipStarpathRecall', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['session_id']);
      final val = SkipStarpathRecall(
        sessionId: $checkedConvert('session_id', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'sessionId': 'session_id'});

Map<String, dynamic> _$SkipStarpathRecallToJson(SkipStarpathRecall instance) =>
    <String, dynamic>{'session_id': instance.sessionId};
