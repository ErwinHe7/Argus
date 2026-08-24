// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simulation_result.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SimulationResultCWProxy {
  SimulationResult commandId(String commandId);

  SimulationResult demo(SimulationDemoDisclosure demo);

  SimulationResult ledgerTransactionIds(List<String> ledgerTransactionIds);

  SimulationResult portfolioVersion(int portfolioVersion);

  SimulationResult projectionLinks(List<String> projectionLinks);

  SimulationResult status(SimulationResultStatusEnum status);

  SimulationResult summary(Map<String, Object?> summary);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulationResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulationResult(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulationResult call({
    String commandId,
    SimulationDemoDisclosure demo,
    List<String> ledgerTransactionIds,
    int portfolioVersion,
    List<String> projectionLinks,
    SimulationResultStatusEnum status,
    Map<String, Object?> summary,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSimulationResult.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSimulationResult.copyWith.fieldName(...)`
class _$SimulationResultCWProxyImpl implements _$SimulationResultCWProxy {
  const _$SimulationResultCWProxyImpl(this._value);

  final SimulationResult _value;

  @override
  SimulationResult commandId(String commandId) => this(commandId: commandId);

  @override
  SimulationResult demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  SimulationResult ledgerTransactionIds(List<String> ledgerTransactionIds) =>
      this(ledgerTransactionIds: ledgerTransactionIds);

  @override
  SimulationResult portfolioVersion(int portfolioVersion) =>
      this(portfolioVersion: portfolioVersion);

  @override
  SimulationResult projectionLinks(List<String> projectionLinks) =>
      this(projectionLinks: projectionLinks);

  @override
  SimulationResult status(SimulationResultStatusEnum status) =>
      this(status: status);

  @override
  SimulationResult summary(Map<String, Object?> summary) =>
      this(summary: summary);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulationResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulationResult(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulationResult call({
    Object? commandId = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? ledgerTransactionIds = const $CopyWithPlaceholder(),
    Object? portfolioVersion = const $CopyWithPlaceholder(),
    Object? projectionLinks = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
  }) {
    return SimulationResult(
      commandId: commandId == const $CopyWithPlaceholder()
          ? _value.commandId
          // ignore: cast_nullable_to_non_nullable
          : commandId as String,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      ledgerTransactionIds: ledgerTransactionIds == const $CopyWithPlaceholder()
          ? _value.ledgerTransactionIds
          // ignore: cast_nullable_to_non_nullable
          : ledgerTransactionIds as List<String>,
      portfolioVersion: portfolioVersion == const $CopyWithPlaceholder()
          ? _value.portfolioVersion
          // ignore: cast_nullable_to_non_nullable
          : portfolioVersion as int,
      projectionLinks: projectionLinks == const $CopyWithPlaceholder()
          ? _value.projectionLinks
          // ignore: cast_nullable_to_non_nullable
          : projectionLinks as List<String>,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as SimulationResultStatusEnum,
      summary: summary == const $CopyWithPlaceholder()
          ? _value.summary
          // ignore: cast_nullable_to_non_nullable
          : summary as Map<String, Object?>,
    );
  }
}

extension $SimulationResultCopyWith on SimulationResult {
  /// Returns a callable class that can be used as follows: `instanceOfSimulationResult.copyWith(...)` or like so:`instanceOfSimulationResult.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SimulationResultCWProxy get copyWith => _$SimulationResultCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimulationResult _$SimulationResultFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SimulationResult',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'command_id',
            'demo',
            'ledger_transaction_ids',
            'portfolio_version',
            'projection_links',
            'status',
            'summary',
          ],
        );
        final val = SimulationResult(
          commandId: $checkedConvert('command_id', (v) => v as String),
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          ledgerTransactionIds: $checkedConvert(
            'ledger_transaction_ids',
            (v) => (v as List<dynamic>).map((e) => e as String).toList(),
          ),
          portfolioVersion: $checkedConvert(
            'portfolio_version',
            (v) => (v as num).toInt(),
          ),
          projectionLinks: $checkedConvert(
            'projection_links',
            (v) => (v as List<dynamic>).map((e) => e as String).toList(),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$SimulationResultStatusEnumEnumMap,
              v,
              unknownValue: SimulationResultStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          summary: $checkedConvert('summary', (v) => v as Map<String, dynamic>),
        );
        return val;
      },
      fieldKeyMap: const {
        'commandId': 'command_id',
        'ledgerTransactionIds': 'ledger_transaction_ids',
        'portfolioVersion': 'portfolio_version',
        'projectionLinks': 'projection_links',
      },
    );

Map<String, dynamic> _$SimulationResultToJson(SimulationResult instance) =>
    <String, dynamic>{
      'command_id': instance.commandId,
      'demo': instance.demo.toJson(),
      'ledger_transaction_ids': instance.ledgerTransactionIds,
      'portfolio_version': instance.portfolioVersion,
      'projection_links': instance.projectionLinks,
      'status': _$SimulationResultStatusEnumEnumMap[instance.status]!,
      'summary': instance.summary,
    };

const _$SimulationResultStatusEnumEnumMap = {
  SimulationResultStatusEnum.committed: 'committed',
  SimulationResultStatusEnum.rejected: 'rejected',
  SimulationResultStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
