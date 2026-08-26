// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_moderation_case.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminModerationCaseCWProxy {
  AdminModerationCase assigneeId(String? assigneeId);

  AdminModerationCase decisions(
    List<AdminModerationCaseDecisionsInner> decisions,
  );

  AdminModerationCase etag(String etag);

  AdminModerationCase id(String id);

  AdminModerationCase report(AdminModerationReport report);

  AdminModerationCase resolutionCode(String? resolutionCode);

  AdminModerationCase resolvedAt(DateTime? resolvedAt);

  AdminModerationCase status(AdminModerationCaseStatusEnum status);

  AdminModerationCase version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminModerationCase(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminModerationCase(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminModerationCase call({
    String? assigneeId,
    List<AdminModerationCaseDecisionsInner> decisions,
    String etag,
    String id,
    AdminModerationReport report,
    String? resolutionCode,
    DateTime? resolvedAt,
    AdminModerationCaseStatusEnum status,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminModerationCase.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminModerationCase.copyWith.fieldName(...)`
class _$AdminModerationCaseCWProxyImpl implements _$AdminModerationCaseCWProxy {
  const _$AdminModerationCaseCWProxyImpl(this._value);

  final AdminModerationCase _value;

  @override
  AdminModerationCase assigneeId(String? assigneeId) =>
      this(assigneeId: assigneeId);

  @override
  AdminModerationCase decisions(
    List<AdminModerationCaseDecisionsInner> decisions,
  ) => this(decisions: decisions);

  @override
  AdminModerationCase etag(String etag) => this(etag: etag);

  @override
  AdminModerationCase id(String id) => this(id: id);

  @override
  AdminModerationCase report(AdminModerationReport report) =>
      this(report: report);

  @override
  AdminModerationCase resolutionCode(String? resolutionCode) =>
      this(resolutionCode: resolutionCode);

  @override
  AdminModerationCase resolvedAt(DateTime? resolvedAt) =>
      this(resolvedAt: resolvedAt);

  @override
  AdminModerationCase status(AdminModerationCaseStatusEnum status) =>
      this(status: status);

  @override
  AdminModerationCase version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminModerationCase(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminModerationCase(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminModerationCase call({
    Object? assigneeId = const $CopyWithPlaceholder(),
    Object? decisions = const $CopyWithPlaceholder(),
    Object? etag = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? report = const $CopyWithPlaceholder(),
    Object? resolutionCode = const $CopyWithPlaceholder(),
    Object? resolvedAt = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return AdminModerationCase(
      assigneeId: assigneeId == const $CopyWithPlaceholder()
          ? _value.assigneeId
          // ignore: cast_nullable_to_non_nullable
          : assigneeId as String?,
      decisions: decisions == const $CopyWithPlaceholder()
          ? _value.decisions
          // ignore: cast_nullable_to_non_nullable
          : decisions as List<AdminModerationCaseDecisionsInner>,
      etag: etag == const $CopyWithPlaceholder()
          ? _value.etag
          // ignore: cast_nullable_to_non_nullable
          : etag as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      report: report == const $CopyWithPlaceholder()
          ? _value.report
          // ignore: cast_nullable_to_non_nullable
          : report as AdminModerationReport,
      resolutionCode: resolutionCode == const $CopyWithPlaceholder()
          ? _value.resolutionCode
          // ignore: cast_nullable_to_non_nullable
          : resolutionCode as String?,
      resolvedAt: resolvedAt == const $CopyWithPlaceholder()
          ? _value.resolvedAt
          // ignore: cast_nullable_to_non_nullable
          : resolvedAt as DateTime?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as AdminModerationCaseStatusEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $AdminModerationCaseCopyWith on AdminModerationCase {
  /// Returns a callable class that can be used as follows: `instanceOfAdminModerationCase.copyWith(...)` or like so:`instanceOfAdminModerationCase.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminModerationCaseCWProxy get copyWith =>
      _$AdminModerationCaseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminModerationCase _$AdminModerationCaseFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AdminModerationCase',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'assignee_id',
            'decisions',
            'etag',
            'id',
            'report',
            'resolution_code',
            'resolved_at',
            'status',
            'version',
          ],
        );
        final val = AdminModerationCase(
          assigneeId: $checkedConvert('assignee_id', (v) => v as String?),
          decisions: $checkedConvert(
            'decisions',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => AdminModerationCaseDecisionsInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
          ),
          etag: $checkedConvert('etag', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          report: $checkedConvert(
            'report',
            (v) => AdminModerationReport.fromJson(v as Map<String, dynamic>),
          ),
          resolutionCode: $checkedConvert(
            'resolution_code',
            (v) => v as String?,
          ),
          resolvedAt: $checkedConvert(
            'resolved_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$AdminModerationCaseStatusEnumEnumMap,
              v,
              unknownValue: AdminModerationCaseStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'assigneeId': 'assignee_id',
        'resolutionCode': 'resolution_code',
        'resolvedAt': 'resolved_at',
      },
    );

Map<String, dynamic> _$AdminModerationCaseToJson(
  AdminModerationCase instance,
) => <String, dynamic>{
  'assignee_id': instance.assigneeId,
  'decisions': instance.decisions.map((e) => e.toJson()).toList(),
  'etag': instance.etag,
  'id': instance.id,
  'report': instance.report.toJson(),
  'resolution_code': instance.resolutionCode,
  'resolved_at': instance.resolvedAt?.toIso8601String(),
  'status': _$AdminModerationCaseStatusEnumEnumMap[instance.status]!,
  'version': instance.version,
};

const _$AdminModerationCaseStatusEnumEnumMap = {
  AdminModerationCaseStatusEnum.open: 'open',
  AdminModerationCaseStatusEnum.investigating: 'investigating',
  AdminModerationCaseStatusEnum.resolved: 'resolved',
  AdminModerationCaseStatusEnum.dismissed: 'dismissed',
  AdminModerationCaseStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
