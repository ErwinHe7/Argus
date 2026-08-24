// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_briefing_template_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchBriefingTemplateRevisionRequestCWProxy {
  PatchBriefingTemplateRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 payload,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchBriefingTemplateRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchBriefingTemplateRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchBriefingTemplateRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 payload,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchBriefingTemplateRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchBriefingTemplateRevisionRequest.copyWith.fieldName(...)`
class _$PatchBriefingTemplateRevisionRequestCWProxyImpl
    implements _$PatchBriefingTemplateRevisionRequestCWProxy {
  const _$PatchBriefingTemplateRevisionRequestCWProxyImpl(this._value);

  final PatchBriefingTemplateRevisionRequest _value;

  @override
  PatchBriefingTemplateRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 payload,
  ) => this(payload: payload);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchBriefingTemplateRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchBriefingTemplateRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchBriefingTemplateRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
  }) {
    return PatchBriefingTemplateRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6,
    );
  }
}

extension $PatchBriefingTemplateRevisionRequestCopyWith
    on PatchBriefingTemplateRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchBriefingTemplateRevisionRequest.copyWith(...)` or like so:`instanceOfPatchBriefingTemplateRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchBriefingTemplateRevisionRequestCWProxy get copyWith =>
      _$PatchBriefingTemplateRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchBriefingTemplateRevisionRequest
_$PatchBriefingTemplateRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchBriefingTemplateRevisionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['payload']);
  final val = PatchBriefingTemplateRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchBriefingTemplateRevisionRequestToJson(
  PatchBriefingTemplateRevisionRequest instance,
) => <String, dynamic>{'payload': instance.payload.toJson()};
