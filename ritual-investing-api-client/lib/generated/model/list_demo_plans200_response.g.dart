// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_demo_plans200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListDemoPlans200ResponseCWProxy {
  ListDemoPlans200Response data(List<DemoPlan> data);

  ListDemoPlans200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListDemoPlans200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListDemoPlans200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListDemoPlans200Response call({List<DemoPlan> data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListDemoPlans200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListDemoPlans200Response.copyWith.fieldName(...)`
class _$ListDemoPlans200ResponseCWProxyImpl
    implements _$ListDemoPlans200ResponseCWProxy {
  const _$ListDemoPlans200ResponseCWProxyImpl(this._value);

  final ListDemoPlans200Response _value;

  @override
  ListDemoPlans200Response data(List<DemoPlan> data) => this(data: data);

  @override
  ListDemoPlans200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListDemoPlans200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListDemoPlans200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListDemoPlans200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListDemoPlans200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<DemoPlan>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $ListDemoPlans200ResponseCopyWith on ListDemoPlans200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListDemoPlans200Response.copyWith(...)` or like so:`instanceOfListDemoPlans200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListDemoPlans200ResponseCWProxy get copyWith =>
      _$ListDemoPlans200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListDemoPlans200Response _$ListDemoPlans200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListDemoPlans200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListDemoPlans200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => DemoPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListDemoPlans200ResponseToJson(
  ListDemoPlans200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
