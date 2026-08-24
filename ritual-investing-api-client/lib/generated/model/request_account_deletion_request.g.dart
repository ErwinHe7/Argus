// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_account_deletion_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestAccountDeletionRequestCWProxy {
  RequestAccountDeletionRequest confirmation(
    RequestAccountDeletionRequestConfirmationEnum confirmation,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestAccountDeletionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestAccountDeletionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestAccountDeletionRequest call({
    RequestAccountDeletionRequestConfirmationEnum confirmation,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestAccountDeletionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestAccountDeletionRequest.copyWith.fieldName(...)`
class _$RequestAccountDeletionRequestCWProxyImpl
    implements _$RequestAccountDeletionRequestCWProxy {
  const _$RequestAccountDeletionRequestCWProxyImpl(this._value);

  final RequestAccountDeletionRequest _value;

  @override
  RequestAccountDeletionRequest confirmation(
    RequestAccountDeletionRequestConfirmationEnum confirmation,
  ) => this(confirmation: confirmation);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestAccountDeletionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestAccountDeletionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestAccountDeletionRequest call({
    Object? confirmation = const $CopyWithPlaceholder(),
  }) {
    return RequestAccountDeletionRequest(
      confirmation: confirmation == const $CopyWithPlaceholder()
          ? _value.confirmation
          // ignore: cast_nullable_to_non_nullable
          : confirmation as RequestAccountDeletionRequestConfirmationEnum,
    );
  }
}

extension $RequestAccountDeletionRequestCopyWith
    on RequestAccountDeletionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRequestAccountDeletionRequest.copyWith(...)` or like so:`instanceOfRequestAccountDeletionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestAccountDeletionRequestCWProxy get copyWith =>
      _$RequestAccountDeletionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestAccountDeletionRequest _$RequestAccountDeletionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequestAccountDeletionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['confirmation']);
  final val = RequestAccountDeletionRequest(
    confirmation: $checkedConvert(
      'confirmation',
      (v) => $enumDecode(
        _$RequestAccountDeletionRequestConfirmationEnumEnumMap,
        v,
        unknownValue:
            RequestAccountDeletionRequestConfirmationEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$RequestAccountDeletionRequestToJson(
  RequestAccountDeletionRequest instance,
) => <String, dynamic>{
  'confirmation':
      _$RequestAccountDeletionRequestConfirmationEnumEnumMap[instance
          .confirmation]!,
};

const _$RequestAccountDeletionRequestConfirmationEnumEnumMap = {
  RequestAccountDeletionRequestConfirmationEnum.DELETE: 'DELETE',
  RequestAccountDeletionRequestConfirmationEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
