// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_rebalance_preview_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateRebalancePreviewRequestCWProxy {
  CreateRebalancePreviewRequest targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner> targetAllocation,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRebalancePreviewRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRebalancePreviewRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRebalancePreviewRequest call({
    List<CreatePortfolioRequestTargetAllocationInner> targetAllocation,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateRebalancePreviewRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateRebalancePreviewRequest.copyWith.fieldName(...)`
class _$CreateRebalancePreviewRequestCWProxyImpl
    implements _$CreateRebalancePreviewRequestCWProxy {
  const _$CreateRebalancePreviewRequestCWProxyImpl(this._value);

  final CreateRebalancePreviewRequest _value;

  @override
  CreateRebalancePreviewRequest targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner> targetAllocation,
  ) => this(targetAllocation: targetAllocation);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRebalancePreviewRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRebalancePreviewRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRebalancePreviewRequest call({
    Object? targetAllocation = const $CopyWithPlaceholder(),
  }) {
    return CreateRebalancePreviewRequest(
      targetAllocation: targetAllocation == const $CopyWithPlaceholder()
          ? _value.targetAllocation
          // ignore: cast_nullable_to_non_nullable
          : targetAllocation
                as List<CreatePortfolioRequestTargetAllocationInner>,
    );
  }
}

extension $CreateRebalancePreviewRequestCopyWith
    on CreateRebalancePreviewRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateRebalancePreviewRequest.copyWith(...)` or like so:`instanceOfCreateRebalancePreviewRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateRebalancePreviewRequestCWProxy get copyWith =>
      _$CreateRebalancePreviewRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateRebalancePreviewRequest _$CreateRebalancePreviewRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateRebalancePreviewRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['target_allocation']);
  final val = CreateRebalancePreviewRequest(
    targetAllocation: $checkedConvert(
      'target_allocation',
      (v) => (v as List<dynamic>)
          .map(
            (e) => CreatePortfolioRequestTargetAllocationInner.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'targetAllocation': 'target_allocation'});

Map<String, dynamic> _$CreateRebalancePreviewRequestToJson(
  CreateRebalancePreviewRequest instance,
) => <String, dynamic>{
  'target_allocation': instance.targetAllocation
      .map((e) => e.toJson())
      .toList(),
};
