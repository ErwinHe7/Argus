// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_editorial_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminEditorialRevisionRequestCWProxy {
  CreateAdminEditorialRevisionRequest payload(Map<String, Object?> payload);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEditorialRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEditorialRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEditorialRevisionRequest call({Map<String, Object?> payload});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminEditorialRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminEditorialRevisionRequest.copyWith.fieldName(...)`
class _$CreateAdminEditorialRevisionRequestCWProxyImpl
    implements _$CreateAdminEditorialRevisionRequestCWProxy {
  const _$CreateAdminEditorialRevisionRequestCWProxyImpl(this._value);

  final CreateAdminEditorialRevisionRequest _value;

  @override
  CreateAdminEditorialRevisionRequest payload(Map<String, Object?> payload) =>
      this(payload: payload);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEditorialRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEditorialRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEditorialRevisionRequest call({
    Object? payload = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminEditorialRevisionRequest(
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload as Map<String, Object?>,
    );
  }
}

extension $CreateAdminEditorialRevisionRequestCopyWith
    on CreateAdminEditorialRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminEditorialRevisionRequest.copyWith(...)` or like so:`instanceOfCreateAdminEditorialRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminEditorialRevisionRequestCWProxy get copyWith =>
      _$CreateAdminEditorialRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminEditorialRevisionRequest
_$CreateAdminEditorialRevisionRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateAdminEditorialRevisionRequest', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['payload']);
      final val = CreateAdminEditorialRevisionRequest(
        payload: $checkedConvert('payload', (v) => v as Map<String, dynamic>),
      );
      return val;
    });

Map<String, dynamic> _$CreateAdminEditorialRevisionRequestToJson(
  CreateAdminEditorialRevisionRequest instance,
) => <String, dynamic>{'payload': instance.payload};
