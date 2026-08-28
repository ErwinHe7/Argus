// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_privacy_action_request_one_of.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestPrivacyActionRequestOneOfCWProxy {
  RequestPrivacyActionRequestOneOf requestType(
    RequestPrivacyActionRequestOneOfRequestTypeEnum requestType,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyActionRequestOneOf(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyActionRequestOneOf(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyActionRequestOneOf call({
    RequestPrivacyActionRequestOneOfRequestTypeEnum requestType,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestPrivacyActionRequestOneOf.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestPrivacyActionRequestOneOf.copyWith.fieldName(...)`
class _$RequestPrivacyActionRequestOneOfCWProxyImpl
    implements _$RequestPrivacyActionRequestOneOfCWProxy {
  const _$RequestPrivacyActionRequestOneOfCWProxyImpl(this._value);

  final RequestPrivacyActionRequestOneOf _value;

  @override
  RequestPrivacyActionRequestOneOf requestType(
    RequestPrivacyActionRequestOneOfRequestTypeEnum requestType,
  ) => this(requestType: requestType);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyActionRequestOneOf(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyActionRequestOneOf(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyActionRequestOneOf call({
    Object? requestType = const $CopyWithPlaceholder(),
  }) {
    return RequestPrivacyActionRequestOneOf(
      requestType: requestType == const $CopyWithPlaceholder()
          ? _value.requestType
          // ignore: cast_nullable_to_non_nullable
          : requestType as RequestPrivacyActionRequestOneOfRequestTypeEnum,
    );
  }
}

extension $RequestPrivacyActionRequestOneOfCopyWith
    on RequestPrivacyActionRequestOneOf {
  /// Returns a callable class that can be used as follows: `instanceOfRequestPrivacyActionRequestOneOf.copyWith(...)` or like so:`instanceOfRequestPrivacyActionRequestOneOf.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestPrivacyActionRequestOneOfCWProxy get copyWith =>
      _$RequestPrivacyActionRequestOneOfCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestPrivacyActionRequestOneOf _$RequestPrivacyActionRequestOneOfFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('RequestPrivacyActionRequestOneOf', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['requestType']);
      final val = RequestPrivacyActionRequestOneOf(
        requestType: $checkedConvert(
          'requestType',
          (v) => $enumDecode(
            _$RequestPrivacyActionRequestOneOfRequestTypeEnumEnumMap,
            v,
            unknownValue: RequestPrivacyActionRequestOneOfRequestTypeEnum
                .unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$RequestPrivacyActionRequestOneOfToJson(
  RequestPrivacyActionRequestOneOf instance,
) => <String, dynamic>{
  'requestType':
      _$RequestPrivacyActionRequestOneOfRequestTypeEnumEnumMap[instance
          .requestType]!,
};

const _$RequestPrivacyActionRequestOneOfRequestTypeEnumEnumMap = {
  RequestPrivacyActionRequestOneOfRequestTypeEnum.export_: 'export',
  RequestPrivacyActionRequestOneOfRequestTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
