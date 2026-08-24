// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_privacy_export_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestPrivacyExportRequestCWProxy {
  RequestPrivacyExportRequest format(
    RequestPrivacyExportRequestFormatEnum format,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyExportRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyExportRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyExportRequest call({
    RequestPrivacyExportRequestFormatEnum format,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestPrivacyExportRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestPrivacyExportRequest.copyWith.fieldName(...)`
class _$RequestPrivacyExportRequestCWProxyImpl
    implements _$RequestPrivacyExportRequestCWProxy {
  const _$RequestPrivacyExportRequestCWProxyImpl(this._value);

  final RequestPrivacyExportRequest _value;

  @override
  RequestPrivacyExportRequest format(
    RequestPrivacyExportRequestFormatEnum format,
  ) => this(format: format);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestPrivacyExportRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestPrivacyExportRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestPrivacyExportRequest call({
    Object? format = const $CopyWithPlaceholder(),
  }) {
    return RequestPrivacyExportRequest(
      format: format == const $CopyWithPlaceholder()
          ? _value.format
          // ignore: cast_nullable_to_non_nullable
          : format as RequestPrivacyExportRequestFormatEnum,
    );
  }
}

extension $RequestPrivacyExportRequestCopyWith on RequestPrivacyExportRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRequestPrivacyExportRequest.copyWith(...)` or like so:`instanceOfRequestPrivacyExportRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestPrivacyExportRequestCWProxy get copyWith =>
      _$RequestPrivacyExportRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestPrivacyExportRequest _$RequestPrivacyExportRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RequestPrivacyExportRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['format']);
  final val = RequestPrivacyExportRequest(
    format: $checkedConvert(
      'format',
      (v) => $enumDecode(
        _$RequestPrivacyExportRequestFormatEnumEnumMap,
        v,
        unknownValue:
            RequestPrivacyExportRequestFormatEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$RequestPrivacyExportRequestToJson(
  RequestPrivacyExportRequest instance,
) => <String, dynamic>{
  'format': _$RequestPrivacyExportRequestFormatEnumEnumMap[instance.format]!,
};

const _$RequestPrivacyExportRequestFormatEnumEnumMap = {
  RequestPrivacyExportRequestFormatEnum.zip: 'zip',
  RequestPrivacyExportRequestFormatEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
