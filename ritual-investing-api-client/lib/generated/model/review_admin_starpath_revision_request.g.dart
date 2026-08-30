// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_admin_starpath_revision_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReviewAdminStarpathRevisionRequestCWProxy {
  ReviewAdminStarpathRevisionRequest decision(
    ReviewAdminStarpathRevisionRequestDecisionEnum decision,
  );

  ReviewAdminStarpathRevisionRequest discipline(
    ReviewAdminStarpathRevisionRequestDisciplineEnum discipline,
  );

  ReviewAdminStarpathRevisionRequest reason(String reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReviewAdminStarpathRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReviewAdminStarpathRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReviewAdminStarpathRevisionRequest call({
    ReviewAdminStarpathRevisionRequestDecisionEnum decision,
    ReviewAdminStarpathRevisionRequestDisciplineEnum discipline,
    String reason,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReviewAdminStarpathRevisionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReviewAdminStarpathRevisionRequest.copyWith.fieldName(...)`
class _$ReviewAdminStarpathRevisionRequestCWProxyImpl
    implements _$ReviewAdminStarpathRevisionRequestCWProxy {
  const _$ReviewAdminStarpathRevisionRequestCWProxyImpl(this._value);

  final ReviewAdminStarpathRevisionRequest _value;

  @override
  ReviewAdminStarpathRevisionRequest decision(
    ReviewAdminStarpathRevisionRequestDecisionEnum decision,
  ) => this(decision: decision);

  @override
  ReviewAdminStarpathRevisionRequest discipline(
    ReviewAdminStarpathRevisionRequestDisciplineEnum discipline,
  ) => this(discipline: discipline);

  @override
  ReviewAdminStarpathRevisionRequest reason(String reason) =>
      this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReviewAdminStarpathRevisionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReviewAdminStarpathRevisionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReviewAdminStarpathRevisionRequest call({
    Object? decision = const $CopyWithPlaceholder(),
    Object? discipline = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return ReviewAdminStarpathRevisionRequest(
      decision: decision == const $CopyWithPlaceholder()
          ? _value.decision
          // ignore: cast_nullable_to_non_nullable
          : decision as ReviewAdminStarpathRevisionRequestDecisionEnum,
      discipline: discipline == const $CopyWithPlaceholder()
          ? _value.discipline
          // ignore: cast_nullable_to_non_nullable
          : discipline as ReviewAdminStarpathRevisionRequestDisciplineEnum,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String,
    );
  }
}

extension $ReviewAdminStarpathRevisionRequestCopyWith
    on ReviewAdminStarpathRevisionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfReviewAdminStarpathRevisionRequest.copyWith(...)` or like so:`instanceOfReviewAdminStarpathRevisionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReviewAdminStarpathRevisionRequestCWProxy get copyWith =>
      _$ReviewAdminStarpathRevisionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReviewAdminStarpathRevisionRequest _$ReviewAdminStarpathRevisionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ReviewAdminStarpathRevisionRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['decision', 'discipline', 'reason']);
  final val = ReviewAdminStarpathRevisionRequest(
    decision: $checkedConvert(
      'decision',
      (v) => $enumDecode(
        _$ReviewAdminStarpathRevisionRequestDecisionEnumEnumMap,
        v,
        unknownValue: ReviewAdminStarpathRevisionRequestDecisionEnum
            .unknownDefaultOpenApi,
      ),
    ),
    discipline: $checkedConvert(
      'discipline',
      (v) => $enumDecode(
        _$ReviewAdminStarpathRevisionRequestDisciplineEnumEnumMap,
        v,
        unknownValue: ReviewAdminStarpathRevisionRequestDisciplineEnum
            .unknownDefaultOpenApi,
      ),
    ),
    reason: $checkedConvert('reason', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$ReviewAdminStarpathRevisionRequestToJson(
  ReviewAdminStarpathRevisionRequest instance,
) => <String, dynamic>{
  'decision':
      _$ReviewAdminStarpathRevisionRequestDecisionEnumEnumMap[instance
          .decision]!,
  'discipline':
      _$ReviewAdminStarpathRevisionRequestDisciplineEnumEnumMap[instance
          .discipline]!,
  'reason': instance.reason,
};

const _$ReviewAdminStarpathRevisionRequestDecisionEnumEnumMap = {
  ReviewAdminStarpathRevisionRequestDecisionEnum.approved: 'approved',
  ReviewAdminStarpathRevisionRequestDecisionEnum.changesRequested:
      'changes_requested',
  ReviewAdminStarpathRevisionRequestDecisionEnum.rejected: 'rejected',
  ReviewAdminStarpathRevisionRequestDecisionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$ReviewAdminStarpathRevisionRequestDisciplineEnumEnumMap = {
  ReviewAdminStarpathRevisionRequestDisciplineEnum.factual: 'factual',
  ReviewAdminStarpathRevisionRequestDisciplineEnum.compliance: 'compliance',
  ReviewAdminStarpathRevisionRequestDisciplineEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
