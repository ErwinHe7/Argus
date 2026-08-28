// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_content_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReportContentRequestCWProxy {
  ReportContentRequest details(String? details);

  ReportContentRequest reasonCode(String reasonCode);

  ReportContentRequest targetId(String targetId);

  ReportContentRequest targetKind(String targetKind);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReportContentRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReportContentRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReportContentRequest call({
    String? details,
    String reasonCode,
    String targetId,
    String targetKind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReportContentRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReportContentRequest.copyWith.fieldName(...)`
class _$ReportContentRequestCWProxyImpl
    implements _$ReportContentRequestCWProxy {
  const _$ReportContentRequestCWProxyImpl(this._value);

  final ReportContentRequest _value;

  @override
  ReportContentRequest details(String? details) => this(details: details);

  @override
  ReportContentRequest reasonCode(String reasonCode) =>
      this(reasonCode: reasonCode);

  @override
  ReportContentRequest targetId(String targetId) => this(targetId: targetId);

  @override
  ReportContentRequest targetKind(String targetKind) =>
      this(targetKind: targetKind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReportContentRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReportContentRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReportContentRequest call({
    Object? details = const $CopyWithPlaceholder(),
    Object? reasonCode = const $CopyWithPlaceholder(),
    Object? targetId = const $CopyWithPlaceholder(),
    Object? targetKind = const $CopyWithPlaceholder(),
  }) {
    return ReportContentRequest(
      details: details == const $CopyWithPlaceholder()
          ? _value.details
          // ignore: cast_nullable_to_non_nullable
          : details as String?,
      reasonCode: reasonCode == const $CopyWithPlaceholder()
          ? _value.reasonCode
          // ignore: cast_nullable_to_non_nullable
          : reasonCode as String,
      targetId: targetId == const $CopyWithPlaceholder()
          ? _value.targetId
          // ignore: cast_nullable_to_non_nullable
          : targetId as String,
      targetKind: targetKind == const $CopyWithPlaceholder()
          ? _value.targetKind
          // ignore: cast_nullable_to_non_nullable
          : targetKind as String,
    );
  }
}

extension $ReportContentRequestCopyWith on ReportContentRequest {
  /// Returns a callable class that can be used as follows: `instanceOfReportContentRequest.copyWith(...)` or like so:`instanceOfReportContentRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReportContentRequestCWProxy get copyWith =>
      _$ReportContentRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReportContentRequest _$ReportContentRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ReportContentRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['reasonCode', 'targetId', 'targetKind'],
  );
  final val = ReportContentRequest(
    details: $checkedConvert('details', (v) => v as String?),
    reasonCode: $checkedConvert('reasonCode', (v) => v as String),
    targetId: $checkedConvert('targetId', (v) => v as String),
    targetKind: $checkedConvert('targetKind', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$ReportContentRequestToJson(
  ReportContentRequest instance,
) => <String, dynamic>{
  'details': ?instance.details,
  'reasonCode': instance.reasonCode,
  'targetId': instance.targetId,
  'targetKind': instance.targetKind,
};
