// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_item_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SaveItemRequestCWProxy {
  SaveItemRequest sourceId(String? sourceId);

  SaveItemRequest sourceKind(SaveItemRequestSourceKindEnum? sourceKind);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SaveItemRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SaveItemRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SaveItemRequest call({
    String? sourceId,
    SaveItemRequestSourceKindEnum? sourceKind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSaveItemRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSaveItemRequest.copyWith.fieldName(...)`
class _$SaveItemRequestCWProxyImpl implements _$SaveItemRequestCWProxy {
  const _$SaveItemRequestCWProxyImpl(this._value);

  final SaveItemRequest _value;

  @override
  SaveItemRequest sourceId(String? sourceId) => this(sourceId: sourceId);

  @override
  SaveItemRequest sourceKind(SaveItemRequestSourceKindEnum? sourceKind) =>
      this(sourceKind: sourceKind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SaveItemRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SaveItemRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  SaveItemRequest call({
    Object? sourceId = const $CopyWithPlaceholder(),
    Object? sourceKind = const $CopyWithPlaceholder(),
  }) {
    return SaveItemRequest(
      sourceId: sourceId == const $CopyWithPlaceholder()
          ? _value.sourceId
          // ignore: cast_nullable_to_non_nullable
          : sourceId as String?,
      sourceKind: sourceKind == const $CopyWithPlaceholder()
          ? _value.sourceKind
          // ignore: cast_nullable_to_non_nullable
          : sourceKind as SaveItemRequestSourceKindEnum?,
    );
  }
}

extension $SaveItemRequestCopyWith on SaveItemRequest {
  /// Returns a callable class that can be used as follows: `instanceOfSaveItemRequest.copyWith(...)` or like so:`instanceOfSaveItemRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SaveItemRequestCWProxy get copyWith => _$SaveItemRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SaveItemRequest _$SaveItemRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SaveItemRequest',
      json,
      ($checkedConvert) {
        final val = SaveItemRequest(
          sourceId: $checkedConvert('source_id', (v) => v as String?),
          sourceKind: $checkedConvert(
            'source_kind',
            (v) => $enumDecodeNullable(
              _$SaveItemRequestSourceKindEnumEnumMap,
              v,
              unknownValue: SaveItemRequestSourceKindEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {'sourceId': 'source_id', 'sourceKind': 'source_kind'},
    );

Map<String, dynamic> _$SaveItemRequestToJson(
  SaveItemRequest instance,
) => <String, dynamic>{
  'source_id': ?instance.sourceId,
  'source_kind': ?_$SaveItemRequestSourceKindEnumEnumMap[instance.sourceKind],
};

const _$SaveItemRequestSourceKindEnumEnumMap = {
  SaveItemRequestSourceKindEnum.ritual: 'ritual',
  SaveItemRequestSourceKindEnum.circle: 'circle',
  SaveItemRequestSourceKindEnum.discover: 'discover',
  SaveItemRequestSourceKindEnum.search: 'search',
  SaveItemRequestSourceKindEnum.direct: 'direct',
  SaveItemRequestSourceKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
