// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_audit200_response_meta.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAudit200ResponseMetaCWProxy {
  ListAdminAudit200ResponseMeta requestId(String requestId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAudit200ResponseMeta(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAudit200ResponseMeta(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAudit200ResponseMeta call({String requestId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAudit200ResponseMeta.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAudit200ResponseMeta.copyWith.fieldName(...)`
class _$ListAdminAudit200ResponseMetaCWProxyImpl
    implements _$ListAdminAudit200ResponseMetaCWProxy {
  const _$ListAdminAudit200ResponseMetaCWProxyImpl(this._value);

  final ListAdminAudit200ResponseMeta _value;

  @override
  ListAdminAudit200ResponseMeta requestId(String requestId) =>
      this(requestId: requestId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAudit200ResponseMeta(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAudit200ResponseMeta(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAudit200ResponseMeta call({
    Object? requestId = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAudit200ResponseMeta(
      requestId: requestId == const $CopyWithPlaceholder()
          ? _value.requestId
          // ignore: cast_nullable_to_non_nullable
          : requestId as String,
    );
  }
}

extension $ListAdminAudit200ResponseMetaCopyWith
    on ListAdminAudit200ResponseMeta {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAudit200ResponseMeta.copyWith(...)` or like so:`instanceOfListAdminAudit200ResponseMeta.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAudit200ResponseMetaCWProxy get copyWith =>
      _$ListAdminAudit200ResponseMetaCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAudit200ResponseMeta _$ListAdminAudit200ResponseMetaFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListAdminAudit200ResponseMeta', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['request_id']);
  final val = ListAdminAudit200ResponseMeta(
    requestId: $checkedConvert('request_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'requestId': 'request_id'});

Map<String, dynamic> _$ListAdminAudit200ResponseMetaToJson(
  ListAdminAudit200ResponseMeta instance,
) => <String, dynamic>{'request_id': instance.requestId};
