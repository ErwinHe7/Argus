// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reset_demo_state_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ResetDemoStateRequestCWProxy {
  ResetDemoStateRequest confirmation(
    ResetDemoStateRequestConfirmationEnum confirmation,
  );

  ResetDemoStateRequest seedVersion(int seedVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ResetDemoStateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ResetDemoStateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ResetDemoStateRequest call({
    ResetDemoStateRequestConfirmationEnum confirmation,
    int seedVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfResetDemoStateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfResetDemoStateRequest.copyWith.fieldName(...)`
class _$ResetDemoStateRequestCWProxyImpl
    implements _$ResetDemoStateRequestCWProxy {
  const _$ResetDemoStateRequestCWProxyImpl(this._value);

  final ResetDemoStateRequest _value;

  @override
  ResetDemoStateRequest confirmation(
    ResetDemoStateRequestConfirmationEnum confirmation,
  ) => this(confirmation: confirmation);

  @override
  ResetDemoStateRequest seedVersion(int seedVersion) =>
      this(seedVersion: seedVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ResetDemoStateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ResetDemoStateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ResetDemoStateRequest call({
    Object? confirmation = const $CopyWithPlaceholder(),
    Object? seedVersion = const $CopyWithPlaceholder(),
  }) {
    return ResetDemoStateRequest(
      confirmation: confirmation == const $CopyWithPlaceholder()
          ? _value.confirmation
          // ignore: cast_nullable_to_non_nullable
          : confirmation as ResetDemoStateRequestConfirmationEnum,
      seedVersion: seedVersion == const $CopyWithPlaceholder()
          ? _value.seedVersion
          // ignore: cast_nullable_to_non_nullable
          : seedVersion as int,
    );
  }
}

extension $ResetDemoStateRequestCopyWith on ResetDemoStateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfResetDemoStateRequest.copyWith(...)` or like so:`instanceOfResetDemoStateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ResetDemoStateRequestCWProxy get copyWith =>
      _$ResetDemoStateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResetDemoStateRequest _$ResetDemoStateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ResetDemoStateRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['confirmation', 'seed_version']);
  final val = ResetDemoStateRequest(
    confirmation: $checkedConvert(
      'confirmation',
      (v) => $enumDecode(
        _$ResetDemoStateRequestConfirmationEnumEnumMap,
        v,
        unknownValue:
            ResetDemoStateRequestConfirmationEnum.unknownDefaultOpenApi,
      ),
    ),
    seedVersion: $checkedConvert('seed_version', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'seedVersion': 'seed_version'});

Map<String, dynamic> _$ResetDemoStateRequestToJson(
  ResetDemoStateRequest instance,
) => <String, dynamic>{
  'confirmation':
      _$ResetDemoStateRequestConfirmationEnumEnumMap[instance.confirmation]!,
  'seed_version': instance.seedVersion,
};

const _$ResetDemoStateRequestConfirmationEnumEnumMap = {
  ResetDemoStateRequestConfirmationEnum.RESET_DEMO: 'RESET_DEMO',
  ResetDemoStateRequestConfirmationEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
