// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_circle_template_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchCircleTemplateRevisionRequestCWProxy {
  PatchCircleTemplateRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4 payload,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchCircleTemplateRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchCircleTemplateRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchCircleTemplateRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4 payload,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchCircleTemplateRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchCircleTemplateRevisionRequest.copyWith.fieldName(...)`
class _$PatchCircleTemplateRevisionRequestCWProxyImpl
    implements _$PatchCircleTemplateRevisionRequestCWProxy {
  const _$PatchCircleTemplateRevisionRequestCWProxyImpl(this._value);

  final PatchCircleTemplateRevisionRequest _value;

  @override
  PatchCircleTemplateRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4 payload,
  ) => this(payload: payload);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchCircleTemplateRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchCircleTemplateRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchCircleTemplateRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
  }) {
    return PatchCircleTemplateRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4,
    );
  }
}

extension $PatchCircleTemplateRevisionRequestCopyWith
    on PatchCircleTemplateRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchCircleTemplateRevisionRequest.copyWith(...)` or like so:`instanceOfPatchCircleTemplateRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchCircleTemplateRevisionRequestCWProxy get copyWith =>
      _$PatchCircleTemplateRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchCircleTemplateRevisionRequest _$PatchCircleTemplateRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchCircleTemplateRevisionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['payload']);
  final val = PatchCircleTemplateRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchCircleTemplateRevisionRequestToJson(
  PatchCircleTemplateRevisionRequest instance,
) => <String, dynamic>{'payload': instance.payload.toJson()};
