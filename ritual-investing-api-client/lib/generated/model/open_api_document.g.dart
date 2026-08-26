// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_api_document.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OpenApiDocumentCWProxy {
  OpenApiDocument openapi(OpenApiDocumentOpenapiEnum openapi);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OpenApiDocument(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OpenApiDocument(...).copyWith(id: 12, name: "My name")
  /// ````
  OpenApiDocument call({OpenApiDocumentOpenapiEnum openapi});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOpenApiDocument.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOpenApiDocument.copyWith.fieldName(...)`
class _$OpenApiDocumentCWProxyImpl implements _$OpenApiDocumentCWProxy {
  const _$OpenApiDocumentCWProxyImpl(this._value);

  final OpenApiDocument _value;

  @override
  OpenApiDocument openapi(OpenApiDocumentOpenapiEnum openapi) =>
      this(openapi: openapi);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OpenApiDocument(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OpenApiDocument(...).copyWith(id: 12, name: "My name")
  /// ````
  OpenApiDocument call({Object? openapi = const $CopyWithPlaceholder()}) {
    return OpenApiDocument(
      openapi: openapi == const $CopyWithPlaceholder()
          ? _value.openapi
          // ignore: cast_nullable_to_non_nullable
          : openapi as OpenApiDocumentOpenapiEnum,
    );
  }
}

extension $OpenApiDocumentCopyWith on OpenApiDocument {
  /// Returns a callable class that can be used as follows: `instanceOfOpenApiDocument.copyWith(...)` or like so:`instanceOfOpenApiDocument.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OpenApiDocumentCWProxy get copyWith => _$OpenApiDocumentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenApiDocument _$OpenApiDocumentFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OpenApiDocument', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['openapi']);
      final val = OpenApiDocument(
        openapi: $checkedConvert(
          'openapi',
          (v) => $enumDecode(
            _$OpenApiDocumentOpenapiEnumEnumMap,
            v,
            unknownValue: OpenApiDocumentOpenapiEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$OpenApiDocumentToJson(OpenApiDocument instance) =>
    <String, dynamic>{
      'openapi': _$OpenApiDocumentOpenapiEnumEnumMap[instance.openapi]!,
    };

const _$OpenApiDocumentOpenapiEnumEnumMap = {
  OpenApiDocumentOpenapiEnum.n3period0Period3: '3.0.3',
  OpenApiDocumentOpenapiEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
