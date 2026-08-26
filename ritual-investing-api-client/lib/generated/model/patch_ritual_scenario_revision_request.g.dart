// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_ritual_scenario_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchRitualScenarioRevisionRequestCWProxy {
  PatchRitualScenarioRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf payload,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchRitualScenarioRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchRitualScenarioRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchRitualScenarioRevisionRequest call({
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf payload,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchRitualScenarioRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchRitualScenarioRevisionRequest.copyWith.fieldName(...)`
class _$PatchRitualScenarioRevisionRequestCWProxyImpl
    implements _$PatchRitualScenarioRevisionRequestCWProxy {
  const _$PatchRitualScenarioRevisionRequestCWProxyImpl(this._value);

  final PatchRitualScenarioRevisionRequest _value;

  @override
  PatchRitualScenarioRevisionRequest payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf payload,
  ) => this(payload: payload);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchRitualScenarioRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchRitualScenarioRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchRitualScenarioRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
  }) {
    return PatchRitualScenarioRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf,
    );
  }
}

extension $PatchRitualScenarioRevisionRequestCopyWith
    on PatchRitualScenarioRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchRitualScenarioRevisionRequest.copyWith(...)` or like so:`instanceOfPatchRitualScenarioRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchRitualScenarioRevisionRequestCWProxy get copyWith =>
      _$PatchRitualScenarioRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchRitualScenarioRevisionRequest _$PatchRitualScenarioRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchRitualScenarioRevisionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['payload']);
  final val = PatchRitualScenarioRevisionRequest(
    payload: $checkedConvert(
      'payload',
      (v) =>
          ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf.fromJson(
            v as Map<String, dynamic>,
          ),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchRitualScenarioRevisionRequestToJson(
  PatchRitualScenarioRevisionRequest instance,
) => <String, dynamic>{'payload': instance.payload.toJson()};
