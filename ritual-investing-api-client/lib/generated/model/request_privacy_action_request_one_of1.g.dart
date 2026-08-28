// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_privacy_action_request_one_of1.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestPrivacyActionRequestOneOf1CWProxy {
  RequestPrivacyActionRequestOneOf1 requestType(
    RequestPrivacyActionRequestOneOf1RequestTypeEnum requestType,
  );

  RequestPrivacyActionRequestOneOf1 stepUpReceipt(String stepUpReceipt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyActionRequestOneOf1(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyActionRequestOneOf1(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyActionRequestOneOf1 call({
    RequestPrivacyActionRequestOneOf1RequestTypeEnum requestType,
    String stepUpReceipt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestPrivacyActionRequestOneOf1.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestPrivacyActionRequestOneOf1.copyWith.fieldName(...)`
class _$RequestPrivacyActionRequestOneOf1CWProxyImpl
    implements _$RequestPrivacyActionRequestOneOf1CWProxy {
  const _$RequestPrivacyActionRequestOneOf1CWProxyImpl(this._value);

  final RequestPrivacyActionRequestOneOf1 _value;

  @override
  RequestPrivacyActionRequestOneOf1 requestType(
    RequestPrivacyActionRequestOneOf1RequestTypeEnum requestType,
  ) => this(requestType: requestType);

  @override
  RequestPrivacyActionRequestOneOf1 stepUpReceipt(String stepUpReceipt) =>
      this(stepUpReceipt: stepUpReceipt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyActionRequestOneOf1(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyActionRequestOneOf1(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyActionRequestOneOf1 call({
    Object? requestType = const $CopyWithPlaceholder(),
    Object? stepUpReceipt = const $CopyWithPlaceholder(),
  }) {
    return RequestPrivacyActionRequestOneOf1(
      requestType: requestType == const $CopyWithPlaceholder()
          ? _value.requestType
          // ignore: cast_nullable_to_non_nullable
          : requestType as RequestPrivacyActionRequestOneOf1RequestTypeEnum,
      stepUpReceipt: stepUpReceipt == const $CopyWithPlaceholder()
          ? _value.stepUpReceipt
          // ignore: cast_nullable_to_non_nullable
          : stepUpReceipt as String,
    );
  }
}

extension $RequestPrivacyActionRequestOneOf1CopyWith
    on RequestPrivacyActionRequestOneOf1 {
  /// Returns a callable class that can be used as follows: `instanceOfRequestPrivacyActionRequestOneOf1.copyWith(...)` or like so:`instanceOfRequestPrivacyActionRequestOneOf1.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestPrivacyActionRequestOneOf1CWProxy get copyWith =>
      _$RequestPrivacyActionRequestOneOf1CWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestPrivacyActionRequestOneOf1 _$RequestPrivacyActionRequestOneOf1FromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequestPrivacyActionRequestOneOf1', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['requestType', 'step_up_receipt']);
  final val = RequestPrivacyActionRequestOneOf1(
    requestType: $checkedConvert(
      'requestType',
      (v) => $enumDecode(
        _$RequestPrivacyActionRequestOneOf1RequestTypeEnumEnumMap,
        v,
        unknownValue: RequestPrivacyActionRequestOneOf1RequestTypeEnum
            .unknownDefaultOpenApi,
      ),
    ),
    stepUpReceipt: $checkedConvert('step_up_receipt', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'stepUpReceipt': 'step_up_receipt'});

Map<String, dynamic> _$RequestPrivacyActionRequestOneOf1ToJson(
  RequestPrivacyActionRequestOneOf1 instance,
) => <String, dynamic>{
  'requestType':
      _$RequestPrivacyActionRequestOneOf1RequestTypeEnumEnumMap[instance
          .requestType]!,
  'step_up_receipt': instance.stepUpReceipt,
};

const _$RequestPrivacyActionRequestOneOf1RequestTypeEnumEnumMap = {
  RequestPrivacyActionRequestOneOf1RequestTypeEnum.deletion: 'deletion',
  RequestPrivacyActionRequestOneOf1RequestTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
