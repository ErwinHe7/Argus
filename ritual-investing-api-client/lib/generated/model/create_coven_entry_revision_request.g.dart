// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_coven_entry_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateCovenEntryRevisionRequestCWProxy {
  CreateCovenEntryRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 payload,
  );

  CreateCovenEntryRevisionRequest sourceRevisionId(String sourceRevisionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCovenEntryRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCovenEntryRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCovenEntryRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 payload,
    String sourceRevisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateCovenEntryRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateCovenEntryRevisionRequest.copyWith.fieldName(...)`
class _$CreateCovenEntryRevisionRequestCWProxyImpl
    implements _$CreateCovenEntryRevisionRequestCWProxy {
  const _$CreateCovenEntryRevisionRequestCWProxyImpl(this._value);

  final CreateCovenEntryRevisionRequest _value;

  @override
  CreateCovenEntryRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2 payload,
  ) => this(payload: payload);

  @override
  CreateCovenEntryRevisionRequest sourceRevisionId(String sourceRevisionId) =>
      this(sourceRevisionId: sourceRevisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCovenEntryRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCovenEntryRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCovenEntryRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
    Object? sourceRevisionId = const $CopyWithPlaceholder(),
  }) {
    return CreateCovenEntryRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2,
      sourceRevisionId: sourceRevisionId == const $CopyWithPlaceholder()
          ? _value.sourceRevisionId
          // ignore: cast_nullable_to_non_nullable
          : sourceRevisionId as String,
    );
  }
}

extension $CreateCovenEntryRevisionRequestCopyWith
    on CreateCovenEntryRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateCovenEntryRevisionRequest.copyWith(...)` or like so:`instanceOfCreateCovenEntryRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateCovenEntryRevisionRequestCWProxy get copyWith =>
      _$CreateCovenEntryRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCovenEntryRevisionRequest _$CreateCovenEntryRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateCovenEntryRevisionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['payload', 'source_revision_id']);
  final val = CreateCovenEntryRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf2.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
    sourceRevisionId: $checkedConvert('source_revision_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'sourceRevisionId': 'source_revision_id'});

Map<String, dynamic> _$CreateCovenEntryRevisionRequestToJson(
  CreateCovenEntryRevisionRequest instance,
) => <String, dynamic>{
  'payload': instance.payload.toJson(),
  'source_revision_id': instance.sourceRevisionId,
};
