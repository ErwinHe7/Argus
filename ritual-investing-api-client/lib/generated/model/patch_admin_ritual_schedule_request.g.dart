// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_admin_ritual_schedule_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchAdminRitualScheduleRequestCWProxy {
  PatchAdminRitualScheduleRequest effectiveAt(DateTime? effectiveAt);

  PatchAdminRitualScheduleRequest revisionId(String? revisionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminRitualScheduleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminRitualScheduleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminRitualScheduleRequest call({
    DateTime? effectiveAt,
    String? revisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchAdminRitualScheduleRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchAdminRitualScheduleRequest.copyWith.fieldName(...)`
class _$PatchAdminRitualScheduleRequestCWProxyImpl
    implements _$PatchAdminRitualScheduleRequestCWProxy {
  const _$PatchAdminRitualScheduleRequestCWProxyImpl(this._value);

  final PatchAdminRitualScheduleRequest _value;

  @override
  PatchAdminRitualScheduleRequest effectiveAt(DateTime? effectiveAt) =>
      this(effectiveAt: effectiveAt);

  @override
  PatchAdminRitualScheduleRequest revisionId(String? revisionId) =>
      this(revisionId: revisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminRitualScheduleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminRitualScheduleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminRitualScheduleRequest call({
    Object? effectiveAt = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
  }) {
    return PatchAdminRitualScheduleRequest(
      effectiveAt: effectiveAt == const $CopyWithPlaceholder()
          ? _value.effectiveAt
          // ignore: cast_nullable_to_non_nullable
          : effectiveAt as DateTime?,
      revisionId: revisionId == const $CopyWithPlaceholder()
          ? _value.revisionId
          // ignore: cast_nullable_to_non_nullable
          : revisionId as String?,
    );
  }
}

extension $PatchAdminRitualScheduleRequestCopyWith
    on PatchAdminRitualScheduleRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchAdminRitualScheduleRequest.copyWith(...)` or like so:`instanceOfPatchAdminRitualScheduleRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchAdminRitualScheduleRequestCWProxy get copyWith =>
      _$PatchAdminRitualScheduleRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchAdminRitualScheduleRequest _$PatchAdminRitualScheduleRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PatchAdminRitualScheduleRequest',
  json,
  ($checkedConvert) {
    final val = PatchAdminRitualScheduleRequest(
      effectiveAt: $checkedConvert(
        'effective_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      revisionId: $checkedConvert('revision_id', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'effectiveAt': 'effective_at',
    'revisionId': 'revision_id',
  },
);

Map<String, dynamic> _$PatchAdminRitualScheduleRequestToJson(
  PatchAdminRitualScheduleRequest instance,
) => <String, dynamic>{
  'effective_at': ?instance.effectiveAt?.toIso8601String(),
  'revision_id': ?instance.revisionId,
};
