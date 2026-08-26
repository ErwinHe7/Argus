// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rebalance_preview.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RebalancePreviewCWProxy {
  RebalancePreview demo(SimulationDemoDisclosure demo);

  RebalancePreview expiresAt(DateTime expiresAt);

  RebalancePreview id(String id);

  RebalancePreview portfolioId(String portfolioId);

  RebalancePreview portfolioVersion(int portfolioVersion);

  RebalancePreview status(RebalancePreviewStatusEnum status);

  RebalancePreview targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner> targetAllocation,
  );

  RebalancePreview trades(List<RebalancePreviewTradesInner> trades);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RebalancePreview(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RebalancePreview(...).copyWith(id: 12, name: "My name")
  /// ````
  RebalancePreview call({
    SimulationDemoDisclosure demo,
    DateTime expiresAt,
    String id,
    String portfolioId,
    int portfolioVersion,
    RebalancePreviewStatusEnum status,
    List<CreatePortfolioRequestTargetAllocationInner> targetAllocation,
    List<RebalancePreviewTradesInner> trades,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRebalancePreview.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRebalancePreview.copyWith.fieldName(...)`
class _$RebalancePreviewCWProxyImpl implements _$RebalancePreviewCWProxy {
  const _$RebalancePreviewCWProxyImpl(this._value);

  final RebalancePreview _value;

  @override
  RebalancePreview demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  RebalancePreview expiresAt(DateTime expiresAt) => this(expiresAt: expiresAt);

  @override
  RebalancePreview id(String id) => this(id: id);

  @override
  RebalancePreview portfolioId(String portfolioId) =>
      this(portfolioId: portfolioId);

  @override
  RebalancePreview portfolioVersion(int portfolioVersion) =>
      this(portfolioVersion: portfolioVersion);

  @override
  RebalancePreview status(RebalancePreviewStatusEnum status) =>
      this(status: status);

  @override
  RebalancePreview targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner> targetAllocation,
  ) => this(targetAllocation: targetAllocation);

  @override
  RebalancePreview trades(List<RebalancePreviewTradesInner> trades) =>
      this(trades: trades);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RebalancePreview(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RebalancePreview(...).copyWith(id: 12, name: "My name")
  /// ````
  RebalancePreview call({
    Object? demo = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? portfolioId = const $CopyWithPlaceholder(),
    Object? portfolioVersion = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? targetAllocation = const $CopyWithPlaceholder(),
    Object? trades = const $CopyWithPlaceholder(),
  }) {
    return RebalancePreview(
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      portfolioId: portfolioId == const $CopyWithPlaceholder()
          ? _value.portfolioId
          // ignore: cast_nullable_to_non_nullable
          : portfolioId as String,
      portfolioVersion: portfolioVersion == const $CopyWithPlaceholder()
          ? _value.portfolioVersion
          // ignore: cast_nullable_to_non_nullable
          : portfolioVersion as int,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as RebalancePreviewStatusEnum,
      targetAllocation: targetAllocation == const $CopyWithPlaceholder()
          ? _value.targetAllocation
          // ignore: cast_nullable_to_non_nullable
          : targetAllocation
                as List<CreatePortfolioRequestTargetAllocationInner>,
      trades: trades == const $CopyWithPlaceholder()
          ? _value.trades
          // ignore: cast_nullable_to_non_nullable
          : trades as List<RebalancePreviewTradesInner>,
    );
  }
}

extension $RebalancePreviewCopyWith on RebalancePreview {
  /// Returns a callable class that can be used as follows: `instanceOfRebalancePreview.copyWith(...)` or like so:`instanceOfRebalancePreview.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RebalancePreviewCWProxy get copyWith => _$RebalancePreviewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RebalancePreview _$RebalancePreviewFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RebalancePreview',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'demo',
            'expires_at',
            'id',
            'portfolio_id',
            'portfolio_version',
            'status',
            'target_allocation',
            'trades',
          ],
        );
        final val = RebalancePreview(
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          expiresAt: $checkedConvert(
            'expires_at',
            (v) => DateTime.parse(v as String),
          ),
          id: $checkedConvert('id', (v) => v as String),
          portfolioId: $checkedConvert('portfolio_id', (v) => v as String),
          portfolioVersion: $checkedConvert(
            'portfolio_version',
            (v) => (v as num).toInt(),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$RebalancePreviewStatusEnumEnumMap,
              v,
              unknownValue: RebalancePreviewStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          targetAllocation: $checkedConvert(
            'target_allocation',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => CreatePortfolioRequestTargetAllocationInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
          ),
          trades: $checkedConvert(
            'trades',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => RebalancePreviewTradesInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'expiresAt': 'expires_at',
        'portfolioId': 'portfolio_id',
        'portfolioVersion': 'portfolio_version',
        'targetAllocation': 'target_allocation',
      },
    );

Map<String, dynamic> _$RebalancePreviewToJson(RebalancePreview instance) =>
    <String, dynamic>{
      'demo': instance.demo.toJson(),
      'expires_at': instance.expiresAt.toIso8601String(),
      'id': instance.id,
      'portfolio_id': instance.portfolioId,
      'portfolio_version': instance.portfolioVersion,
      'status': _$RebalancePreviewStatusEnumEnumMap[instance.status]!,
      'target_allocation': instance.targetAllocation
          .map((e) => e.toJson())
          .toList(),
      'trades': instance.trades.map((e) => e.toJson()).toList(),
    };

const _$RebalancePreviewStatusEnumEnumMap = {
  RebalancePreviewStatusEnum.active: 'active',
  RebalancePreviewStatusEnum.executed: 'executed',
  RebalancePreviewStatusEnum.expired: 'expired',
  RebalancePreviewStatusEnum.invalidated: 'invalidated',
  RebalancePreviewStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
