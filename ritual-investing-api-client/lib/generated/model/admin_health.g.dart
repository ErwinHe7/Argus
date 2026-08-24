// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_health.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminHealthCWProxy {
  AdminHealth dependencies(AdminHealthDependencies dependencies);

  AdminHealth status(AdminHealthStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminHealth(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminHealth(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminHealth call({
    AdminHealthDependencies dependencies,
    AdminHealthStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminHealth.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminHealth.copyWith.fieldName(...)`
class _$AdminHealthCWProxyImpl implements _$AdminHealthCWProxy {
  const _$AdminHealthCWProxyImpl(this._value);

  final AdminHealth _value;

  @override
  AdminHealth dependencies(AdminHealthDependencies dependencies) =>
      this(dependencies: dependencies);

  @override
  AdminHealth status(AdminHealthStatusEnum status) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminHealth(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminHealth(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminHealth call({
    Object? dependencies = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return AdminHealth(
      dependencies: dependencies == const $CopyWithPlaceholder()
          ? _value.dependencies
          // ignore: cast_nullable_to_non_nullable
          : dependencies as AdminHealthDependencies,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as AdminHealthStatusEnum,
    );
  }
}

extension $AdminHealthCopyWith on AdminHealth {
  /// Returns a callable class that can be used as follows: `instanceOfAdminHealth.copyWith(...)` or like so:`instanceOfAdminHealth.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminHealthCWProxy get copyWith => _$AdminHealthCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminHealth _$AdminHealthFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AdminHealth', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['dependencies', 'status']);
      final val = AdminHealth(
        dependencies: $checkedConvert(
          'dependencies',
          (v) => AdminHealthDependencies.fromJson(v as Map<String, dynamic>),
        ),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$AdminHealthStatusEnumEnumMap,
            v,
            unknownValue: AdminHealthStatusEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AdminHealthToJson(AdminHealth instance) =>
    <String, dynamic>{
      'dependencies': instance.dependencies.toJson(),
      'status': _$AdminHealthStatusEnumEnumMap[instance.status]!,
    };

const _$AdminHealthStatusEnumEnumMap = {
  AdminHealthStatusEnum.ready: 'ready',
  AdminHealthStatusEnum.degraded: 'degraded',
  AdminHealthStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
