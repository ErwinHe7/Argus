// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_asset_codex_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchAssetCodexRevisionRequestCWProxy {
  PatchAssetCodexRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1 payload,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAssetCodexRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAssetCodexRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAssetCodexRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1 payload,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchAssetCodexRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchAssetCodexRevisionRequest.copyWith.fieldName(...)`
class _$PatchAssetCodexRevisionRequestCWProxyImpl
    implements _$PatchAssetCodexRevisionRequestCWProxy {
  const _$PatchAssetCodexRevisionRequestCWProxyImpl(this._value);

  final PatchAssetCodexRevisionRequest _value;

  @override
  PatchAssetCodexRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1 payload,
  ) => this(payload: payload);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAssetCodexRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAssetCodexRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAssetCodexRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
  }) {
    return PatchAssetCodexRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1,
    );
  }
}

extension $PatchAssetCodexRevisionRequestCopyWith
    on PatchAssetCodexRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchAssetCodexRevisionRequest.copyWith(...)` or like so:`instanceOfPatchAssetCodexRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchAssetCodexRevisionRequestCWProxy get copyWith =>
      _$PatchAssetCodexRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchAssetCodexRevisionRequest _$PatchAssetCodexRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchAssetCodexRevisionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['payload']);
  final val = PatchAssetCodexRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchAssetCodexRevisionRequestToJson(
  PatchAssetCodexRevisionRequest instance,
) => <String, dynamic>{'payload': instance.payload.toJson()};
