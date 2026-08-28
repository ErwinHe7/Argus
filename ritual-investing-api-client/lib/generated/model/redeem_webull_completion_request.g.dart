// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'redeem_webull_completion_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RedeemWebullCompletionRequestCWProxy {
  RedeemWebullCompletionRequest completion(String completion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RedeemWebullCompletionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RedeemWebullCompletionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RedeemWebullCompletionRequest call({String completion});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRedeemWebullCompletionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRedeemWebullCompletionRequest.copyWith.fieldName(...)`
class _$RedeemWebullCompletionRequestCWProxyImpl
    implements _$RedeemWebullCompletionRequestCWProxy {
  const _$RedeemWebullCompletionRequestCWProxyImpl(this._value);

  final RedeemWebullCompletionRequest _value;

  @override
  RedeemWebullCompletionRequest completion(String completion) =>
      this(completion: completion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RedeemWebullCompletionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RedeemWebullCompletionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RedeemWebullCompletionRequest call({
    Object? completion = const $CopyWithPlaceholder(),
  }) {
    return RedeemWebullCompletionRequest(
      completion: completion == const $CopyWithPlaceholder()
          ? _value.completion
          // ignore: cast_nullable_to_non_nullable
          : completion as String,
    );
  }
}

extension $RedeemWebullCompletionRequestCopyWith
    on RedeemWebullCompletionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRedeemWebullCompletionRequest.copyWith(...)` or like so:`instanceOfRedeemWebullCompletionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RedeemWebullCompletionRequestCWProxy get copyWith =>
      _$RedeemWebullCompletionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RedeemWebullCompletionRequest _$RedeemWebullCompletionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RedeemWebullCompletionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['completion']);
  final val = RedeemWebullCompletionRequest(
    completion: $checkedConvert('completion', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$RedeemWebullCompletionRequestToJson(
  RedeemWebullCompletionRequest instance,
) => <String, dynamic>{'completion': instance.completion};
