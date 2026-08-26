// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_reset_result.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DemoResetResultCWProxy {
  DemoResetResult defaultPortfolio(
    DemoResetResultDefaultPortfolio defaultPortfolio,
  );

  DemoResetResult demo(SimulationDemoDisclosure demo);

  DemoResetResult entitlement(DemoResetResultEntitlement entitlement);

  DemoResetResult resetGeneration(int resetGeneration);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoResetResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoResetResult(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoResetResult call({
    DemoResetResultDefaultPortfolio defaultPortfolio,
    SimulationDemoDisclosure demo,
    DemoResetResultEntitlement entitlement,
    int resetGeneration,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDemoResetResult.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDemoResetResult.copyWith.fieldName(...)`
class _$DemoResetResultCWProxyImpl implements _$DemoResetResultCWProxy {
  const _$DemoResetResultCWProxyImpl(this._value);

  final DemoResetResult _value;

  @override
  DemoResetResult defaultPortfolio(
    DemoResetResultDefaultPortfolio defaultPortfolio,
  ) => this(defaultPortfolio: defaultPortfolio);

  @override
  DemoResetResult demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  DemoResetResult entitlement(DemoResetResultEntitlement entitlement) =>
      this(entitlement: entitlement);

  @override
  DemoResetResult resetGeneration(int resetGeneration) =>
      this(resetGeneration: resetGeneration);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DemoResetResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DemoResetResult(...).copyWith(id: 12, name: "My name")
  /// ````
  DemoResetResult call({
    Object? defaultPortfolio = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? entitlement = const $CopyWithPlaceholder(),
    Object? resetGeneration = const $CopyWithPlaceholder(),
  }) {
    return DemoResetResult(
      defaultPortfolio: defaultPortfolio == const $CopyWithPlaceholder()
          ? _value.defaultPortfolio
          // ignore: cast_nullable_to_non_nullable
          : defaultPortfolio as DemoResetResultDefaultPortfolio,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      entitlement: entitlement == const $CopyWithPlaceholder()
          ? _value.entitlement
          // ignore: cast_nullable_to_non_nullable
          : entitlement as DemoResetResultEntitlement,
      resetGeneration: resetGeneration == const $CopyWithPlaceholder()
          ? _value.resetGeneration
          // ignore: cast_nullable_to_non_nullable
          : resetGeneration as int,
    );
  }
}

extension $DemoResetResultCopyWith on DemoResetResult {
  /// Returns a callable class that can be used as follows: `instanceOfDemoResetResult.copyWith(...)` or like so:`instanceOfDemoResetResult.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DemoResetResultCWProxy get copyWith => _$DemoResetResultCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DemoResetResult _$DemoResetResultFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'DemoResetResult',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'default_portfolio',
            'demo',
            'entitlement',
            'reset_generation',
          ],
        );
        final val = DemoResetResult(
          defaultPortfolio: $checkedConvert(
            'default_portfolio',
            (v) => DemoResetResultDefaultPortfolio.fromJson(
              v as Map<String, dynamic>,
            ),
          ),
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          entitlement: $checkedConvert(
            'entitlement',
            (v) =>
                DemoResetResultEntitlement.fromJson(v as Map<String, dynamic>),
          ),
          resetGeneration: $checkedConvert(
            'reset_generation',
            (v) => (v as num).toInt(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'defaultPortfolio': 'default_portfolio',
        'resetGeneration': 'reset_generation',
      },
    );

Map<String, dynamic> _$DemoResetResultToJson(DemoResetResult instance) =>
    <String, dynamic>{
      'default_portfolio': instance.defaultPortfolio.toJson(),
      'demo': instance.demo.toJson(),
      'entitlement': instance.entitlement.toJson(),
      'reset_generation': instance.resetGeneration,
    };
