// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_order_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CommitOrderRequestCWProxy {
  CommitOrderRequest portfolioVersion(int portfolioVersion);

  CommitOrderRequest previewId(String previewId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CommitOrderRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CommitOrderRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CommitOrderRequest call({int portfolioVersion, String previewId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCommitOrderRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCommitOrderRequest.copyWith.fieldName(...)`
class _$CommitOrderRequestCWProxyImpl implements _$CommitOrderRequestCWProxy {
  const _$CommitOrderRequestCWProxyImpl(this._value);

  final CommitOrderRequest _value;

  @override
  CommitOrderRequest portfolioVersion(int portfolioVersion) =>
      this(portfolioVersion: portfolioVersion);

  @override
  CommitOrderRequest previewId(String previewId) => this(previewId: previewId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CommitOrderRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CommitOrderRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CommitOrderRequest call({
    Object? portfolioVersion = const $CopyWithPlaceholder(),
    Object? previewId = const $CopyWithPlaceholder(),
  }) {
    return CommitOrderRequest(
      portfolioVersion: portfolioVersion == const $CopyWithPlaceholder()
          ? _value.portfolioVersion
          // ignore: cast_nullable_to_non_nullable
          : portfolioVersion as int,
      previewId: previewId == const $CopyWithPlaceholder()
          ? _value.previewId
          // ignore: cast_nullable_to_non_nullable
          : previewId as String,
    );
  }
}

extension $CommitOrderRequestCopyWith on CommitOrderRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCommitOrderRequest.copyWith(...)` or like so:`instanceOfCommitOrderRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CommitOrderRequestCWProxy get copyWith =>
      _$CommitOrderRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommitOrderRequest _$CommitOrderRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CommitOrderRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['portfolio_version', 'preview_id'],
        );
        final val = CommitOrderRequest(
          portfolioVersion: $checkedConvert(
            'portfolio_version',
            (v) => (v as num).toInt(),
          ),
          previewId: $checkedConvert('preview_id', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'portfolioVersion': 'portfolio_version',
        'previewId': 'preview_id',
      },
    );

Map<String, dynamic> _$CommitOrderRequestToJson(CommitOrderRequest instance) =>
    <String, dynamic>{
      'portfolio_version': instance.portfolioVersion,
      'preview_id': instance.previewId,
    };
