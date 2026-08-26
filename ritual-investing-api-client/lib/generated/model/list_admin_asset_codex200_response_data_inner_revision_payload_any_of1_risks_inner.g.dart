// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of1_risks_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerCWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner detail(
    String detail,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner
  severity(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
    severity,
  );

  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner title(
    String title,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner call({
    String detail,
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
    severity,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerCWProxyImpl
    implements
        _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerCWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerCWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner
  _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner detail(
    String detail,
  ) => this(detail: detail);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner
  severity(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
    severity,
  ) => this(severity: severity);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner title(
    String title,
  ) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner call({
    Object? detail = const $CopyWithPlaceholder(),
    Object? severity = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner(
      detail: detail == const $CopyWithPlaceholder()
          ? _value.detail
          // ignore: cast_nullable_to_non_nullable
          : detail as String,
      severity: severity == const $CopyWithPlaceholder()
          ? _value.severity
          // ignore: cast_nullable_to_non_nullable
          : severity
                as ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerCopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerCWProxy
  get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerCWProxyImpl(
        this,
      );
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['detail', 'severity', 'title']);
    final val = ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner(
      detail: $checkedConvert('detail', (v) => v as String),
      severity: $checkedConvert(
        'severity',
        (v) => $enumDecode(
          _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnumEnumMap,
          v,
          unknownValue:
              ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
                  .unknownDefaultOpenApi,
        ),
      ),
      title: $checkedConvert('title', (v) => v as String),
    );
    return val;
  },
);

Map<String, dynamic>
_$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerToJson(
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInner
  instance,
) => <String, dynamic>{
  'detail': instance.detail,
  'severity':
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnumEnumMap[instance
          .severity]!,
  'title': instance.title,
};

const _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnumEnumMap = {
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
          .low:
      'low',
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
          .medium:
      'medium',
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
          .high:
      'high',
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1RisksInnerSeverityEnum
          .unknownDefaultOpenApi:
      'unknown_default_open_api',
};
