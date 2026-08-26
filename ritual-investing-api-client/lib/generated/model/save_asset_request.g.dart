// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_asset_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SaveAssetRequestCWProxy {
  SaveAssetRequest sourceId(String? sourceId);

  SaveAssetRequest sourceKind(SaveAssetRequestSourceKindEnum? sourceKind);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SaveAssetRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SaveAssetRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SaveAssetRequest call({
    String? sourceId,
    SaveAssetRequestSourceKindEnum? sourceKind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSaveAssetRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSaveAssetRequest.copyWith.fieldName(...)`
class _$SaveAssetRequestCWProxyImpl implements _$SaveAssetRequestCWProxy {
  const _$SaveAssetRequestCWProxyImpl(this._value);

  final SaveAssetRequest _value;

  @override
  SaveAssetRequest sourceId(String? sourceId) => this(sourceId: sourceId);

  @override
  SaveAssetRequest sourceKind(SaveAssetRequestSourceKindEnum? sourceKind) =>
      this(sourceKind: sourceKind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SaveAssetRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SaveAssetRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SaveAssetRequest call({
    Object? sourceId = const $CopyWithPlaceholder(),
    Object? sourceKind = const $CopyWithPlaceholder(),
  }) {
    return SaveAssetRequest(
      sourceId: sourceId == const $CopyWithPlaceholder()
          ? _value.sourceId
          // ignore: cast_nullable_to_non_nullable
          : sourceId as String?,
      sourceKind: sourceKind == const $CopyWithPlaceholder()
          ? _value.sourceKind
          // ignore: cast_nullable_to_non_nullable
          : sourceKind as SaveAssetRequestSourceKindEnum?,
    );
  }
}

extension $SaveAssetRequestCopyWith on SaveAssetRequest {
  /// Returns a callable class that can be used as follows: `instanceOfSaveAssetRequest.copyWith(...)` or like so:`instanceOfSaveAssetRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SaveAssetRequestCWProxy get copyWith => _$SaveAssetRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SaveAssetRequest _$SaveAssetRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SaveAssetRequest', json, ($checkedConvert) {
  final val = SaveAssetRequest(
    sourceId: $checkedConvert('source_id', (v) => v as String?),
    sourceKind: $checkedConvert(
      'source_kind',
      (v) => $enumDecodeNullable(
        _$SaveAssetRequestSourceKindEnumEnumMap,
        v,
        unknownValue: SaveAssetRequestSourceKindEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'sourceId': 'source_id', 'sourceKind': 'source_kind'});

Map<String, dynamic> _$SaveAssetRequestToJson(
  SaveAssetRequest instance,
) => <String, dynamic>{
  'source_id': ?instance.sourceId,
  'source_kind': ?_$SaveAssetRequestSourceKindEnumEnumMap[instance.sourceKind],
};

const _$SaveAssetRequestSourceKindEnumEnumMap = {
  SaveAssetRequestSourceKindEnum.ritual: 'ritual',
  SaveAssetRequestSourceKindEnum.circle: 'circle',
  SaveAssetRequestSourceKindEnum.discover: 'discover',
  SaveAssetRequestSourceKindEnum.search: 'search',
  SaveAssetRequestSourceKindEnum.direct: 'direct',
  SaveAssetRequestSourceKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
