// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_content_report_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateContentReportRequestCWProxy {
  CreateContentReportRequest detail(String? detail);

  CreateContentReportRequest reasonCode(
    CreateContentReportRequestReasonCodeEnum reasonCode,
  );

  CreateContentReportRequest targetId(String targetId);

  CreateContentReportRequest targetKind(
    CreateContentReportRequestTargetKindEnum targetKind,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateContentReportRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateContentReportRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateContentReportRequest call({
    String? detail,
    CreateContentReportRequestReasonCodeEnum reasonCode,
    String targetId,
    CreateContentReportRequestTargetKindEnum targetKind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateContentReportRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateContentReportRequest.copyWith.fieldName(...)`
class _$CreateContentReportRequestCWProxyImpl
    implements _$CreateContentReportRequestCWProxy {
  const _$CreateContentReportRequestCWProxyImpl(this._value);

  final CreateContentReportRequest _value;

  @override
  CreateContentReportRequest detail(String? detail) => this(detail: detail);

  @override
  CreateContentReportRequest reasonCode(
    CreateContentReportRequestReasonCodeEnum reasonCode,
  ) => this(reasonCode: reasonCode);

  @override
  CreateContentReportRequest targetId(String targetId) =>
      this(targetId: targetId);

  @override
  CreateContentReportRequest targetKind(
    CreateContentReportRequestTargetKindEnum targetKind,
  ) => this(targetKind: targetKind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateContentReportRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateContentReportRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateContentReportRequest call({
    Object? detail = const $CopyWithPlaceholder(),
    Object? reasonCode = const $CopyWithPlaceholder(),
    Object? targetId = const $CopyWithPlaceholder(),
    Object? targetKind = const $CopyWithPlaceholder(),
  }) {
    return CreateContentReportRequest(
      detail: detail == const $CopyWithPlaceholder()
          ? _value.detail
          // ignore: cast_nullable_to_non_nullable
          : detail as String?,
      reasonCode: reasonCode == const $CopyWithPlaceholder()
          ? _value.reasonCode
          // ignore: cast_nullable_to_non_nullable
          : reasonCode as CreateContentReportRequestReasonCodeEnum,
      targetId: targetId == const $CopyWithPlaceholder()
          ? _value.targetId
          // ignore: cast_nullable_to_non_nullable
          : targetId as String,
      targetKind: targetKind == const $CopyWithPlaceholder()
          ? _value.targetKind
          // ignore: cast_nullable_to_non_nullable
          : targetKind as CreateContentReportRequestTargetKindEnum,
    );
  }
}

extension $CreateContentReportRequestCopyWith on CreateContentReportRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateContentReportRequest.copyWith(...)` or like so:`instanceOfCreateContentReportRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateContentReportRequestCWProxy get copyWith =>
      _$CreateContentReportRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateContentReportRequest _$CreateContentReportRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateContentReportRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['reason_code', 'target_id', 'target_kind'],
    );
    final val = CreateContentReportRequest(
      detail: $checkedConvert('detail', (v) => v as String?),
      reasonCode: $checkedConvert(
        'reason_code',
        (v) => $enumDecode(
          _$CreateContentReportRequestReasonCodeEnumEnumMap,
          v,
          unknownValue:
              CreateContentReportRequestReasonCodeEnum.unknownDefaultOpenApi,
        ),
      ),
      targetId: $checkedConvert('target_id', (v) => v as String),
      targetKind: $checkedConvert(
        'target_kind',
        (v) => $enumDecode(
          _$CreateContentReportRequestTargetKindEnumEnumMap,
          v,
          unknownValue:
              CreateContentReportRequestTargetKindEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'reasonCode': 'reason_code',
    'targetId': 'target_id',
    'targetKind': 'target_kind',
  },
);

Map<String, dynamic> _$CreateContentReportRequestToJson(
  CreateContentReportRequest instance,
) => <String, dynamic>{
  'detail': ?instance.detail,
  'reason_code':
      _$CreateContentReportRequestReasonCodeEnumEnumMap[instance.reasonCode]!,
  'target_id': instance.targetId,
  'target_kind':
      _$CreateContentReportRequestTargetKindEnumEnumMap[instance.targetKind]!,
};

const _$CreateContentReportRequestReasonCodeEnumEnumMap = {
  CreateContentReportRequestReasonCodeEnum.incorrect: 'incorrect',
  CreateContentReportRequestReasonCodeEnum.unsafe: 'unsafe',
  CreateContentReportRequestReasonCodeEnum.spam: 'spam',
  CreateContentReportRequestReasonCodeEnum.rights: 'rights',
  CreateContentReportRequestReasonCodeEnum.other: 'other',
  CreateContentReportRequestReasonCodeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$CreateContentReportRequestTargetKindEnumEnumMap = {
  CreateContentReportRequestTargetKindEnum.ritual: 'ritual',
  CreateContentReportRequestTargetKindEnum.codex: 'codex',
  CreateContentReportRequestTargetKindEnum.coven: 'coven',
  CreateContentReportRequestTargetKindEnum.grimoire: 'grimoire',
  CreateContentReportRequestTargetKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
