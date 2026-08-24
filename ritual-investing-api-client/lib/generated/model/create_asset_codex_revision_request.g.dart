// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_asset_codex_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAssetCodexRevisionRequestCWProxy {
  CreateAssetCodexRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1 payload,
  );

  CreateAssetCodexRevisionRequest sourceRevisionId(String sourceRevisionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAssetCodexRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAssetCodexRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAssetCodexRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1 payload,
    String sourceRevisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAssetCodexRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAssetCodexRevisionRequest.copyWith.fieldName(...)`
class _$CreateAssetCodexRevisionRequestCWProxyImpl
    implements _$CreateAssetCodexRevisionRequestCWProxy {
  const _$CreateAssetCodexRevisionRequestCWProxyImpl(this._value);

  final CreateAssetCodexRevisionRequest _value;

  @override
  CreateAssetCodexRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1 payload,
  ) => this(payload: payload);

  @override
  CreateAssetCodexRevisionRequest sourceRevisionId(String sourceRevisionId) =>
      this(sourceRevisionId: sourceRevisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAssetCodexRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAssetCodexRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAssetCodexRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
    Object? sourceRevisionId = const $CopyWithPlaceholder(),
  }) {
    return CreateAssetCodexRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1,
      sourceRevisionId: sourceRevisionId == const $CopyWithPlaceholder()
          ? _value.sourceRevisionId
          // ignore: cast_nullable_to_non_nullable
          : sourceRevisionId as String,
    );
  }
}

extension $CreateAssetCodexRevisionRequestCopyWith
    on CreateAssetCodexRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAssetCodexRevisionRequest.copyWith(...)` or like so:`instanceOfCreateAssetCodexRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAssetCodexRevisionRequestCWProxy get copyWith =>
      _$CreateAssetCodexRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAssetCodexRevisionRequest _$CreateAssetCodexRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateAssetCodexRevisionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['payload', 'source_revision_id']);
  final val = CreateAssetCodexRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
    sourceRevisionId: $checkedConvert('source_revision_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'sourceRevisionId': 'source_revision_id'});

Map<String, dynamic> _$CreateAssetCodexRevisionRequestToJson(
  CreateAssetCodexRevisionRequest instance,
) => <String, dynamic>{
  'payload': instance.payload.toJson(),
  'source_revision_id': instance.sourceRevisionId,
};
