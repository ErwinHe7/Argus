// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_coven_entry_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchCovenEntryRevisionRequestCWProxy {
  PatchCovenEntryRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 payload,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchCovenEntryRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchCovenEntryRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchCovenEntryRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 payload,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchCovenEntryRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchCovenEntryRevisionRequest.copyWith.fieldName(...)`
class _$PatchCovenEntryRevisionRequestCWProxyImpl
    implements _$PatchCovenEntryRevisionRequestCWProxy {
  const _$PatchCovenEntryRevisionRequestCWProxyImpl(this._value);

  final PatchCovenEntryRevisionRequest _value;

  @override
  PatchCovenEntryRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 payload,
  ) => this(payload: payload);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchCovenEntryRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchCovenEntryRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchCovenEntryRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
  }) {
    return PatchCovenEntryRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2,
    );
  }
}

extension $PatchCovenEntryRevisionRequestCopyWith
    on PatchCovenEntryRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchCovenEntryRevisionRequest.copyWith(...)` or like so:`instanceOfPatchCovenEntryRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchCovenEntryRevisionRequestCWProxy get copyWith =>
      _$PatchCovenEntryRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchCovenEntryRevisionRequest _$PatchCovenEntryRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchCovenEntryRevisionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['payload']);
  final val = PatchCovenEntryRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchCovenEntryRevisionRequestToJson(
  PatchCovenEntryRevisionRequest instance,
) => <String, dynamic>{'payload': instance.payload.toJson()};
