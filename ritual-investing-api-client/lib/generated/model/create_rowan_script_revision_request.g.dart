// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_rowan_script_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateRowanScriptRevisionRequestCWProxy {
  CreateRowanScriptRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 payload,
  );

  CreateRowanScriptRevisionRequest sourceRevisionId(String sourceRevisionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRowanScriptRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRowanScriptRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRowanScriptRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 payload,
    String sourceRevisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateRowanScriptRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateRowanScriptRevisionRequest.copyWith.fieldName(...)`
class _$CreateRowanScriptRevisionRequestCWProxyImpl
    implements _$CreateRowanScriptRevisionRequestCWProxy {
  const _$CreateRowanScriptRevisionRequestCWProxyImpl(this._value);

  final CreateRowanScriptRevisionRequest _value;

  @override
  CreateRowanScriptRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 payload,
  ) => this(payload: payload);

  @override
  CreateRowanScriptRevisionRequest sourceRevisionId(String sourceRevisionId) =>
      this(sourceRevisionId: sourceRevisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRowanScriptRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRowanScriptRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRowanScriptRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
    Object? sourceRevisionId = const $CopyWithPlaceholder(),
  }) {
    return CreateRowanScriptRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5,
      sourceRevisionId: sourceRevisionId == const $CopyWithPlaceholder()
          ? _value.sourceRevisionId
          // ignore: cast_nullable_to_non_nullable
          : sourceRevisionId as String,
    );
  }
}

extension $CreateRowanScriptRevisionRequestCopyWith
    on CreateRowanScriptRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateRowanScriptRevisionRequest.copyWith(...)` or like so:`instanceOfCreateRowanScriptRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateRowanScriptRevisionRequestCWProxy get copyWith =>
      _$CreateRowanScriptRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateRowanScriptRevisionRequest _$CreateRowanScriptRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateRowanScriptRevisionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['payload', 'source_revision_id']);
  final val = CreateRowanScriptRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
    sourceRevisionId: $checkedConvert('source_revision_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'sourceRevisionId': 'source_revision_id'});

Map<String, dynamic> _$CreateRowanScriptRevisionRequestToJson(
  CreateRowanScriptRevisionRequest instance,
) => <String, dynamic>{
  'payload': instance.payload.toJson(),
  'source_revision_id': instance.sourceRevisionId,
};
