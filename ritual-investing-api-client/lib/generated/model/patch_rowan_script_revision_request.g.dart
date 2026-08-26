// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_rowan_script_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchRowanScriptRevisionRequestCWProxy {
  PatchRowanScriptRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 payload,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchRowanScriptRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchRowanScriptRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchRowanScriptRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 payload,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchRowanScriptRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchRowanScriptRevisionRequest.copyWith.fieldName(...)`
class _$PatchRowanScriptRevisionRequestCWProxyImpl
    implements _$PatchRowanScriptRevisionRequestCWProxy {
  const _$PatchRowanScriptRevisionRequestCWProxyImpl(this._value);

  final PatchRowanScriptRevisionRequest _value;

  @override
  PatchRowanScriptRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 payload,
  ) => this(payload: payload);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchRowanScriptRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchRowanScriptRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchRowanScriptRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
  }) {
    return PatchRowanScriptRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5,
    );
  }
}

extension $PatchRowanScriptRevisionRequestCopyWith
    on PatchRowanScriptRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchRowanScriptRevisionRequest.copyWith(...)` or like so:`instanceOfPatchRowanScriptRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchRowanScriptRevisionRequestCWProxy get copyWith =>
      _$PatchRowanScriptRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchRowanScriptRevisionRequest _$PatchRowanScriptRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchRowanScriptRevisionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['payload']);
  final val = PatchRowanScriptRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchRowanScriptRevisionRequestToJson(
  PatchRowanScriptRevisionRequest instance,
) => <String, dynamic>{'payload': instance.payload.toJson()};
