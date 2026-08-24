//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/portfolio_activity.dart';
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_portfolio_activity200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListPortfolioActivity200Response {
  /// Returns a new [ListPortfolioActivity200Response] instance.
  ListPortfolioActivity200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<PortfolioActivity> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListPortfolioActivity200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory ListPortfolioActivity200Response.fromJson(
    Map<String, dynamic> json,
  ) => _$ListPortfolioActivity200ResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListPortfolioActivity200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
