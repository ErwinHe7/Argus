// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decide_admin_asset_codex_review_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DecideAdminAssetCodexReviewRequestCWProxy {
  DecideAdminAssetCodexReviewRequest decision(
    DecideAdminAssetCodexReviewRequestDecisionEnum decision,
  );

  DecideAdminAssetCodexReviewRequest reason(String reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DecideAdminAssetCodexReviewRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DecideAdminAssetCodexReviewRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DecideAdminAssetCodexReviewRequest call({
    DecideAdminAssetCodexReviewRequestDecisionEnum decision,
    String reason,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDecideAdminAssetCodexReviewRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDecideAdminAssetCodexReviewRequest.copyWith.fieldName(...)`
class _$DecideAdminAssetCodexReviewRequestCWProxyImpl
    implements _$DecideAdminAssetCodexReviewRequestCWProxy {
  const _$DecideAdminAssetCodexReviewRequestCWProxyImpl(this._value);

  final DecideAdminAssetCodexReviewRequest _value;

  @override
  DecideAdminAssetCodexReviewRequest decision(
    DecideAdminAssetCodexReviewRequestDecisionEnum decision,
  ) => this(decision: decision);

  @override
  DecideAdminAssetCodexReviewRequest reason(String reason) =>
      this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DecideAdminAssetCodexReviewRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DecideAdminAssetCodexReviewRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DecideAdminAssetCodexReviewRequest call({
    Object? decision = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return DecideAdminAssetCodexReviewRequest(
      decision: decision == const $CopyWithPlaceholder()
          ? _value.decision
          // ignore: cast_nullable_to_non_nullable
          : decision as DecideAdminAssetCodexReviewRequestDecisionEnum,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
    );
  }
}

extension $DecideAdminAssetCodexReviewRequestCopyWith
    on DecideAdminAssetCodexReviewRequest {
  /// Returns a callable class that can be used as follows: `instanceOfDecideAdminAssetCodexReviewRequest.copyWith(...)` or like so:`instanceOfDecideAdminAssetCodexReviewRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DecideAdminAssetCodexReviewRequestCWProxy get copyWith =>
      _$DecideAdminAssetCodexReviewRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DecideAdminAssetCodexReviewRequest _$DecideAdminAssetCodexReviewRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DecideAdminAssetCodexReviewRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['decision', 'reason']);
  final val = DecideAdminAssetCodexReviewRequest(
    decision: $checkedConvert(
      'decision',
      (v) => $enumDecode(
        _$DecideAdminAssetCodexReviewRequestDecisionEnumEnumMap,
        v,
        unknownValue: DecideAdminAssetCodexReviewRequestDecisionEnum
            .unknownDefaultOpenApi,
      ),
    ),
    reason: $checkedConvert('reason', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$DecideAdminAssetCodexReviewRequestToJson(
  DecideAdminAssetCodexReviewRequest instance,
) => <String, dynamic>{
  'decision':
      _$DecideAdminAssetCodexReviewRequestDecisionEnumEnumMap[instance
          .decision]!,
  'reason': instance.reason,
};

const _$DecideAdminAssetCodexReviewRequestDecisionEnumEnumMap = {
  DecideAdminAssetCodexReviewRequestDecisionEnum.approved: 'approved',
  DecideAdminAssetCodexReviewRequestDecisionEnum.changesRequested:
      'changes_requested',
  DecideAdminAssetCodexReviewRequestDecisionEnum.rejected: 'rejected',
  DecideAdminAssetCodexReviewRequestDecisionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
