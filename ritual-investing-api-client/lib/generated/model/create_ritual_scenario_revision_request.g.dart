// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_ritual_scenario_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateRitualScenarioRevisionRequestCWProxy {
  CreateRitualScenarioRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf payload,
  );

  CreateRitualScenarioRevisionRequest sourceRevisionId(String sourceRevisionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRitualScenarioRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRitualScenarioRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRitualScenarioRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf payload,
    String sourceRevisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateRitualScenarioRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateRitualScenarioRevisionRequest.copyWith.fieldName(...)`
class _$CreateRitualScenarioRevisionRequestCWProxyImpl
    implements _$CreateRitualScenarioRevisionRequestCWProxy {
  const _$CreateRitualScenarioRevisionRequestCWProxyImpl(this._value);

  final CreateRitualScenarioRevisionRequest _value;

  @override
  CreateRitualScenarioRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf payload,
  ) => this(payload: payload);

  @override
  CreateRitualScenarioRevisionRequest sourceRevisionId(
    String sourceRevisionId,
  ) => this(sourceRevisionId: sourceRevisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRitualScenarioRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRitualScenarioRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRitualScenarioRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
    Object? sourceRevisionId = const $CopyWithPlaceholder(),
  }) {
    return CreateRitualScenarioRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf,
      sourceRevisionId: sourceRevisionId == const $CopyWithPlaceholder()
          ? _value.sourceRevisionId
          // ignore: cast_nullable_to_non_nullable
          : sourceRevisionId as String,
    );
  }
}

extension $CreateRitualScenarioRevisionRequestCopyWith
    on CreateRitualScenarioRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateRitualScenarioRevisionRequest.copyWith(...)` or like so:`instanceOfCreateRitualScenarioRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateRitualScenarioRevisionRequestCWProxy get copyWith =>
      _$CreateRitualScenarioRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateRitualScenarioRevisionRequest
_$CreateRitualScenarioRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateRitualScenarioRevisionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['payload', 'source_revision_id']);
  final val = CreateRitualScenarioRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
    sourceRevisionId: $checkedConvert('source_revision_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'sourceRevisionId': 'source_revision_id'});

Map<String, dynamic> _$CreateRitualScenarioRevisionRequestToJson(
  CreateRitualScenarioRevisionRequest instance,
) => <String, dynamic>{
  'payload': instance.payload.toJson(),
  'source_revision_id': instance.sourceRevisionId,
};
