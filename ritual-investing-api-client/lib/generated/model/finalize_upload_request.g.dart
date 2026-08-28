// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finalize_upload_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FinalizeUploadRequestCWProxy {
  FinalizeUploadRequest byteSize(int byteSize);

  FinalizeUploadRequest checksum(String checksum);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeUploadRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeUploadRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeUploadRequest call({int byteSize, String checksum});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFinalizeUploadRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFinalizeUploadRequest.copyWith.fieldName(...)`
class _$FinalizeUploadRequestCWProxyImpl
    implements _$FinalizeUploadRequestCWProxy {
  const _$FinalizeUploadRequestCWProxyImpl(this._value);

  final FinalizeUploadRequest _value;

  @override
  FinalizeUploadRequest byteSize(int byteSize) => this(byteSize: byteSize);

  @override
  FinalizeUploadRequest checksum(String checksum) => this(checksum: checksum);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FinalizeUploadRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FinalizeUploadRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  FinalizeUploadRequest call({
    Object? byteSize = const $CopyWithPlaceholder(),
    Object? checksum = const $CopyWithPlaceholder(),
  }) {
    return FinalizeUploadRequest(
      byteSize: byteSize == const $CopyWithPlaceholder()
          ? _value.byteSize
          // ignore: cast_nullable_to_non_nullable
          : byteSize as int,
      checksum: checksum == const $CopyWithPlaceholder()
          ? _value.checksum
          // ignore: cast_nullable_to_non_nullable
          : checksum as String,
    );
  }
}

extension $FinalizeUploadRequestCopyWith on FinalizeUploadRequest {
  /// Returns a callable class that can be used as follows: `instanceOfFinalizeUploadRequest.copyWith(...)` or like so:`instanceOfFinalizeUploadRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FinalizeUploadRequestCWProxy get copyWith =>
      _$FinalizeUploadRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinalizeUploadRequest _$FinalizeUploadRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FinalizeUploadRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['byteSize', 'checksum']);
  final val = FinalizeUploadRequest(
    byteSize: $checkedConvert('byteSize', (v) => (v as num).toInt()),
    checksum: $checkedConvert('checksum', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$FinalizeUploadRequestToJson(
  FinalizeUploadRequest instance,
) => <String, dynamic>{
  'byteSize': instance.byteSize,
  'checksum': instance.checksum,
};
