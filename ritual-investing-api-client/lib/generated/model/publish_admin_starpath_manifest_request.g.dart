// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publish_admin_starpath_manifest_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublishAdminStarpathManifestRequestCWProxy {
  PublishAdminStarpathManifestRequest reason(String reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublishAdminStarpathManifestRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublishAdminStarpathManifestRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PublishAdminStarpathManifestRequest call({String reason});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublishAdminStarpathManifestRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublishAdminStarpathManifestRequest.copyWith.fieldName(...)`
class _$PublishAdminStarpathManifestRequestCWProxyImpl
    implements _$PublishAdminStarpathManifestRequestCWProxy {
  const _$PublishAdminStarpathManifestRequestCWProxyImpl(this._value);

  final PublishAdminStarpathManifestRequest _value;

  @override
  PublishAdminStarpathManifestRequest reason(String reason) =>
      this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublishAdminStarpathManifestRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublishAdminStarpathManifestRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PublishAdminStarpathManifestRequest call({
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return PublishAdminStarpathManifestRequest(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
    );
  }
}

extension $PublishAdminStarpathManifestRequestCopyWith
    on PublishAdminStarpathManifestRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPublishAdminStarpathManifestRequest.copyWith(...)` or like so:`instanceOfPublishAdminStarpathManifestRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublishAdminStarpathManifestRequestCWProxy get copyWith =>
      _$PublishAdminStarpathManifestRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublishAdminStarpathManifestRequest
_$PublishAdminStarpathManifestRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PublishAdminStarpathManifestRequest', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['reason']);
      final val = PublishAdminStarpathManifestRequest(
        reason: $checkedConvert('reason', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$PublishAdminStarpathManifestRequestToJson(
  PublishAdminStarpathManifestRequest instance,
) => <String, dynamic>{'reason': instance.reason};
