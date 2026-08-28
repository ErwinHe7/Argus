// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_hypothetical_future_mirror.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateHypotheticalFutureMirrorCWProxy {
  CreateHypotheticalFutureMirror annualReturnBps(
    CreateHypotheticalFutureMirrorAnnualReturnBps annualReturnBps,
  );

  CreateHypotheticalFutureMirror asOfDate(DateTime asOfDate);

  CreateHypotheticalFutureMirror baseline(ScenarioMoney baseline);

  CreateHypotheticalFutureMirror monthlyContribution(
    ScenarioMoney monthlyContribution,
  );

  CreateHypotheticalFutureMirror name(String name);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateHypotheticalFutureMirror(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateHypotheticalFutureMirror(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateHypotheticalFutureMirror call({
    CreateHypotheticalFutureMirrorAnnualReturnBps annualReturnBps,
    DateTime asOfDate,
    ScenarioMoney baseline,
    ScenarioMoney monthlyContribution,
    String name,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateHypotheticalFutureMirror.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateHypotheticalFutureMirror.copyWith.fieldName(...)`
class _$CreateHypotheticalFutureMirrorCWProxyImpl
    implements _$CreateHypotheticalFutureMirrorCWProxy {
  const _$CreateHypotheticalFutureMirrorCWProxyImpl(this._value);

  final CreateHypotheticalFutureMirror _value;

  @override
  CreateHypotheticalFutureMirror annualReturnBps(
    CreateHypotheticalFutureMirrorAnnualReturnBps annualReturnBps,
  ) => this(annualReturnBps: annualReturnBps);

  @override
  CreateHypotheticalFutureMirror asOfDate(DateTime asOfDate) =>
      this(asOfDate: asOfDate);

  @override
  CreateHypotheticalFutureMirror baseline(ScenarioMoney baseline) =>
      this(baseline: baseline);

  @override
  CreateHypotheticalFutureMirror monthlyContribution(
    ScenarioMoney monthlyContribution,
  ) => this(monthlyContribution: monthlyContribution);

  @override
  CreateHypotheticalFutureMirror name(String name) => this(name: name);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateHypotheticalFutureMirror(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateHypotheticalFutureMirror(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateHypotheticalFutureMirror call({
    Object? annualReturnBps = const $CopyWithPlaceholder(),
    Object? asOfDate = const $CopyWithPlaceholder(),
    Object? baseline = const $CopyWithPlaceholder(),
    Object? monthlyContribution = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
  }) {
    return CreateHypotheticalFutureMirror(
      annualReturnBps: annualReturnBps == const $CopyWithPlaceholder()
          ? _value.annualReturnBps
          // ignore: cast_nullable_to_non_nullable
          : annualReturnBps as CreateHypotheticalFutureMirrorAnnualReturnBps,
      asOfDate: asOfDate == const $CopyWithPlaceholder()
          ? _value.asOfDate
          // ignore: cast_nullable_to_non_nullable
          : asOfDate as DateTime,
      baseline: baseline == const $CopyWithPlaceholder()
          ? _value.baseline
          // ignore: cast_nullable_to_non_nullable
          : baseline as ScenarioMoney,
      monthlyContribution: monthlyContribution == const $CopyWithPlaceholder()
          ? _value.monthlyContribution
          // ignore: cast_nullable_to_non_nullable
          : monthlyContribution as ScenarioMoney,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
    );
  }
}

extension $CreateHypotheticalFutureMirrorCopyWith
    on CreateHypotheticalFutureMirror {
  /// Returns a callable class that can be used as follows: `instanceOfCreateHypotheticalFutureMirror.copyWith(...)` or like so:`instanceOfCreateHypotheticalFutureMirror.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateHypotheticalFutureMirrorCWProxy get copyWith =>
      _$CreateHypotheticalFutureMirrorCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateHypotheticalFutureMirror _$CreateHypotheticalFutureMirrorFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateHypotheticalFutureMirror',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'annual_return_bps',
        'as_of_date',
        'baseline',
        'monthly_contribution',
        'name',
      ],
    );
    final val = CreateHypotheticalFutureMirror(
      annualReturnBps: $checkedConvert(
        'annual_return_bps',
        (v) => CreateHypotheticalFutureMirrorAnnualReturnBps.fromJson(
          v as Map<String, dynamic>,
        ),
      ),
      asOfDate: $checkedConvert(
        'as_of_date',
        (v) => DateTime.parse(v as String),
      ),
      baseline: $checkedConvert(
        'baseline',
        (v) => ScenarioMoney.fromJson(v as Map<String, dynamic>),
      ),
      monthlyContribution: $checkedConvert(
        'monthly_contribution',
        (v) => ScenarioMoney.fromJson(v as Map<String, dynamic>),
      ),
      name: $checkedConvert('name', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'annualReturnBps': 'annual_return_bps',
    'asOfDate': 'as_of_date',
    'monthlyContribution': 'monthly_contribution',
  },
);

Map<String, dynamic> _$CreateHypotheticalFutureMirrorToJson(
  CreateHypotheticalFutureMirror instance,
) => <String, dynamic>{
  'annual_return_bps': instance.annualReturnBps.toJson(),
  'as_of_date': instance.asOfDate.toIso8601String(),
  'baseline': instance.baseline.toJson(),
  'monthly_contribution': instance.monthlyContribution.toJson(),
  'name': instance.name,
};
