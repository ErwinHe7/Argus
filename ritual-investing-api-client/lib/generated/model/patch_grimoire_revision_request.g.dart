// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_grimoire_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchGrimoireRevisionRequestCWProxy {
  PatchGrimoireRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3 payload,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchGrimoireRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchGrimoireRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchGrimoireRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3 payload,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchGrimoireRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchGrimoireRevisionRequest.copyWith.fieldName(...)`
class _$PatchGrimoireRevisionRequestCWProxyImpl
    implements _$PatchGrimoireRevisionRequestCWProxy {
  const _$PatchGrimoireRevisionRequestCWProxyImpl(this._value);

  final PatchGrimoireRevisionRequest _value;

  @override
  PatchGrimoireRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3 payload,
  ) => this(payload: payload);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchGrimoireRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchGrimoireRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchGrimoireRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
  }) {
    return PatchGrimoireRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3,
    );
  }
}

extension $PatchGrimoireRevisionRequestCopyWith
    on PatchGrimoireRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchGrimoireRevisionRequest.copyWith(...)` or like so:`instanceOfPatchGrimoireRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchGrimoireRevisionRequestCWProxy get copyWith =>
      _$PatchGrimoireRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchGrimoireRevisionRequest _$PatchGrimoireRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchGrimoireRevisionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['payload']);
  final val = PatchGrimoireRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchGrimoireRevisionRequestToJson(
  PatchGrimoireRevisionRequest instance,
) => <String, dynamic>{'payload': instance.payload.toJson()};
