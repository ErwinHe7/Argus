// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_circle_template_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateCircleTemplateRevisionRequestCWProxy {
  CreateCircleTemplateRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4 payload,
  );

  CreateCircleTemplateRevisionRequest sourceRevisionId(String sourceRevisionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCircleTemplateRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCircleTemplateRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCircleTemplateRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4 payload,
    String sourceRevisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateCircleTemplateRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateCircleTemplateRevisionRequest.copyWith.fieldName(...)`
class _$CreateCircleTemplateRevisionRequestCWProxyImpl
    implements _$CreateCircleTemplateRevisionRequestCWProxy {
  const _$CreateCircleTemplateRevisionRequestCWProxyImpl(this._value);

  final CreateCircleTemplateRevisionRequest _value;

  @override
  CreateCircleTemplateRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4 payload,
  ) => this(payload: payload);

  @override
  CreateCircleTemplateRevisionRequest sourceRevisionId(
    String sourceRevisionId,
  ) => this(sourceRevisionId: sourceRevisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCircleTemplateRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCircleTemplateRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCircleTemplateRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
    Object? sourceRevisionId = const $CopyWithPlaceholder(),
  }) {
    return CreateCircleTemplateRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4,
      sourceRevisionId: sourceRevisionId == const $CopyWithPlaceholder()
          ? _value.sourceRevisionId
          // ignore: cast_nullable_to_non_nullable
          : sourceRevisionId as String,
    );
  }
}

extension $CreateCircleTemplateRevisionRequestCopyWith
    on CreateCircleTemplateRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateCircleTemplateRevisionRequest.copyWith(...)` or like so:`instanceOfCreateCircleTemplateRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateCircleTemplateRevisionRequestCWProxy get copyWith =>
      _$CreateCircleTemplateRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCircleTemplateRevisionRequest
_$CreateCircleTemplateRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateCircleTemplateRevisionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['payload', 'source_revision_id']);
  final val = CreateCircleTemplateRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
    sourceRevisionId: $checkedConvert('source_revision_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'sourceRevisionId': 'source_revision_id'});

Map<String, dynamic> _$CreateCircleTemplateRevisionRequestToJson(
  CreateCircleTemplateRevisionRequest instance,
) => <String, dynamic>{
  'payload': instance.payload.toJson(),
  'source_revision_id': instance.sourceRevisionId,
};
