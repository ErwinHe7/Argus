// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HealthResponseDataCWProxy {
  HealthResponseData buildRevision(String buildRevision);

  HealthResponseData status(HealthResponseDataStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthResponseData call({
    String buildRevision,
    HealthResponseDataStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHealthResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHealthResponseData.copyWith.fieldName(...)`
class _$HealthResponseDataCWProxyImpl implements _$HealthResponseDataCWProxy {
  const _$HealthResponseDataCWProxyImpl(this._value);

  final HealthResponseData _value;

  @override
  HealthResponseData buildRevision(String buildRevision) =>
      this(buildRevision: buildRevision);

  @override
  HealthResponseData status(HealthResponseDataStatusEnum status) =>
      this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthResponseData call({
    Object? buildRevision = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return HealthResponseData(
      buildRevision: buildRevision == const $CopyWithPlaceholder()
          ? _value.buildRevision
          // ignore: cast_nullable_to_non_nullable
          : buildRevision as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as HealthResponseDataStatusEnum,
    );
  }
}

extension $HealthResponseDataCopyWith on HealthResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfHealthResponseData.copyWith(...)` or like so:`instanceOfHealthResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HealthResponseDataCWProxy get copyWith =>
      _$HealthResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthResponseData _$HealthResponseDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HealthResponseData', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['build_revision', 'status']);
      final val = HealthResponseData(
        buildRevision: $checkedConvert('build_revision', (v) => v as String),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$HealthResponseDataStatusEnumEnumMap,
            v,
            unknownValue: HealthResponseDataStatusEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    }, fieldKeyMap: const {'buildRevision': 'build_revision'});

Map<String, dynamic> _$HealthResponseDataToJson(HealthResponseData instance) =>
    <String, dynamic>{
      'build_revision': instance.buildRevision,
      'status': _$HealthResponseDataStatusEnumEnumMap[instance.status]!,
    };

const _$HealthResponseDataStatusEnumEnumMap = {
  HealthResponseDataStatusEnum.ok: 'ok',
  HealthResponseDataStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
