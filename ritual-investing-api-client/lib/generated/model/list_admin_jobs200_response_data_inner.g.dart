// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_jobs200_response_data_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminJobs200ResponseDataInnerCWProxy {
  ListAdminJobs200ResponseDataInner attempt(int attempt);

  ListAdminJobs200ResponseDataInner completedAt(DateTime? completedAt);

  ListAdminJobs200ResponseDataInner consumer(String consumer);

  ListAdminJobs200ResponseDataInner correlationId(String correlationId);

  ListAdminJobs200ResponseDataInner createdAt(DateTime createdAt);

  ListAdminJobs200ResponseDataInner failureCode(String? failureCode);

  ListAdminJobs200ResponseDataInner id(String id);

  ListAdminJobs200ResponseDataInner outboxId(String outboxId);

  ListAdminJobs200ResponseDataInner status(
    ListAdminJobs200ResponseDataInnerStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminJobs200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminJobs200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminJobs200ResponseDataInner call({
    int attempt,
    DateTime? completedAt,
    String consumer,
    String correlationId,
    DateTime createdAt,
    String? failureCode,
    String id,
    String outboxId,
    ListAdminJobs200ResponseDataInnerStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminJobs200ResponseDataInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminJobs200ResponseDataInner.copyWith.fieldName(...)`
class _$ListAdminJobs200ResponseDataInnerCWProxyImpl
    implements _$ListAdminJobs200ResponseDataInnerCWProxy {
  const _$ListAdminJobs200ResponseDataInnerCWProxyImpl(this._value);

  final ListAdminJobs200ResponseDataInner _value;

  @override
  ListAdminJobs200ResponseDataInner attempt(int attempt) =>
      this(attempt: attempt);

  @override
  ListAdminJobs200ResponseDataInner completedAt(DateTime? completedAt) =>
      this(completedAt: completedAt);

  @override
  ListAdminJobs200ResponseDataInner consumer(String consumer) =>
      this(consumer: consumer);

  @override
  ListAdminJobs200ResponseDataInner correlationId(String correlationId) =>
      this(correlationId: correlationId);

  @override
  ListAdminJobs200ResponseDataInner createdAt(DateTime createdAt) =>
      this(createdAt: createdAt);

  @override
  ListAdminJobs200ResponseDataInner failureCode(String? failureCode) =>
      this(failureCode: failureCode);

  @override
  ListAdminJobs200ResponseDataInner id(String id) => this(id: id);

  @override
  ListAdminJobs200ResponseDataInner outboxId(String outboxId) =>
      this(outboxId: outboxId);

  @override
  ListAdminJobs200ResponseDataInner status(
    ListAdminJobs200ResponseDataInnerStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminJobs200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminJobs200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminJobs200ResponseDataInner call({
    Object? attempt = const $CopyWithPlaceholder(),
    Object? completedAt = const $CopyWithPlaceholder(),
    Object? consumer = const $CopyWithPlaceholder(),
    Object? correlationId = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? failureCode = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? outboxId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return ListAdminJobs200ResponseDataInner(
      attempt: attempt == const $CopyWithPlaceholder()
          ? _value.attempt
          // ignore: cast_nullable_to_non_nullable
          : attempt as int,
      completedAt: completedAt == const $CopyWithPlaceholder()
          ? _value.completedAt
          // ignore: cast_nullable_to_non_nullable
          : completedAt as DateTime?,
      consumer: consumer == const $CopyWithPlaceholder()
          ? _value.consumer
          // ignore: cast_nullable_to_non_nullable
          : consumer as String,
      correlationId: correlationId == const $CopyWithPlaceholder()
          ? _value.correlationId
          // ignore: cast_nullable_to_non_nullable
          : correlationId as String,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      failureCode: failureCode == const $CopyWithPlaceholder()
          ? _value.failureCode
          // ignore: cast_nullable_to_non_nullable
          : failureCode as String?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      outboxId: outboxId == const $CopyWithPlaceholder()
          ? _value.outboxId
          // ignore: cast_nullable_to_non_nullable
          : outboxId as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as ListAdminJobs200ResponseDataInnerStatusEnum,
    );
  }
}

extension $ListAdminJobs200ResponseDataInnerCopyWith
    on ListAdminJobs200ResponseDataInner {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminJobs200ResponseDataInner.copyWith(...)` or like so:`instanceOfListAdminJobs200ResponseDataInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminJobs200ResponseDataInnerCWProxy get copyWith =>
      _$ListAdminJobs200ResponseDataInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminJobs200ResponseDataInner _$ListAdminJobs200ResponseDataInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListAdminJobs200ResponseDataInner',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'attempt',
        'completed_at',
        'consumer',
        'correlation_id',
        'created_at',
        'failure_code',
        'id',
        'outbox_id',
        'status',
      ],
    );
    final val = ListAdminJobs200ResponseDataInner(
      attempt: $checkedConvert('attempt', (v) => (v as num).toInt()),
      completedAt: $checkedConvert(
        'completed_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      consumer: $checkedConvert('consumer', (v) => v as String),
      correlationId: $checkedConvert('correlation_id', (v) => v as String),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      failureCode: $checkedConvert('failure_code', (v) => v as String?),
      id: $checkedConvert('id', (v) => v as String),
      outboxId: $checkedConvert('outbox_id', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$ListAdminJobs200ResponseDataInnerStatusEnumEnumMap,
          v,
          unknownValue:
              ListAdminJobs200ResponseDataInnerStatusEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'completedAt': 'completed_at',
    'correlationId': 'correlation_id',
    'createdAt': 'created_at',
    'failureCode': 'failure_code',
    'outboxId': 'outbox_id',
  },
);

Map<String, dynamic> _$ListAdminJobs200ResponseDataInnerToJson(
  ListAdminJobs200ResponseDataInner instance,
) => <String, dynamic>{
  'attempt': instance.attempt,
  'completed_at': instance.completedAt?.toIso8601String(),
  'consumer': instance.consumer,
  'correlation_id': instance.correlationId,
  'created_at': instance.createdAt.toIso8601String(),
  'failure_code': instance.failureCode,
  'id': instance.id,
  'outbox_id': instance.outboxId,
  'status':
      _$ListAdminJobs200ResponseDataInnerStatusEnumEnumMap[instance.status]!,
};

const _$ListAdminJobs200ResponseDataInnerStatusEnumEnumMap = {
  ListAdminJobs200ResponseDataInnerStatusEnum.leased: 'leased',
  ListAdminJobs200ResponseDataInnerStatusEnum.completed: 'completed',
  ListAdminJobs200ResponseDataInnerStatusEnum.retry: 'retry',
  ListAdminJobs200ResponseDataInnerStatusEnum.deadLetter: 'dead_letter',
  ListAdminJobs200ResponseDataInnerStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
