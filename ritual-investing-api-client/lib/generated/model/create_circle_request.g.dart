// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_circle_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateCircleRequestCWProxy {
  CreateCircleRequest description(String description);

  CreateCircleRequest title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCircleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCircleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCircleRequest call({String description, String title});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateCircleRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateCircleRequest.copyWith.fieldName(...)`
class _$CreateCircleRequestCWProxyImpl implements _$CreateCircleRequestCWProxy {
  const _$CreateCircleRequestCWProxyImpl(this._value);

  final CreateCircleRequest _value;

  @override
  CreateCircleRequest description(String description) =>
      this(description: description);

  @override
  CreateCircleRequest title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCircleRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCircleRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCircleRequest call({
    Object? description = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CreateCircleRequest(
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $CreateCircleRequestCopyWith on CreateCircleRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateCircleRequest.copyWith(...)` or like so:`instanceOfCreateCircleRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateCircleRequestCWProxy get copyWith =>
      _$CreateCircleRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCircleRequest _$CreateCircleRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateCircleRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['description', 'title']);
      final val = CreateCircleRequest(
        description: $checkedConvert('description', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$CreateCircleRequestToJson(
  CreateCircleRequest instance,
) => <String, dynamic>{
  'description': instance.description,
  'title': instance.title,
};
