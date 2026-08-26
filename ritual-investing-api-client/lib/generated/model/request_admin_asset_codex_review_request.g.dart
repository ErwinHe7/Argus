// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_admin_asset_codex_review_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RequestAdminAssetCodexReviewRequestCWProxy {
  RequestAdminAssetCodexReviewRequest highTrust(bool? highTrust);

  RequestAdminAssetCodexReviewRequest note(String note);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestAdminAssetCodexReviewRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestAdminAssetCodexReviewRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestAdminAssetCodexReviewRequest call({bool? highTrust, String note});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRequestAdminAssetCodexReviewRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRequestAdminAssetCodexReviewRequest.copyWith.fieldName(...)`
class _$RequestAdminAssetCodexReviewRequestCWProxyImpl
    implements _$RequestAdminAssetCodexReviewRequestCWProxy {
  const _$RequestAdminAssetCodexReviewRequestCWProxyImpl(this._value);

  final RequestAdminAssetCodexReviewRequest _value;

  @override
  RequestAdminAssetCodexReviewRequest highTrust(bool? highTrust) =>
      this(highTrust: highTrust);

  @override
  RequestAdminAssetCodexReviewRequest note(String note) => this(note: note);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RequestAdminAssetCodexReviewRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RequestAdminAssetCodexReviewRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RequestAdminAssetCodexReviewRequest call({
    Object? highTrust = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
  }) {
    return RequestAdminAssetCodexReviewRequest(
      highTrust: highTrust == const $CopyWithPlaceholder()
          ? _value.highTrust
          // ignore: cast_nullable_to_non_nullable
          : highTrust as bool?,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String,
    );
  }
}

extension $RequestAdminAssetCodexReviewRequestCopyWith
    on RequestAdminAssetCodexReviewRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRequestAdminAssetCodexReviewRequest.copyWith(...)` or like so:`instanceOfRequestAdminAssetCodexReviewRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RequestAdminAssetCodexReviewRequestCWProxy get copyWith =>
      _$RequestAdminAssetCodexReviewRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestAdminAssetCodexReviewRequest
_$RequestAdminAssetCodexReviewRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RequestAdminAssetCodexReviewRequest', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['note']);
      final val = RequestAdminAssetCodexReviewRequest(
        highTrust: $checkedConvert('high_trust', (v) => v as bool?),
        note: $checkedConvert('note', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'highTrust': 'high_trust'});

Map<String, dynamic> _$RequestAdminAssetCodexReviewRequestToJson(
  RequestAdminAssetCodexReviewRequest instance,
) => <String, dynamic>{
  'high_trust': ?instance.highTrust,
  'note': instance.note,
};
