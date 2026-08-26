// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_future_mirror_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateFutureMirrorRequestCWProxy {
  CreateFutureMirrorRequest annualReturnBps(
    CreateFutureMirrorRequestAnnualReturnBps annualReturnBps,
  );

  CreateFutureMirrorRequest monthlyContribution(InputMoney monthlyContribution);

  CreateFutureMirrorRequest name(String name);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateFutureMirrorRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateFutureMirrorRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateFutureMirrorRequest call({
    CreateFutureMirrorRequestAnnualReturnBps annualReturnBps,
    InputMoney monthlyContribution,
    String name,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateFutureMirrorRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateFutureMirrorRequest.copyWith.fieldName(...)`
class _$CreateFutureMirrorRequestCWProxyImpl
    implements _$CreateFutureMirrorRequestCWProxy {
  const _$CreateFutureMirrorRequestCWProxyImpl(this._value);

  final CreateFutureMirrorRequest _value;

  @override
  CreateFutureMirrorRequest annualReturnBps(
    CreateFutureMirrorRequestAnnualReturnBps annualReturnBps,
  ) => this(annualReturnBps: annualReturnBps);

  @override
  CreateFutureMirrorRequest monthlyContribution(
    InputMoney monthlyContribution,
  ) => this(monthlyContribution: monthlyContribution);

  @override
  CreateFutureMirrorRequest name(String name) => this(name: name);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateFutureMirrorRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateFutureMirrorRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateFutureMirrorRequest call({
    Object? annualReturnBps = const $CopyWithPlaceholder(),
    Object? monthlyContribution = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
  }) {
    return CreateFutureMirrorRequest(
      annualReturnBps: annualReturnBps == const $CopyWithPlaceholder()
          ? _value.annualReturnBps
          // ignore: cast_nullable_to_non_nullable
          : annualReturnBps as CreateFutureMirrorRequestAnnualReturnBps,
      monthlyContribution: monthlyContribution == const $CopyWithPlaceholder()
          ? _value.monthlyContribution
          // ignore: cast_nullable_to_non_nullable
          : monthlyContribution as InputMoney,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
    );
  }
}

extension $CreateFutureMirrorRequestCopyWith on CreateFutureMirrorRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateFutureMirrorRequest.copyWith(...)` or like so:`instanceOfCreateFutureMirrorRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateFutureMirrorRequestCWProxy get copyWith =>
      _$CreateFutureMirrorRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateFutureMirrorRequest _$CreateFutureMirrorRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateFutureMirrorRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['annual_return_bps', 'monthly_contribution', 'name'],
    );
    final val = CreateFutureMirrorRequest(
      annualReturnBps: $checkedConvert(
        'annual_return_bps',
        (v) => CreateFutureMirrorRequestAnnualReturnBps.fromJson(
          v as Map<String, dynamic>,
        ),
      ),
      monthlyContribution: $checkedConvert(
        'monthly_contribution',
        (v) => InputMoney.fromJson(v as Map<String, dynamic>),
      ),
      name: $checkedConvert('name', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'annualReturnBps': 'annual_return_bps',
    'monthlyContribution': 'monthly_contribution',
  },
);

Map<String, dynamic> _$CreateFutureMirrorRequestToJson(
  CreateFutureMirrorRequest instance,
) => <String, dynamic>{
  'annual_return_bps': instance.annualReturnBps.toJson(),
  'monthly_contribution': instance.monthlyContribution.toJson(),
  'name': instance.name,
};
