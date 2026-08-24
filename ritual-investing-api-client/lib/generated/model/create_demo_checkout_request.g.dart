// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_demo_checkout_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateDemoCheckoutRequestCWProxy {
  CreateDemoCheckoutRequest planCode(
    CreateDemoCheckoutRequestPlanCodeEnum planCode,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoCheckoutRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoCheckoutRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoCheckoutRequest call({
    CreateDemoCheckoutRequestPlanCodeEnum planCode,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateDemoCheckoutRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateDemoCheckoutRequest.copyWith.fieldName(...)`
class _$CreateDemoCheckoutRequestCWProxyImpl
    implements _$CreateDemoCheckoutRequestCWProxy {
  const _$CreateDemoCheckoutRequestCWProxyImpl(this._value);

  final CreateDemoCheckoutRequest _value;

  @override
  CreateDemoCheckoutRequest planCode(
    CreateDemoCheckoutRequestPlanCodeEnum planCode,
  ) => this(planCode: planCode);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateDemoCheckoutRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateDemoCheckoutRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateDemoCheckoutRequest call({
    Object? planCode = const $CopyWithPlaceholder(),
  }) {
    return CreateDemoCheckoutRequest(
      planCode: planCode == const $CopyWithPlaceholder()
          ? _value.planCode
          // ignore: cast_nullable_to_non_nullable
          : planCode as CreateDemoCheckoutRequestPlanCodeEnum,
    );
  }
}

extension $CreateDemoCheckoutRequestCopyWith on CreateDemoCheckoutRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateDemoCheckoutRequest.copyWith(...)` or like so:`instanceOfCreateDemoCheckoutRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateDemoCheckoutRequestCWProxy get copyWith =>
      _$CreateDemoCheckoutRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateDemoCheckoutRequest _$CreateDemoCheckoutRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateDemoCheckoutRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['plan_code']);
  final val = CreateDemoCheckoutRequest(
    planCode: $checkedConvert(
      'plan_code',
      (v) => $enumDecode(
        _$CreateDemoCheckoutRequestPlanCodeEnumEnumMap,
        v,
        unknownValue:
            CreateDemoCheckoutRequestPlanCodeEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'planCode': 'plan_code'});

Map<String, dynamic> _$CreateDemoCheckoutRequestToJson(
  CreateDemoCheckoutRequest instance,
) => <String, dynamic>{
  'plan_code':
      _$CreateDemoCheckoutRequestPlanCodeEnumEnumMap[instance.planCode]!,
};

const _$CreateDemoCheckoutRequestPlanCodeEnumEnumMap = {
  CreateDemoCheckoutRequestPlanCodeEnum.premiumDemo: 'premium_demo',
  CreateDemoCheckoutRequestPlanCodeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
