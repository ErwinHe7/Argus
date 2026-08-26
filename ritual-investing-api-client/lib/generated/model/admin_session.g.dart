// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_session.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminSessionCWProxy {
  AdminSession displayLabel(String displayLabel);

  AdminSession staffId(String staffId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminSession(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminSession call({String displayLabel, String staffId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminSession.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminSession.copyWith.fieldName(...)`
class _$AdminSessionCWProxyImpl implements _$AdminSessionCWProxy {
  const _$AdminSessionCWProxyImpl(this._value);

  final AdminSession _value;

  @override
  AdminSession displayLabel(String displayLabel) =>
      this(displayLabel: displayLabel);

  @override
  AdminSession staffId(String staffId) => this(staffId: staffId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminSession(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminSession call({
    Object? displayLabel = const $CopyWithPlaceholder(),
    Object? staffId = const $CopyWithPlaceholder(),
  }) {
    return AdminSession(
      displayLabel: displayLabel == const $CopyWithPlaceholder()
          ? _value.displayLabel
          // ignore: cast_nullable_to_non_nullable
          : displayLabel as String,
      staffId: staffId == const $CopyWithPlaceholder()
          ? _value.staffId
          // ignore: cast_nullable_to_non_nullable
          : staffId as String,
    );
  }
}

extension $AdminSessionCopyWith on AdminSession {
  /// Returns a callable class that can be used as follows: `instanceOfAdminSession.copyWith(...)` or like so:`instanceOfAdminSession.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminSessionCWProxy get copyWith => _$AdminSessionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminSession _$AdminSessionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AdminSession', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['display_label', 'staff_id']);
  final val = AdminSession(
    displayLabel: $checkedConvert('display_label', (v) => v as String),
    staffId: $checkedConvert('staff_id', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'displayLabel': 'display_label', 'staffId': 'staff_id'});

Map<String, dynamic> _$AdminSessionToJson(AdminSession instance) =>
    <String, dynamic>{
      'display_label': instance.displayLabel,
      'staff_id': instance.staffId,
    };
