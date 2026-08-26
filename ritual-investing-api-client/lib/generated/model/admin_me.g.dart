// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_me.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminMeCWProxy {
  AdminMe displayLabel(String displayLabel);

  AdminMe permissions(List<String> permissions);

  AdminMe revocationEpoch(int revocationEpoch);

  AdminMe staffId(String staffId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminMe(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminMe(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminMe call({
    String displayLabel,
    List<String> permissions,
    int revocationEpoch,
    String staffId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminMe.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminMe.copyWith.fieldName(...)`
class _$AdminMeCWProxyImpl implements _$AdminMeCWProxy {
  const _$AdminMeCWProxyImpl(this._value);

  final AdminMe _value;

  @override
  AdminMe displayLabel(String displayLabel) => this(displayLabel: displayLabel);

  @override
  AdminMe permissions(List<String> permissions) =>
      this(permissions: permissions);

  @override
  AdminMe revocationEpoch(int revocationEpoch) =>
      this(revocationEpoch: revocationEpoch);

  @override
  AdminMe staffId(String staffId) => this(staffId: staffId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminMe(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminMe(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminMe call({
    Object? displayLabel = const $CopyWithPlaceholder(),
    Object? permissions = const $CopyWithPlaceholder(),
    Object? revocationEpoch = const $CopyWithPlaceholder(),
    Object? staffId = const $CopyWithPlaceholder(),
  }) {
    return AdminMe(
      displayLabel: displayLabel == const $CopyWithPlaceholder()
          ? _value.displayLabel
          // ignore: cast_nullable_to_non_nullable
          : displayLabel as String,
      permissions: permissions == const $CopyWithPlaceholder()
          ? _value.permissions
          // ignore: cast_nullable_to_non_nullable
          : permissions as List<String>,
      revocationEpoch: revocationEpoch == const $CopyWithPlaceholder()
          ? _value.revocationEpoch
          // ignore: cast_nullable_to_non_nullable
          : revocationEpoch as int,
      staffId: staffId == const $CopyWithPlaceholder()
          ? _value.staffId
          // ignore: cast_nullable_to_non_nullable
          : staffId as String,
    );
  }
}

extension $AdminMeCopyWith on AdminMe {
  /// Returns a callable class that can be used as follows: `instanceOfAdminMe.copyWith(...)` or like so:`instanceOfAdminMe.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminMeCWProxy get copyWith => _$AdminMeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminMe _$AdminMeFromJson(Map<String, dynamic> json) => $checkedCreate(
  'AdminMe',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'display_label',
        'permissions',
        'revocation_epoch',
        'staff_id',
      ],
    );
    final val = AdminMe(
      displayLabel: $checkedConvert('display_label', (v) => v as String),
      permissions: $checkedConvert(
        'permissions',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      revocationEpoch: $checkedConvert(
        'revocation_epoch',
        (v) => (v as num).toInt(),
      ),
      staffId: $checkedConvert('staff_id', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'displayLabel': 'display_label',
    'revocationEpoch': 'revocation_epoch',
    'staffId': 'staff_id',
  },
);

Map<String, dynamic> _$AdminMeToJson(AdminMe instance) => <String, dynamic>{
  'display_label': instance.displayLabel,
  'permissions': instance.permissions,
  'revocation_epoch': instance.revocationEpoch,
  'staff_id': instance.staffId,
};
