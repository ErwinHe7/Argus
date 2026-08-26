// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_moderation_report.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminModerationReportCWProxy {
  AdminModerationReport createdAt(DateTime createdAt);

  AdminModerationReport detail(String? detail);

  AdminModerationReport id(String id);

  AdminModerationReport reasonCode(String reasonCode);

  AdminModerationReport status(AdminModerationReportStatusEnum status);

  AdminModerationReport targetId(String targetId);

  AdminModerationReport targetKind(
    AdminModerationReportTargetKindEnum targetKind,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminModerationReport(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminModerationReport(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminModerationReport call({
    DateTime createdAt,
    String? detail,
    String id,
    String reasonCode,
    AdminModerationReportStatusEnum status,
    String targetId,
    AdminModerationReportTargetKindEnum targetKind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminModerationReport.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminModerationReport.copyWith.fieldName(...)`
class _$AdminModerationReportCWProxyImpl
    implements _$AdminModerationReportCWProxy {
  const _$AdminModerationReportCWProxyImpl(this._value);

  final AdminModerationReport _value;

  @override
  AdminModerationReport createdAt(DateTime createdAt) =>
      this(createdAt: createdAt);

  @override
  AdminModerationReport detail(String? detail) => this(detail: detail);

  @override
  AdminModerationReport id(String id) => this(id: id);

  @override
  AdminModerationReport reasonCode(String reasonCode) =>
      this(reasonCode: reasonCode);

  @override
  AdminModerationReport status(AdminModerationReportStatusEnum status) =>
      this(status: status);

  @override
  AdminModerationReport targetId(String targetId) => this(targetId: targetId);

  @override
  AdminModerationReport targetKind(
    AdminModerationReportTargetKindEnum targetKind,
  ) => this(targetKind: targetKind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminModerationReport(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminModerationReport(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminModerationReport call({
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? detail = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? reasonCode = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? targetId = const $CopyWithPlaceholder(),
    Object? targetKind = const $CopyWithPlaceholder(),
  }) {
    return AdminModerationReport(
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      detail: detail == const $CopyWithPlaceholder()
          ? _value.detail
          // ignore: cast_nullable_to_non_nullable
          : detail as String?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      reasonCode: reasonCode == const $CopyWithPlaceholder()
          ? _value.reasonCode
          // ignore: cast_nullable_to_non_nullable
          : reasonCode as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as AdminModerationReportStatusEnum,
      targetId: targetId == const $CopyWithPlaceholder()
          ? _value.targetId
          // ignore: cast_nullable_to_non_nullable
          : targetId as String,
      targetKind: targetKind == const $CopyWithPlaceholder()
          ? _value.targetKind
          // ignore: cast_nullable_to_non_nullable
          : targetKind as AdminModerationReportTargetKindEnum,
    );
  }
}

extension $AdminModerationReportCopyWith on AdminModerationReport {
  /// Returns a callable class that can be used as follows: `instanceOfAdminModerationReport.copyWith(...)` or like so:`instanceOfAdminModerationReport.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminModerationReportCWProxy get copyWith =>
      _$AdminModerationReportCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminModerationReport _$AdminModerationReportFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'AdminModerationReport',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'created_at',
        'detail',
        'id',
        'reason_code',
        'status',
        'target_id',
        'target_kind',
      ],
    );
    final val = AdminModerationReport(
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      detail: $checkedConvert('detail', (v) => v as String?),
      id: $checkedConvert('id', (v) => v as String),
      reasonCode: $checkedConvert('reason_code', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$AdminModerationReportStatusEnumEnumMap,
          v,
          unknownValue: AdminModerationReportStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      targetId: $checkedConvert('target_id', (v) => v as String),
      targetKind: $checkedConvert(
        'target_kind',
        (v) => $enumDecode(
          _$AdminModerationReportTargetKindEnumEnumMap,
          v,
          unknownValue:
              AdminModerationReportTargetKindEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'createdAt': 'created_at',
    'reasonCode': 'reason_code',
    'targetId': 'target_id',
    'targetKind': 'target_kind',
  },
);

Map<String, dynamic> _$AdminModerationReportToJson(
  AdminModerationReport instance,
) => <String, dynamic>{
  'created_at': instance.createdAt.toIso8601String(),
  'detail': instance.detail,
  'id': instance.id,
  'reason_code': instance.reasonCode,
  'status': _$AdminModerationReportStatusEnumEnumMap[instance.status]!,
  'target_id': instance.targetId,
  'target_kind':
      _$AdminModerationReportTargetKindEnumEnumMap[instance.targetKind]!,
};

const _$AdminModerationReportStatusEnumEnumMap = {
  AdminModerationReportStatusEnum.open: 'open',
  AdminModerationReportStatusEnum.triaged: 'triaged',
  AdminModerationReportStatusEnum.resolved: 'resolved',
  AdminModerationReportStatusEnum.dismissed: 'dismissed',
  AdminModerationReportStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$AdminModerationReportTargetKindEnumEnumMap = {
  AdminModerationReportTargetKindEnum.ritual: 'ritual',
  AdminModerationReportTargetKindEnum.assetCodex: 'asset_codex',
  AdminModerationReportTargetKindEnum.covenEntry: 'coven_entry',
  AdminModerationReportTargetKindEnum.grimoire: 'grimoire',
  AdminModerationReportTargetKindEnum.circleTemplate: 'circle_template',
  AdminModerationReportTargetKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
