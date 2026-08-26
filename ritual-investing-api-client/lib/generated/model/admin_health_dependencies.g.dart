// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_health_dependencies.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminHealthDependenciesCWProxy {
  AdminHealthDependencies identity(
    AdminHealthDependenciesIdentityEnum identity,
  );

  AdminHealthDependencies media(AdminHealthDependenciesMediaEnum media);

  AdminHealthDependencies neon(AdminHealthDependenciesNeonEnum neon);

  AdminHealthDependencies queue(AdminHealthDependenciesQueueEnum queue);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminHealthDependencies(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminHealthDependencies(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminHealthDependencies call({
    AdminHealthDependenciesIdentityEnum identity,
    AdminHealthDependenciesMediaEnum media,
    AdminHealthDependenciesNeonEnum neon,
    AdminHealthDependenciesQueueEnum queue,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminHealthDependencies.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminHealthDependencies.copyWith.fieldName(...)`
class _$AdminHealthDependenciesCWProxyImpl
    implements _$AdminHealthDependenciesCWProxy {
  const _$AdminHealthDependenciesCWProxyImpl(this._value);

  final AdminHealthDependencies _value;

  @override
  AdminHealthDependencies identity(
    AdminHealthDependenciesIdentityEnum identity,
  ) => this(identity: identity);

  @override
  AdminHealthDependencies media(AdminHealthDependenciesMediaEnum media) =>
      this(media: media);

  @override
  AdminHealthDependencies neon(AdminHealthDependenciesNeonEnum neon) =>
      this(neon: neon);

  @override
  AdminHealthDependencies queue(AdminHealthDependenciesQueueEnum queue) =>
      this(queue: queue);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminHealthDependencies(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminHealthDependencies(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminHealthDependencies call({
    Object? identity = const $CopyWithPlaceholder(),
    Object? media = const $CopyWithPlaceholder(),
    Object? neon = const $CopyWithPlaceholder(),
    Object? queue = const $CopyWithPlaceholder(),
  }) {
    return AdminHealthDependencies(
      identity: identity == const $CopyWithPlaceholder()
          ? _value.identity
          // ignore: cast_nullable_to_non_nullable
          : identity as AdminHealthDependenciesIdentityEnum,
      media: media == const $CopyWithPlaceholder()
          ? _value.media
          // ignore: cast_nullable_to_non_nullable
          : media as AdminHealthDependenciesMediaEnum,
      neon: neon == const $CopyWithPlaceholder()
          ? _value.neon
          // ignore: cast_nullable_to_non_nullable
          : neon as AdminHealthDependenciesNeonEnum,
      queue: queue == const $CopyWithPlaceholder()
          ? _value.queue
          // ignore: cast_nullable_to_non_nullable
          : queue as AdminHealthDependenciesQueueEnum,
    );
  }
}

extension $AdminHealthDependenciesCopyWith on AdminHealthDependencies {
  /// Returns a callable class that can be used as follows: `instanceOfAdminHealthDependencies.copyWith(...)` or like so:`instanceOfAdminHealthDependencies.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminHealthDependenciesCWProxy get copyWith =>
      _$AdminHealthDependenciesCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminHealthDependencies _$AdminHealthDependenciesFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AdminHealthDependencies', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['identity', 'media', 'neon', 'queue']);
  final val = AdminHealthDependencies(
    identity: $checkedConvert(
      'identity',
      (v) => $enumDecode(
        _$AdminHealthDependenciesIdentityEnumEnumMap,
        v,
        unknownValue: AdminHealthDependenciesIdentityEnum.unknownDefaultOpenApi,
      ),
    ),
    media: $checkedConvert(
      'media',
      (v) => $enumDecode(
        _$AdminHealthDependenciesMediaEnumEnumMap,
        v,
        unknownValue: AdminHealthDependenciesMediaEnum.unknownDefaultOpenApi,
      ),
    ),
    neon: $checkedConvert(
      'neon',
      (v) => $enumDecode(
        _$AdminHealthDependenciesNeonEnumEnumMap,
        v,
        unknownValue: AdminHealthDependenciesNeonEnum.unknownDefaultOpenApi,
      ),
    ),
    queue: $checkedConvert(
      'queue',
      (v) => $enumDecode(
        _$AdminHealthDependenciesQueueEnumEnumMap,
        v,
        unknownValue: AdminHealthDependenciesQueueEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$AdminHealthDependenciesToJson(
  AdminHealthDependencies instance,
) => <String, dynamic>{
  'identity': _$AdminHealthDependenciesIdentityEnumEnumMap[instance.identity]!,
  'media': _$AdminHealthDependenciesMediaEnumEnumMap[instance.media]!,
  'neon': _$AdminHealthDependenciesNeonEnumEnumMap[instance.neon]!,
  'queue': _$AdminHealthDependenciesQueueEnumEnumMap[instance.queue]!,
};

const _$AdminHealthDependenciesIdentityEnumEnumMap = {
  AdminHealthDependenciesIdentityEnum.configured: 'configured',
  AdminHealthDependenciesIdentityEnum.missing: 'missing',
  AdminHealthDependenciesIdentityEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$AdminHealthDependenciesMediaEnumEnumMap = {
  AdminHealthDependenciesMediaEnum.configured: 'configured',
  AdminHealthDependenciesMediaEnum.missing: 'missing',
  AdminHealthDependenciesMediaEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$AdminHealthDependenciesNeonEnumEnumMap = {
  AdminHealthDependenciesNeonEnum.configured: 'configured',
  AdminHealthDependenciesNeonEnum.missing: 'missing',
  AdminHealthDependenciesNeonEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$AdminHealthDependenciesQueueEnumEnumMap = {
  AdminHealthDependenciesQueueEnum.configured: 'configured',
  AdminHealthDependenciesQueueEnum.missing: 'missing',
  AdminHealthDependenciesQueueEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
