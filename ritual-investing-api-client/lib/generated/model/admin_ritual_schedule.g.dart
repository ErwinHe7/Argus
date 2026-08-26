// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_ritual_schedule.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminRitualScheduleCWProxy {
  AdminRitualSchedule audience(AdminRitualScheduleAudienceEnum audience);

  AdminRitualSchedule effectiveAt(DateTime effectiveAt);

  AdminRitualSchedule etag(String etag);

  AdminRitualSchedule id(String id);

  AdminRitualSchedule localDate(DateTime localDate);

  AdminRitualSchedule mode(AdminRitualScheduleModeEnum mode);

  AdminRitualSchedule revisionId(String revisionId);

  AdminRitualSchedule state(AdminRitualScheduleStateEnum state);

  AdminRitualSchedule version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminRitualSchedule(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminRitualSchedule(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminRitualSchedule call({
    AdminRitualScheduleAudienceEnum audience,
    DateTime effectiveAt,
    String etag,
    String id,
    DateTime localDate,
    AdminRitualScheduleModeEnum mode,
    String revisionId,
    AdminRitualScheduleStateEnum state,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminRitualSchedule.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminRitualSchedule.copyWith.fieldName(...)`
class _$AdminRitualScheduleCWProxyImpl implements _$AdminRitualScheduleCWProxy {
  const _$AdminRitualScheduleCWProxyImpl(this._value);

  final AdminRitualSchedule _value;

  @override
  AdminRitualSchedule audience(AdminRitualScheduleAudienceEnum audience) =>
      this(audience: audience);

  @override
  AdminRitualSchedule effectiveAt(DateTime effectiveAt) =>
      this(effectiveAt: effectiveAt);

  @override
  AdminRitualSchedule etag(String etag) => this(etag: etag);

  @override
  AdminRitualSchedule id(String id) => this(id: id);

  @override
  AdminRitualSchedule localDate(DateTime localDate) =>
      this(localDate: localDate);

  @override
  AdminRitualSchedule mode(AdminRitualScheduleModeEnum mode) =>
      this(mode: mode);

  @override
  AdminRitualSchedule revisionId(String revisionId) =>
      this(revisionId: revisionId);

  @override
  AdminRitualSchedule state(AdminRitualScheduleStateEnum state) =>
      this(state: state);

  @override
  AdminRitualSchedule version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminRitualSchedule(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminRitualSchedule(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminRitualSchedule call({
    Object? audience = const $CopyWithPlaceholder(),
    Object? effectiveAt = const $CopyWithPlaceholder(),
    Object? etag = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? localDate = const $CopyWithPlaceholder(),
    Object? mode = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return AdminRitualSchedule(
      audience: audience == const $CopyWithPlaceholder()
          ? _value.audience
          // ignore: cast_nullable_to_non_nullable
          : audience as AdminRitualScheduleAudienceEnum,
      effectiveAt: effectiveAt == const $CopyWithPlaceholder()
          ? _value.effectiveAt
          // ignore: cast_nullable_to_non_nullable
          : effectiveAt as DateTime,
      etag: etag == const $CopyWithPlaceholder()
          ? _value.etag
          // ignore: cast_nullable_to_non_nullable
          : etag as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      localDate: localDate == const $CopyWithPlaceholder()
          ? _value.localDate
          // ignore: cast_nullable_to_non_nullable
          : localDate as DateTime,
      mode: mode == const $CopyWithPlaceholder()
          ? _value.mode
          // ignore: cast_nullable_to_non_nullable
          : mode as AdminRitualScheduleModeEnum,
      revisionId: revisionId == const $CopyWithPlaceholder()
          ? _value.revisionId
          // ignore: cast_nullable_to_non_nullable
          : revisionId as String,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as AdminRitualScheduleStateEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $AdminRitualScheduleCopyWith on AdminRitualSchedule {
  /// Returns a callable class that can be used as follows: `instanceOfAdminRitualSchedule.copyWith(...)` or like so:`instanceOfAdminRitualSchedule.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminRitualScheduleCWProxy get copyWith =>
      _$AdminRitualScheduleCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminRitualSchedule _$AdminRitualScheduleFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AdminRitualSchedule',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'audience',
            'effective_at',
            'etag',
            'id',
            'local_date',
            'mode',
            'revision_id',
            'state',
            'version',
          ],
        );
        final val = AdminRitualSchedule(
          audience: $checkedConvert(
            'audience',
            (v) => $enumDecode(
              _$AdminRitualScheduleAudienceEnumEnumMap,
              v,
              unknownValue:
                  AdminRitualScheduleAudienceEnum.unknownDefaultOpenApi,
            ),
          ),
          effectiveAt: $checkedConvert(
            'effective_at',
            (v) => DateTime.parse(v as String),
          ),
          etag: $checkedConvert('etag', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          localDate: $checkedConvert(
            'local_date',
            (v) => DateTime.parse(v as String),
          ),
          mode: $checkedConvert(
            'mode',
            (v) => $enumDecode(
              _$AdminRitualScheduleModeEnumEnumMap,
              v,
              unknownValue: AdminRitualScheduleModeEnum.unknownDefaultOpenApi,
            ),
          ),
          revisionId: $checkedConvert('revision_id', (v) => v as String),
          state: $checkedConvert(
            'state',
            (v) => $enumDecode(
              _$AdminRitualScheduleStateEnumEnumMap,
              v,
              unknownValue: AdminRitualScheduleStateEnum.unknownDefaultOpenApi,
            ),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'effectiveAt': 'effective_at',
        'localDate': 'local_date',
        'revisionId': 'revision_id',
      },
    );

Map<String, dynamic> _$AdminRitualScheduleToJson(
  AdminRitualSchedule instance,
) => <String, dynamic>{
  'audience': _$AdminRitualScheduleAudienceEnumEnumMap[instance.audience]!,
  'effective_at': instance.effectiveAt.toIso8601String(),
  'etag': instance.etag,
  'id': instance.id,
  'local_date': instance.localDate.toIso8601String(),
  'mode': _$AdminRitualScheduleModeEnumEnumMap[instance.mode]!,
  'revision_id': instance.revisionId,
  'state': _$AdminRitualScheduleStateEnumEnumMap[instance.state]!,
  'version': instance.version,
};

const _$AdminRitualScheduleAudienceEnumEnumMap = {
  AdminRitualScheduleAudienceEnum.public: 'public',
  AdminRitualScheduleAudienceEnum.member: 'member',
  AdminRitualScheduleAudienceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$AdminRitualScheduleModeEnumEnumMap = {
  AdminRitualScheduleModeEnum.tarot: 'tarot',
  AdminRitualScheduleModeEnum.astrology: 'astrology',
  AdminRitualScheduleModeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$AdminRitualScheduleStateEnumEnumMap = {
  AdminRitualScheduleStateEnum.draft: 'draft',
  AdminRitualScheduleStateEnum.scheduled: 'scheduled',
  AdminRitualScheduleStateEnum.active: 'active',
  AdminRitualScheduleStateEnum.withdrawn: 'withdrawn',
  AdminRitualScheduleStateEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
