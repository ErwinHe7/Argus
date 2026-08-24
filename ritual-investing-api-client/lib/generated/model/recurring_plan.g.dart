// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_plan.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RecurringPlanCWProxy {
  RecurringPlan allocations(
    List<CreateRecurringPlanRequestAllocationsInner> allocations,
  );

  RecurringPlan amount(Money amount);

  RecurringPlan demo(SimulationDemoDisclosure demo);

  RecurringPlan frequency(RecurringPlanFrequencyEnum frequency);

  RecurringPlan id(String id);

  RecurringPlan nextRunAt(DateTime nextRunAt);

  RecurringPlan portfolioId(String portfolioId);

  RecurringPlan recentRuns(List<RecurringPlanRecentRunsInner> recentRuns);

  RecurringPlan status(RecurringPlanStatusEnum status);

  RecurringPlan type(RecurringPlanTypeEnum type);

  RecurringPlan version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RecurringPlan(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RecurringPlan(...).copyWith(id: 12, name: "My name")
  /// ````
  RecurringPlan call({
    List<CreateRecurringPlanRequestAllocationsInner> allocations,
    Money amount,
    SimulationDemoDisclosure demo,
    RecurringPlanFrequencyEnum frequency,
    String id,
    DateTime nextRunAt,
    String portfolioId,
    List<RecurringPlanRecentRunsInner> recentRuns,
    RecurringPlanStatusEnum status,
    RecurringPlanTypeEnum type,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRecurringPlan.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRecurringPlan.copyWith.fieldName(...)`
class _$RecurringPlanCWProxyImpl implements _$RecurringPlanCWProxy {
  const _$RecurringPlanCWProxyImpl(this._value);

  final RecurringPlan _value;

  @override
  RecurringPlan allocations(
    List<CreateRecurringPlanRequestAllocationsInner> allocations,
  ) => this(allocations: allocations);

  @override
  RecurringPlan amount(Money amount) => this(amount: amount);

  @override
  RecurringPlan demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  RecurringPlan frequency(RecurringPlanFrequencyEnum frequency) =>
      this(frequency: frequency);

  @override
  RecurringPlan id(String id) => this(id: id);

  @override
  RecurringPlan nextRunAt(DateTime nextRunAt) => this(nextRunAt: nextRunAt);

  @override
  RecurringPlan portfolioId(String portfolioId) =>
      this(portfolioId: portfolioId);

  @override
  RecurringPlan recentRuns(List<RecurringPlanRecentRunsInner> recentRuns) =>
      this(recentRuns: recentRuns);

  @override
  RecurringPlan status(RecurringPlanStatusEnum status) => this(status: status);

  @override
  RecurringPlan type(RecurringPlanTypeEnum type) => this(type: type);

  @override
  RecurringPlan version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RecurringPlan(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RecurringPlan(...).copyWith(id: 12, name: "My name")
  /// ````
  RecurringPlan call({
    Object? allocations = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? frequency = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? nextRunAt = const $CopyWithPlaceholder(),
    Object? portfolioId = const $CopyWithPlaceholder(),
    Object? recentRuns = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? type = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return RecurringPlan(
      allocations: allocations == const $CopyWithPlaceholder()
          ? _value.allocations
          // ignore: cast_nullable_to_non_nullable
          : allocations as List<CreateRecurringPlanRequestAllocationsInner>,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as Money,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      frequency: frequency == const $CopyWithPlaceholder()
          ? _value.frequency
          // ignore: cast_nullable_to_non_nullable
          : frequency as RecurringPlanFrequencyEnum,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      nextRunAt: nextRunAt == const $CopyWithPlaceholder()
          ? _value.nextRunAt
          // ignore: cast_nullable_to_non_nullable
          : nextRunAt as DateTime,
      portfolioId: portfolioId == const $CopyWithPlaceholder()
          ? _value.portfolioId
          // ignore: cast_nullable_to_non_nullable
          : portfolioId as String,
      recentRuns: recentRuns == const $CopyWithPlaceholder()
          ? _value.recentRuns
          // ignore: cast_nullable_to_non_nullable
          : recentRuns as List<RecurringPlanRecentRunsInner>,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as RecurringPlanStatusEnum,
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as RecurringPlanTypeEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $RecurringPlanCopyWith on RecurringPlan {
  /// Returns a callable class that can be used as follows: `instanceOfRecurringPlan.copyWith(...)` or like so:`instanceOfRecurringPlan.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RecurringPlanCWProxy get copyWith => _$RecurringPlanCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecurringPlan _$RecurringPlanFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RecurringPlan',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'allocations',
            'amount',
            'demo',
            'frequency',
            'id',
            'next_run_at',
            'portfolio_id',
            'recent_runs',
            'status',
            'type',
            'version',
          ],
        );
        final val = RecurringPlan(
          allocations: $checkedConvert(
            'allocations',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => CreateRecurringPlanRequestAllocationsInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
          ),
          amount: $checkedConvert(
            'amount',
            (v) => Money.fromJson(v as Map<String, dynamic>),
          ),
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          frequency: $checkedConvert(
            'frequency',
            (v) => $enumDecode(
              _$RecurringPlanFrequencyEnumEnumMap,
              v,
              unknownValue: RecurringPlanFrequencyEnum.unknownDefaultOpenApi,
            ),
          ),
          id: $checkedConvert('id', (v) => v as String),
          nextRunAt: $checkedConvert(
            'next_run_at',
            (v) => DateTime.parse(v as String),
          ),
          portfolioId: $checkedConvert('portfolio_id', (v) => v as String),
          recentRuns: $checkedConvert(
            'recent_runs',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => RecurringPlanRecentRunsInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$RecurringPlanStatusEnumEnumMap,
              v,
              unknownValue: RecurringPlanStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          type: $checkedConvert(
            'type',
            (v) => $enumDecode(
              _$RecurringPlanTypeEnumEnumMap,
              v,
              unknownValue: RecurringPlanTypeEnum.unknownDefaultOpenApi,
            ),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'nextRunAt': 'next_run_at',
        'portfolioId': 'portfolio_id',
        'recentRuns': 'recent_runs',
      },
    );

Map<String, dynamic> _$RecurringPlanToJson(RecurringPlan instance) =>
    <String, dynamic>{
      'allocations': instance.allocations.map((e) => e.toJson()).toList(),
      'amount': instance.amount.toJson(),
      'demo': instance.demo.toJson(),
      'frequency': _$RecurringPlanFrequencyEnumEnumMap[instance.frequency]!,
      'id': instance.id,
      'next_run_at': instance.nextRunAt.toIso8601String(),
      'portfolio_id': instance.portfolioId,
      'recent_runs': instance.recentRuns.map((e) => e.toJson()).toList(),
      'status': _$RecurringPlanStatusEnumEnumMap[instance.status]!,
      'type': _$RecurringPlanTypeEnumEnumMap[instance.type]!,
      'version': instance.version,
    };

const _$RecurringPlanFrequencyEnumEnumMap = {
  RecurringPlanFrequencyEnum.weekly: 'weekly',
  RecurringPlanFrequencyEnum.monthly: 'monthly',
  RecurringPlanFrequencyEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$RecurringPlanStatusEnumEnumMap = {
  RecurringPlanStatusEnum.active: 'active',
  RecurringPlanStatusEnum.paused: 'paused',
  RecurringPlanStatusEnum.cancelled: 'cancelled',
  RecurringPlanStatusEnum.completed: 'completed',
  RecurringPlanStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$RecurringPlanTypeEnumEnumMap = {
  RecurringPlanTypeEnum.contribution: 'contribution',
  RecurringPlanTypeEnum.allocation: 'allocation',
  RecurringPlanTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
