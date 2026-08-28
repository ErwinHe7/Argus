// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_privacy_action_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestPrivacyActionRequestCWProxy {
  RequestPrivacyActionRequest requestType(
    RequestPrivacyActionRequestRequestTypeEnum requestType,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyActionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyActionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyActionRequest call({
    RequestPrivacyActionRequestRequestTypeEnum requestType,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestPrivacyActionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestPrivacyActionRequest.copyWith.fieldName(...)`
class _$RequestPrivacyActionRequestCWProxyImpl
    implements _$RequestPrivacyActionRequestCWProxy {
  const _$RequestPrivacyActionRequestCWProxyImpl(this._value);

  final RequestPrivacyActionRequest _value;

  @override
  RequestPrivacyActionRequest requestType(
    RequestPrivacyActionRequestRequestTypeEnum requestType,
  ) => this(requestType: requestType);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyActionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyActionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyActionRequest call({
    Object? requestType = const $CopyWithPlaceholder(),
  }) {
    return RequestPrivacyActionRequest(
      requestType: requestType == const $CopyWithPlaceholder()
          ? _value.requestType
          // ignore: cast_nullable_to_non_nullable
          : requestType as RequestPrivacyActionRequestRequestTypeEnum,
    );
  }
}

extension $RequestPrivacyActionRequestCopyWith on RequestPrivacyActionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRequestPrivacyActionRequest.copyWith(...)` or like so:`instanceOfRequestPrivacyActionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestPrivacyActionRequestCWProxy get copyWith =>
      _$RequestPrivacyActionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestPrivacyActionRequest _$RequestPrivacyActionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequestPrivacyActionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['requestType']);
  final val = RequestPrivacyActionRequest(
    requestType: $checkedConvert(
      'requestType',
      (v) => $enumDecode(
        _$RequestPrivacyActionRequestRequestTypeEnumEnumMap,
        v,
        unknownValue:
            RequestPrivacyActionRequestRequestTypeEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$RequestPrivacyActionRequestToJson(
  RequestPrivacyActionRequest instance,
) => <String, dynamic>{
  'requestType':
      _$RequestPrivacyActionRequestRequestTypeEnumEnumMap[instance
          .requestType]!,
};

const _$RequestPrivacyActionRequestRequestTypeEnumEnumMap = {
  RequestPrivacyActionRequestRequestTypeEnum.export_: 'export',
  RequestPrivacyActionRequestRequestTypeEnum.deletion: 'deletion',
  RequestPrivacyActionRequestRequestTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
