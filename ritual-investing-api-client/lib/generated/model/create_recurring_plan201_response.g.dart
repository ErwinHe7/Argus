// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_recurring_plan201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateRecurringPlan201ResponseCWProxy {
  CreateRecurringPlan201Response data(RecurringPlan data);

  CreateRecurringPlan201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRecurringPlan201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRecurringPlan201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRecurringPlan201Response call({RecurringPlan data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateRecurringPlan201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateRecurringPlan201Response.copyWith.fieldName(...)`
class _$CreateRecurringPlan201ResponseCWProxyImpl
    implements _$CreateRecurringPlan201ResponseCWProxy {
  const _$CreateRecurringPlan201ResponseCWProxyImpl(this._value);

  final CreateRecurringPlan201Response _value;

  @override
  CreateRecurringPlan201Response data(RecurringPlan data) => this(data: data);

  @override
  CreateRecurringPlan201Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRecurringPlan201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRecurringPlan201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRecurringPlan201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateRecurringPlan201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as RecurringPlan,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateRecurringPlan201ResponseCopyWith
    on CreateRecurringPlan201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateRecurringPlan201Response.copyWith(...)` or like so:`instanceOfCreateRecurringPlan201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateRecurringPlan201ResponseCWProxy get copyWith =>
      _$CreateRecurringPlan201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateRecurringPlan201Response _$CreateRecurringPlan201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateRecurringPlan201Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateRecurringPlan201Response(
    data: $checkedConvert(
      'data',
      (v) => RecurringPlan.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateRecurringPlan201ResponseToJson(
  CreateRecurringPlan201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
