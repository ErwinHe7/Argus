// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_grimoire_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateGrimoireRevisionRequestCWProxy {
  CreateGrimoireRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3 payload,
  );

  CreateGrimoireRevisionRequest sourceRevisionId(String sourceRevisionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateGrimoireRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateGrimoireRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateGrimoireRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3 payload,
    String sourceRevisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateGrimoireRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateGrimoireRevisionRequest.copyWith.fieldName(...)`
class _$CreateGrimoireRevisionRequestCWProxyImpl
    implements _$CreateGrimoireRevisionRequestCWProxy {
  const _$CreateGrimoireRevisionRequestCWProxyImpl(this._value);

  final CreateGrimoireRevisionRequest _value;

  @override
  CreateGrimoireRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3 payload,
  ) => this(payload: payload);

  @override
  CreateGrimoireRevisionRequest sourceRevisionId(String sourceRevisionId) =>
      this(sourceRevisionId: sourceRevisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateGrimoireRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateGrimoireRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateGrimoireRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
    Object? sourceRevisionId = const $CopyWithPlaceholder(),
  }) {
    return CreateGrimoireRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3,
      sourceRevisionId: sourceRevisionId == const $CopyWithPlaceholder()
          ? _value.sourceRevisionId
          // ignore: cast_nullable_to_non_nullable
          : sourceRevisionId as String,
    );
  }
}

extension $CreateGrimoireRevisionRequestCopyWith
    on CreateGrimoireRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateGrimoireRevisionRequest.copyWith(...)` or like so:`instanceOfCreateGrimoireRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateGrimoireRevisionRequestCWProxy get copyWith =>
      _$CreateGrimoireRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateGrimoireRevisionRequest _$CreateGrimoireRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateGrimoireRevisionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['payload', 'source_revision_id']);
  final val = CreateGrimoireRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
    sourceRevisionId: $checkedConvert('source_revision_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'sourceRevisionId': 'source_revision_id'});

Map<String, dynamic> _$CreateGrimoireRevisionRequestToJson(
  CreateGrimoireRevisionRequest instance,
) => <String, dynamic>{
  'payload': instance.payload.toJson(),
  'source_revision_id': instance.sourceRevisionId,
};
