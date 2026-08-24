// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_moderation_case_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminModerationCaseRequestCWProxy {
  CreateAdminModerationCaseRequest assigneeId(String? assigneeId);

  CreateAdminModerationCaseRequest note(String note);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminModerationCaseRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminModerationCaseRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminModerationCaseRequest call({String? assigneeId, String note});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminModerationCaseRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminModerationCaseRequest.copyWith.fieldName(...)`
class _$CreateAdminModerationCaseRequestCWProxyImpl
    implements _$CreateAdminModerationCaseRequestCWProxy {
  const _$CreateAdminModerationCaseRequestCWProxyImpl(this._value);

  final CreateAdminModerationCaseRequest _value;

  @override
  CreateAdminModerationCaseRequest assigneeId(String? assigneeId) =>
      this(assigneeId: assigneeId);

  @override
  CreateAdminModerationCaseRequest note(String note) => this(note: note);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminModerationCaseRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminModerationCaseRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminModerationCaseRequest call({
    Object? assigneeId = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminModerationCaseRequest(
      assigneeId: assigneeId == const $CopyWithPlaceholder()
          ? _value.assigneeId
          // ignore: cast_nullable_to_non_nullable
          : assigneeId as String?,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String,
    );
  }
}

extension $CreateAdminModerationCaseRequestCopyWith
    on CreateAdminModerationCaseRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminModerationCaseRequest.copyWith(...)` or like so:`instanceOfCreateAdminModerationCaseRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminModerationCaseRequestCWProxy get copyWith =>
      _$CreateAdminModerationCaseRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminModerationCaseRequest _$CreateAdminModerationCaseRequestFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('CreateAdminModerationCaseRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['note']);
      final val = CreateAdminModerationCaseRequest(
        assigneeId: $checkedConvert('assignee_id', (v) => v as String?),
        note: $checkedConvert('note', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'assigneeId': 'assignee_id'});

Map<String, dynamic> _$CreateAdminModerationCaseRequestToJson(
  CreateAdminModerationCaseRequest instance,
) => <String, dynamic>{
  'assignee_id': ?instance.assigneeId,
  'note': instance.note,
};
