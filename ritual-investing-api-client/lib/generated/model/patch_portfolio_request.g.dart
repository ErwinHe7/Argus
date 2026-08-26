// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_portfolio_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchPortfolioRequestCWProxy {
  PatchPortfolioRequest name(String? name);

  PatchPortfolioRequest targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner>? targetAllocation,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchPortfolioRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchPortfolioRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchPortfolioRequest call({
    String? name,
    List<CreatePortfolioRequestTargetAllocationInner>? targetAllocation,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchPortfolioRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchPortfolioRequest.copyWith.fieldName(...)`
class _$PatchPortfolioRequestCWProxyImpl
    implements _$PatchPortfolioRequestCWProxy {
  const _$PatchPortfolioRequestCWProxyImpl(this._value);

  final PatchPortfolioRequest _value;

  @override
  PatchPortfolioRequest name(String? name) => this(name: name);

  @override
  PatchPortfolioRequest targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner>? targetAllocation,
  ) => this(targetAllocation: targetAllocation);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchPortfolioRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchPortfolioRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchPortfolioRequest call({
    Object? name = const $CopyWithPlaceholder(),
    Object? targetAllocation = const $CopyWithPlaceholder(),
  }) {
    return PatchPortfolioRequest(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String?,
      targetAllocation: targetAllocation == const $CopyWithPlaceholder()
          ? _value.targetAllocation
          // ignore: cast_nullable_to_non_nullable
          : targetAllocation
                as List<CreatePortfolioRequestTargetAllocationInner>?,
    );
  }
}

extension $PatchPortfolioRequestCopyWith on PatchPortfolioRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchPortfolioRequest.copyWith(...)` or like so:`instanceOfPatchPortfolioRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchPortfolioRequestCWProxy get copyWith =>
      _$PatchPortfolioRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchPortfolioRequest _$PatchPortfolioRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchPortfolioRequest', json, ($checkedConvert) {
  final val = PatchPortfolioRequest(
    name: $checkedConvert('name', (v) => v as String?),
    targetAllocation: $checkedConvert(
      'target_allocation',
      (v) => (v as List<dynamic>?)
          ?.map(
            (e) => CreatePortfolioRequestTargetAllocationInner.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'targetAllocation': 'target_allocation'});

Map<String, dynamic> _$PatchPortfolioRequestToJson(
  PatchPortfolioRequest instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'target_allocation': ?instance.targetAllocation
      ?.map((e) => e.toJson())
      .toList(),
};
