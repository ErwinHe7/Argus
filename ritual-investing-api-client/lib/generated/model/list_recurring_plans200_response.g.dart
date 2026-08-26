// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_recurring_plans200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListRecurringPlans200ResponseCWProxy {
  ListRecurringPlans200Response data(List<RecurringPlan> data);

  ListRecurringPlans200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListRecurringPlans200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListRecurringPlans200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListRecurringPlans200Response call({
    List<RecurringPlan> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListRecurringPlans200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListRecurringPlans200Response.copyWith.fieldName(...)`
class _$ListRecurringPlans200ResponseCWProxyImpl
    implements _$ListRecurringPlans200ResponseCWProxy {
  const _$ListRecurringPlans200ResponseCWProxyImpl(this._value);

  final ListRecurringPlans200Response _value;

  @override
  ListRecurringPlans200Response data(List<RecurringPlan> data) =>
      this(data: data);

  @override
  ListRecurringPlans200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListRecurringPlans200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListRecurringPlans200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListRecurringPlans200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListRecurringPlans200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<RecurringPlan>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListRecurringPlans200ResponseCopyWith
    on ListRecurringPlans200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListRecurringPlans200Response.copyWith(...)` or like so:`instanceOfListRecurringPlans200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListRecurringPlans200ResponseCWProxy get copyWith =>
      _$ListRecurringPlans200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListRecurringPlans200Response _$ListRecurringPlans200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListRecurringPlans200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListRecurringPlans200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => RecurringPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListRecurringPlans200ResponseToJson(
  ListRecurringPlans200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
