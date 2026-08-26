// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_intention_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateIntentionRequestCWProxy {
  CreateIntentionRequest portfolioId(String portfolioId);

  CreateIntentionRequest target(PositiveInputMoney target);

  CreateIntentionRequest targetDate(DateTime targetDate);

  CreateIntentionRequest title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateIntentionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateIntentionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateIntentionRequest call({
    String portfolioId,
    PositiveInputMoney target,
    DateTime targetDate,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateIntentionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateIntentionRequest.copyWith.fieldName(...)`
class _$CreateIntentionRequestCWProxyImpl
    implements _$CreateIntentionRequestCWProxy {
  const _$CreateIntentionRequestCWProxyImpl(this._value);

  final CreateIntentionRequest _value;

  @override
  CreateIntentionRequest portfolioId(String portfolioId) =>
      this(portfolioId: portfolioId);

  @override
  CreateIntentionRequest target(PositiveInputMoney target) =>
      this(target: target);

  @override
  CreateIntentionRequest targetDate(DateTime targetDate) =>
      this(targetDate: targetDate);

  @override
  CreateIntentionRequest title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateIntentionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateIntentionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateIntentionRequest call({
    Object? portfolioId = const $CopyWithPlaceholder(),
    Object? target = const $CopyWithPlaceholder(),
    Object? targetDate = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CreateIntentionRequest(
      portfolioId: portfolioId == const $CopyWithPlaceholder()
          ? _value.portfolioId
          // ignore: cast_nullable_to_non_nullable
          : portfolioId as String,
      target: target == const $CopyWithPlaceholder()
          ? _value.target
          // ignore: cast_nullable_to_non_nullable
          : target as PositiveInputMoney,
      targetDate: targetDate == const $CopyWithPlaceholder()
          ? _value.targetDate
          // ignore: cast_nullable_to_non_nullable
          : targetDate as DateTime,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $CreateIntentionRequestCopyWith on CreateIntentionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateIntentionRequest.copyWith(...)` or like so:`instanceOfCreateIntentionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateIntentionRequestCWProxy get copyWith =>
      _$CreateIntentionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateIntentionRequest _$CreateIntentionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateIntentionRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['portfolio_id', 'target', 'target_date', 'title'],
    );
    final val = CreateIntentionRequest(
      portfolioId: $checkedConvert('portfolio_id', (v) => v as String),
      target: $checkedConvert(
        'target',
        (v) => PositiveInputMoney.fromJson(v as Map<String, dynamic>),
      ),
      targetDate: $checkedConvert(
        'target_date',
        (v) => DateTime.parse(v as String),
      ),
      title: $checkedConvert('title', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'portfolioId': 'portfolio_id',
    'targetDate': 'target_date',
  },
);

Map<String, dynamic> _$CreateIntentionRequestToJson(
  CreateIntentionRequest instance,
) => <String, dynamic>{
  'portfolio_id': instance.portfolioId,
  'target': instance.target.toJson(),
  'target_date': instance.targetDate.toIso8601String(),
  'title': instance.title,
};
