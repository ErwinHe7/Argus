// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_content_report201_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateContentReport201ResponseDataCWProxy {
  CreateContentReport201ResponseData id(String id);

  CreateContentReport201ResponseData status(
    CreateContentReport201ResponseDataStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateContentReport201ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateContentReport201ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateContentReport201ResponseData call({
    String id,
    CreateContentReport201ResponseDataStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateContentReport201ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateContentReport201ResponseData.copyWith.fieldName(...)`
class _$CreateContentReport201ResponseDataCWProxyImpl
    implements _$CreateContentReport201ResponseDataCWProxy {
  const _$CreateContentReport201ResponseDataCWProxyImpl(this._value);

  final CreateContentReport201ResponseData _value;

  @override
  CreateContentReport201ResponseData id(String id) => this(id: id);

  @override
  CreateContentReport201ResponseData status(
    CreateContentReport201ResponseDataStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateContentReport201ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateContentReport201ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateContentReport201ResponseData call({
    Object? id = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return CreateContentReport201ResponseData(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as CreateContentReport201ResponseDataStatusEnum,
    );
  }
}

extension $CreateContentReport201ResponseDataCopyWith
    on CreateContentReport201ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfCreateContentReport201ResponseData.copyWith(...)` or like so:`instanceOfCreateContentReport201ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateContentReport201ResponseDataCWProxy get copyWith =>
      _$CreateContentReport201ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateContentReport201ResponseData _$CreateContentReport201ResponseDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateContentReport201ResponseData', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['id', 'status']);
  final val = CreateContentReport201ResponseData(
    id: $checkedConvert('id', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$CreateContentReport201ResponseDataStatusEnumEnumMap,
        v,
        unknownValue:
            CreateContentReport201ResponseDataStatusEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateContentReport201ResponseDataToJson(
  CreateContentReport201ResponseData instance,
) => <String, dynamic>{
  'id': instance.id,
  'status':
      _$CreateContentReport201ResponseDataStatusEnumEnumMap[instance.status]!,
};

const _$CreateContentReport201ResponseDataStatusEnumEnumMap = {
  CreateContentReport201ResponseDataStatusEnum.received: 'received',
  CreateContentReport201ResponseDataStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
