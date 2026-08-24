// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_media_upload_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CompleteMediaUploadRequestCWProxy {
  CompleteMediaUploadRequest checksum(String checksum);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CompleteMediaUploadRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CompleteMediaUploadRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CompleteMediaUploadRequest call({String checksum});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCompleteMediaUploadRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCompleteMediaUploadRequest.copyWith.fieldName(...)`
class _$CompleteMediaUploadRequestCWProxyImpl
    implements _$CompleteMediaUploadRequestCWProxy {
  const _$CompleteMediaUploadRequestCWProxyImpl(this._value);

  final CompleteMediaUploadRequest _value;

  @override
  CompleteMediaUploadRequest checksum(String checksum) =>
      this(checksum: checksum);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CompleteMediaUploadRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CompleteMediaUploadRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CompleteMediaUploadRequest call({
    Object? checksum = const $CopyWithPlaceholder(),
  }) {
    return CompleteMediaUploadRequest(
      checksum: checksum == const $CopyWithPlaceholder()
          ? _value.checksum
          // ignore: cast_nullable_to_non_nullable
          : checksum as String,
    );
  }
}

extension $CompleteMediaUploadRequestCopyWith on CompleteMediaUploadRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCompleteMediaUploadRequest.copyWith(...)` or like so:`instanceOfCompleteMediaUploadRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CompleteMediaUploadRequestCWProxy get copyWith =>
      _$CompleteMediaUploadRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompleteMediaUploadRequest _$CompleteMediaUploadRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CompleteMediaUploadRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['checksum']);
  final val = CompleteMediaUploadRequest(
    checksum: $checkedConvert('checksum', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$CompleteMediaUploadRequestToJson(
  CompleteMediaUploadRequest instance,
) => <String, dynamic>{'checksum': instance.checksum};
