// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transition_ritual_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TransitionRitualRequestCWProxy {
  TransitionRitualRequest from(TransitionRitualRequestFromEnum from);

  TransitionRitualRequest to(TransitionRitualRequestToEnum to);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TransitionRitualRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TransitionRitualRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TransitionRitualRequest call({
    TransitionRitualRequestFromEnum from,
    TransitionRitualRequestToEnum to,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTransitionRitualRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTransitionRitualRequest.copyWith.fieldName(...)`
class _$TransitionRitualRequestCWProxyImpl
    implements _$TransitionRitualRequestCWProxy {
  const _$TransitionRitualRequestCWProxyImpl(this._value);

  final TransitionRitualRequest _value;

  @override
  TransitionRitualRequest from(TransitionRitualRequestFromEnum from) =>
      this(from: from);

  @override
  TransitionRitualRequest to(TransitionRitualRequestToEnum to) => this(to: to);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TransitionRitualRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TransitionRitualRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TransitionRitualRequest call({
    Object? from = const $CopyWithPlaceholder(),
    Object? to = const $CopyWithPlaceholder(),
  }) {
    return TransitionRitualRequest(
      from: from == const $CopyWithPlaceholder()
          ? _value.from
          // ignore: cast_nullable_to_non_nullable
          : from as TransitionRitualRequestFromEnum,
      to: to == const $CopyWithPlaceholder()
          ? _value.to
          // ignore: cast_nullable_to_non_nullable
          : to as TransitionRitualRequestToEnum,
    );
  }
}

extension $TransitionRitualRequestCopyWith on TransitionRitualRequest {
  /// Returns a callable class that can be used as follows: `instanceOfTransitionRitualRequest.copyWith(...)` or like so:`instanceOfTransitionRitualRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TransitionRitualRequestCWProxy get copyWith =>
      _$TransitionRitualRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransitionRitualRequest _$TransitionRitualRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('TransitionRitualRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['from', 'to']);
  final val = TransitionRitualRequest(
    from: $checkedConvert(
      'from',
      (v) => $enumDecode(
        _$TransitionRitualRequestFromEnumEnumMap,
        v,
        unknownValue: TransitionRitualRequestFromEnum.unknownDefaultOpenApi,
      ),
    ),
    to: $checkedConvert(
      'to',
      (v) => $enumDecode(
        _$TransitionRitualRequestToEnumEnumMap,
        v,
        unknownValue: TransitionRitualRequestToEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$TransitionRitualRequestToJson(
  TransitionRitualRequest instance,
) => <String, dynamic>{
  'from': _$TransitionRitualRequestFromEnumEnumMap[instance.from]!,
  'to': _$TransitionRitualRequestToEnumEnumMap[instance.to]!,
};

const _$TransitionRitualRequestFromEnumEnumMap = {
  TransitionRitualRequestFromEnum.assigned: 'assigned',
  TransitionRitualRequestFromEnum.revealed: 'revealed',
  TransitionRitualRequestFromEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$TransitionRitualRequestToEnumEnumMap = {
  TransitionRitualRequestToEnum.revealed: 'revealed',
  TransitionRitualRequestToEnum.completed: 'completed',
  TransitionRitualRequestToEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
