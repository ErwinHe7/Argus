// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner_revision.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerRevisionCWProxy {
  ListAdminAssetCodex200ResponseDataInnerRevision authorStaffId(
    String authorStaffId,
  );

  ListAdminAssetCodex200ResponseDataInnerRevision etag(String etag);

  ListAdminAssetCodex200ResponseDataInnerRevision id(String id);

  ListAdminAssetCodex200ResponseDataInnerRevision payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayload payload,
  );

  ListAdminAssetCodex200ResponseDataInnerRevision revisionNumber(
    int revisionNumber,
  );

  ListAdminAssetCodex200ResponseDataInnerRevision state(
    ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum state,
  );

  ListAdminAssetCodex200ResponseDataInnerRevision version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevision(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevision(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevision call({
    String authorStaffId,
    String etag,
    String id,
    ListAdminAssetCodex200ResponseDataInnerRevisionPayload payload,
    int revisionNumber,
    ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum state,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevision.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInnerRevision.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerRevisionCWProxyImpl
    implements _$ListAdminAssetCodex200ResponseDataInnerRevisionCWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerRevisionCWProxyImpl(
    this._value,
  );

  final ListAdminAssetCodex200ResponseDataInnerRevision _value;

  @override
  ListAdminAssetCodex200ResponseDataInnerRevision authorStaffId(
    String authorStaffId,
  ) => this(authorStaffId: authorStaffId);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevision etag(String etag) =>
      this(etag: etag);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevision id(String id) => this(id: id);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevision payload(
    ListAdminAssetCodex200ResponseDataInnerRevisionPayload payload,
  ) => this(payload: payload);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevision revisionNumber(
    int revisionNumber,
  ) => this(revisionNumber: revisionNumber);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevision state(
    ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum state,
  ) => this(state: state);

  @override
  ListAdminAssetCodex200ResponseDataInnerRevision version(int version) =>
      this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInnerRevision(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInnerRevision(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInnerRevision call({
    Object? authorStaffId = const $CopyWithPlaceholder(),
    Object? etag = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? payload = const $CopyWithPlaceholder(),
    Object? revisionNumber = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInnerRevision(
      authorStaffId: authorStaffId == const $CopyWithPlaceholder()
          ? _value.authorStaffId
          // ignore: cast_nullable_to_non_nullable
          : authorStaffId as String,
      etag: etag == const $CopyWithPlaceholder()
          ? _value.etag
          // ignore: cast_nullable_to_non_nullable
          : etag as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload as ListAdminAssetCodex200ResponseDataInnerRevisionPayload,
      revisionNumber: revisionNumber == const $CopyWithPlaceholder()
          ? _value.revisionNumber
          // ignore: cast_nullable_to_non_nullable
          : revisionNumber as int,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerRevisionCopyWith
    on ListAdminAssetCodex200ResponseDataInnerRevision {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInnerRevision.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInnerRevision.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerRevisionCWProxy get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInnerRevision
_$ListAdminAssetCodex200ResponseDataInnerRevisionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminAssetCodex200ResponseDataInnerRevision',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'author_staff_id',
        'etag',
        'id',
        'payload',
        'revision_number',
        'state',
        'version',
      ],
    );
    final val = ListAdminAssetCodex200ResponseDataInnerRevision(
      authorStaffId: $checkedConvert('author_staff_id', (v) => v as String),
      etag: $checkedConvert('etag', (v) => v as String),
      id: $checkedConvert('id', (v) => v as String),
      payload: $checkedConvert(
        'payload',
        (v) => ListAdminAssetCodex200ResponseDataInnerRevisionPayload.fromJson(
          v as Map<String, dynamic>,
        ),
      ),
      revisionNumber: $checkedConvert(
        'revision_number',
        (v) => (v as num).toInt(),
      ),
      state: $checkedConvert(
        'state',
        (v) => $enumDecode(
          _$ListAdminAssetCodex200ResponseDataInnerRevisionStateEnumEnumMap,
          v,
          unknownValue: ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum
              .unknownDefaultOpenApi,
        ),
      ),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'authorStaffId': 'author_staff_id',
    'revisionNumber': 'revision_number',
  },
);

Map<String, dynamic> _$ListAdminAssetCodex200ResponseDataInnerRevisionToJson(
  ListAdminAssetCodex200ResponseDataInnerRevision instance,
) => <String, dynamic>{
  'author_staff_id': instance.authorStaffId,
  'etag': instance.etag,
  'id': instance.id,
  'payload': instance.payload.toJson(),
  'revision_number': instance.revisionNumber,
  'state':
      _$ListAdminAssetCodex200ResponseDataInnerRevisionStateEnumEnumMap[instance
          .state]!,
  'version': instance.version,
};

const _$ListAdminAssetCodex200ResponseDataInnerRevisionStateEnumEnumMap = {
  ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum.draft: 'draft',
  ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum.inReview:
      'in_review',
  ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum.approved: 'approved',
  ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum.changesRequested:
      'changes_requested',
  ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum.rejected: 'rejected',
  ListAdminAssetCodex200ResponseDataInnerRevisionStateEnum
          .unknownDefaultOpenApi:
      'unknown_default_open_api',
};
