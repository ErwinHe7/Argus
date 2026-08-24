// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_briefing_template_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateBriefingTemplateRevisionRequestCWProxy {
  CreateBriefingTemplateRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 payload,
  );

  CreateBriefingTemplateRevisionRequest sourceRevisionId(
    String sourceRevisionId,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateBriefingTemplateRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateBriefingTemplateRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateBriefingTemplateRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 payload,
    String sourceRevisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateBriefingTemplateRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateBriefingTemplateRevisionRequest.copyWith.fieldName(...)`
class _$CreateBriefingTemplateRevisionRequestCWProxyImpl
    implements _$CreateBriefingTemplateRevisionRequestCWProxy {
  const _$CreateBriefingTemplateRevisionRequestCWProxyImpl(this._value);

  final CreateBriefingTemplateRevisionRequest _value;

  @override
  CreateBriefingTemplateRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 payload,
  ) => this(payload: payload);

  @override
  CreateBriefingTemplateRevisionRequest sourceRevisionId(
    String sourceRevisionId,
  ) => this(sourceRevisionId: sourceRevisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateBriefingTemplateRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateBriefingTemplateRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateBriefingTemplateRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
    Object? sourceRevisionId = const $CopyWithPlaceholder(),
  }) {
    return CreateBriefingTemplateRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6,
      sourceRevisionId: sourceRevisionId == const $CopyWithPlaceholder()
          ? _value.sourceRevisionId
          // ignore: cast_nullable_to_non_nullable
          : sourceRevisionId as String,
    );
  }
}

extension $CreateBriefingTemplateRevisionRequestCopyWith
    on CreateBriefingTemplateRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateBriefingTemplateRevisionRequest.copyWith(...)` or like so:`instanceOfCreateBriefingTemplateRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateBriefingTemplateRevisionRequestCWProxy get copyWith =>
      _$CreateBriefingTemplateRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateBriefingTemplateRevisionRequest
_$CreateBriefingTemplateRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateBriefingTemplateRevisionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['payload', 'source_revision_id']);
  final val = CreateBriefingTemplateRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
    sourceRevisionId: $checkedConvert('source_revision_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'sourceRevisionId': 'source_revision_id'});

Map<String, dynamic> _$CreateBriefingTemplateRevisionRequestToJson(
  CreateBriefingTemplateRevisionRequest instance,
) => <String, dynamic>{
  'payload': instance.payload.toJson(),
  'source_revision_id': instance.sourceRevisionId,
};
