// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publish_admin_asset_codex_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublishAdminAssetCodexRevisionRequestCWProxy {
  PublishAdminAssetCodexRevisionRequest effectiveAt(DateTime effectiveAt);

  PublishAdminAssetCodexRevisionRequest reason(String reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublishAdminAssetCodexRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublishAdminAssetCodexRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PublishAdminAssetCodexRevisionRequest call({
    DateTime effectiveAt,
    String reason,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublishAdminAssetCodexRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublishAdminAssetCodexRevisionRequest.copyWith.fieldName(...)`
class _$PublishAdminAssetCodexRevisionRequestCWProxyImpl
    implements _$PublishAdminAssetCodexRevisionRequestCWProxy {
  const _$PublishAdminAssetCodexRevisionRequestCWProxyImpl(this._value);

  final PublishAdminAssetCodexRevisionRequest _value;

  @override
  PublishAdminAssetCodexRevisionRequest effectiveAt(DateTime effectiveAt) =>
      this(effectiveAt: effectiveAt);

  @override
  PublishAdminAssetCodexRevisionRequest reason(String reason) =>
      this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublishAdminAssetCodexRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublishAdminAssetCodexRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PublishAdminAssetCodexRevisionRequest call({
    Object? effectiveAt = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return PublishAdminAssetCodexRevisionRequest(
      effectiveAt: effectiveAt == const $CopyWithPlaceholder()
          ? _value.effectiveAt
          // ignore: cast_nullable_to_non_nullable
          : effectiveAt as DateTime,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
    );
  }
}

extension $PublishAdminAssetCodexRevisionRequestCopyWith
    on PublishAdminAssetCodexRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPublishAdminAssetCodexRevisionRequest.copyWith(...)` or like so:`instanceOfPublishAdminAssetCodexRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublishAdminAssetCodexRevisionRequestCWProxy get copyWith =>
      _$PublishAdminAssetCodexRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublishAdminAssetCodexRevisionRequest
_$PublishAdminAssetCodexRevisionRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PublishAdminAssetCodexRevisionRequest', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['effective_at', 'reason']);
      final val = PublishAdminAssetCodexRevisionRequest(
        effectiveAt: $checkedConvert(
          'effective_at',
          (v) => DateTime.parse(v as String),
        ),
        reason: $checkedConvert('reason', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'effectiveAt': 'effective_at'});

Map<String, dynamic> _$PublishAdminAssetCodexRevisionRequestToJson(
  PublishAdminAssetCodexRevisionRequest instance,
) => <String, dynamic>{
  'effective_at': instance.effectiveAt.toIso8601String(),
  'reason': instance.reason,
};
