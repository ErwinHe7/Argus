// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_ritual_schedule_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminRitualScheduleRequestCWProxy {
  CreateAdminRitualScheduleRequest audience(
    CreateAdminRitualScheduleRequestAudienceEnum audience,
  );

  CreateAdminRitualScheduleRequest effectiveAt(DateTime effectiveAt);

  CreateAdminRitualScheduleRequest localDate(DateTime localDate);

  CreateAdminRitualScheduleRequest mode(
    CreateAdminRitualScheduleRequestModeEnum mode,
  );

  CreateAdminRitualScheduleRequest revisionId(String revisionId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminRitualScheduleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminRitualScheduleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminRitualScheduleRequest call({
    CreateAdminRitualScheduleRequestAudienceEnum audience,
    DateTime effectiveAt,
    DateTime localDate,
    CreateAdminRitualScheduleRequestModeEnum mode,
    String revisionId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminRitualScheduleRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminRitualScheduleRequest.copyWith.fieldName(...)`
class _$CreateAdminRitualScheduleRequestCWProxyImpl
    implements _$CreateAdminRitualScheduleRequestCWProxy {
  const _$CreateAdminRitualScheduleRequestCWProxyImpl(this._value);

  final CreateAdminRitualScheduleRequest _value;

  @override
  CreateAdminRitualScheduleRequest audience(
    CreateAdminRitualScheduleRequestAudienceEnum audience,
  ) => this(audience: audience);

  @override
  CreateAdminRitualScheduleRequest effectiveAt(DateTime effectiveAt) =>
      this(effectiveAt: effectiveAt);

  @override
  CreateAdminRitualScheduleRequest localDate(DateTime localDate) =>
      this(localDate: localDate);

  @override
  CreateAdminRitualScheduleRequest mode(
    CreateAdminRitualScheduleRequestModeEnum mode,
  ) => this(mode: mode);

  @override
  CreateAdminRitualScheduleRequest revisionId(String revisionId) =>
      this(revisionId: revisionId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminRitualScheduleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminRitualScheduleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminRitualScheduleRequest call({
    Object? audience = const $CopyWithPlaceholder(),
    Object? effectiveAt = const $CopyWithPlaceholder(),
    Object? localDate = const $CopyWithPlaceholder(),
    Object? mode = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminRitualScheduleRequest(
      audience: audience == const $CopyWithPlaceholder()
          ? _value.audience
          // ignore: cast_nullable_to_non_nullable
          : audience as CreateAdminRitualScheduleRequestAudienceEnum,
      effectiveAt: effectiveAt == const $CopyWithPlaceholder()
          ? _value.effectiveAt
          // ignore: cast_nullable_to_non_nullable
          : effectiveAt as DateTime,
      localDate: localDate == const $CopyWithPlaceholder()
          ? _value.localDate
          // ignore: cast_nullable_to_non_nullable
          : localDate as DateTime,
      mode: mode == const $CopyWithPlaceholder()
          ? _value.mode
          // ignore: cast_nullable_to_non_nullable
          : mode as CreateAdminRitualScheduleRequestModeEnum,
      revisionId: revisionId == const $CopyWithPlaceholder()
          ? _value.revisionId
          // ignore: cast_nullable_to_non_nullable
          : revisionId as String,
    );
  }
}

extension $CreateAdminRitualScheduleRequestCopyWith
    on CreateAdminRitualScheduleRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminRitualScheduleRequest.copyWith(...)` or like so:`instanceOfCreateAdminRitualScheduleRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminRitualScheduleRequestCWProxy get copyWith =>
      _$CreateAdminRitualScheduleRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminRitualScheduleRequest _$CreateAdminRitualScheduleRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateAdminRitualScheduleRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'audience',
        'effective_at',
        'local_date',
        'mode',
        'revision_id',
      ],
    );
    final val = CreateAdminRitualScheduleRequest(
      audience: $checkedConvert(
        'audience',
        (v) => $enumDecode(
          _$CreateAdminRitualScheduleRequestAudienceEnumEnumMap,
          v,
          unknownValue: CreateAdminRitualScheduleRequestAudienceEnum
              .unknownDefaultOpenApi,
        ),
      ),
      effectiveAt: $checkedConvert(
        'effective_at',
        (v) => DateTime.parse(v as String),
      ),
      localDate: $checkedConvert(
        'local_date',
        (v) => DateTime.parse(v as String),
      ),
      mode: $checkedConvert(
        'mode',
        (v) => $enumDecode(
          _$CreateAdminRitualScheduleRequestModeEnumEnumMap,
          v,
          unknownValue:
              CreateAdminRitualScheduleRequestModeEnum.unknownDefaultOpenApi,
        ),
      ),
      revisionId: $checkedConvert('revision_id', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'effectiveAt': 'effective_at',
    'localDate': 'local_date',
    'revisionId': 'revision_id',
  },
);

Map<String, dynamic> _$CreateAdminRitualScheduleRequestToJson(
  CreateAdminRitualScheduleRequest instance,
) => <String, dynamic>{
  'audience':
      _$CreateAdminRitualScheduleRequestAudienceEnumEnumMap[instance.audience]!,
  'effective_at': instance.effectiveAt.toIso8601String(),
  'local_date': instance.localDate.toIso8601String(),
  'mode': _$CreateAdminRitualScheduleRequestModeEnumEnumMap[instance.mode]!,
  'revision_id': instance.revisionId,
};

const _$CreateAdminRitualScheduleRequestAudienceEnumEnumMap = {
  CreateAdminRitualScheduleRequestAudienceEnum.public: 'public',
  CreateAdminRitualScheduleRequestAudienceEnum.member: 'member',
  CreateAdminRitualScheduleRequestAudienceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$CreateAdminRitualScheduleRequestModeEnumEnumMap = {
  CreateAdminRitualScheduleRequestModeEnum.tarot: 'tarot',
  CreateAdminRitualScheduleRequestModeEnum.astrology: 'astrology',
  CreateAdminRitualScheduleRequestModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
