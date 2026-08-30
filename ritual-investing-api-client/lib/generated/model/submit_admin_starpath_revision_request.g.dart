// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'submit_admin_starpath_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SubmitAdminStarpathRevisionRequestCWProxy {
  SubmitAdminStarpathRevisionRequest policyVersion(String policyVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SubmitAdminStarpathRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SubmitAdminStarpathRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SubmitAdminStarpathRevisionRequest call({String policyVersion});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSubmitAdminStarpathRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSubmitAdminStarpathRevisionRequest.copyWith.fieldName(...)`
class _$SubmitAdminStarpathRevisionRequestCWProxyImpl
    implements _$SubmitAdminStarpathRevisionRequestCWProxy {
  const _$SubmitAdminStarpathRevisionRequestCWProxyImpl(this._value);

  final SubmitAdminStarpathRevisionRequest _value;

  @override
  SubmitAdminStarpathRevisionRequest policyVersion(String policyVersion) =>
      this(policyVersion: policyVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SubmitAdminStarpathRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SubmitAdminStarpathRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SubmitAdminStarpathRevisionRequest call({
    Object? policyVersion = const $CopyWithPlaceholder(),
  }) {
    return SubmitAdminStarpathRevisionRequest(
      policyVersion: policyVersion == const $CopyWithPlaceholder()
          ? _value.policyVersion
          // ignore: cast_nullable_to_non_nullable
          : policyVersion as String,
    );
  }
}

extension $SubmitAdminStarpathRevisionRequestCopyWith
    on SubmitAdminStarpathRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfSubmitAdminStarpathRevisionRequest.copyWith(...)` or like so:`instanceOfSubmitAdminStarpathRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SubmitAdminStarpathRevisionRequestCWProxy get copyWith =>
      _$SubmitAdminStarpathRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubmitAdminStarpathRevisionRequest _$SubmitAdminStarpathRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SubmitAdminStarpathRevisionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['policy_version']);
  final val = SubmitAdminStarpathRevisionRequest(
    policyVersion: $checkedConvert('policy_version', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'policyVersion': 'policy_version'});

Map<String, dynamic> _$SubmitAdminStarpathRevisionRequestToJson(
  SubmitAdminStarpathRevisionRequest instance,
) => <String, dynamic>{'policy_version': instance.policyVersion};
