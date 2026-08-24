// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_circle_template_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CopyCircleTemplateRequestCWProxy {
  CopyCircleTemplateRequest title(String? title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CopyCircleTemplateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CopyCircleTemplateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CopyCircleTemplateRequest call({String? title});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCopyCircleTemplateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCopyCircleTemplateRequest.copyWith.fieldName(...)`
class _$CopyCircleTemplateRequestCWProxyImpl
    implements _$CopyCircleTemplateRequestCWProxy {
  const _$CopyCircleTemplateRequestCWProxyImpl(this._value);

  final CopyCircleTemplateRequest _value;

  @override
  CopyCircleTemplateRequest title(String? title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CopyCircleTemplateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CopyCircleTemplateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CopyCircleTemplateRequest call({
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CopyCircleTemplateRequest(
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String?,
    );
  }
}

extension $CopyCircleTemplateRequestCopyWith on CopyCircleTemplateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCopyCircleTemplateRequest.copyWith(...)` or like so:`instanceOfCopyCircleTemplateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CopyCircleTemplateRequestCWProxy get copyWith =>
      _$CopyCircleTemplateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CopyCircleTemplateRequest _$CopyCircleTemplateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CopyCircleTemplateRequest', json, ($checkedConvert) {
  final val = CopyCircleTemplateRequest(
    title: $checkedConvert('title', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$CopyCircleTemplateRequestToJson(
  CopyCircleTemplateRequest instance,
) => <String, dynamic>{'title': ?instance.title};
