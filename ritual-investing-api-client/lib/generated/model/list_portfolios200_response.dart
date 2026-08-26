//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/portfolio_view.dart';
import 'package:ritual_investing_api_client/generated/model/collection_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_portfolios200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListPortfolios200Response {
  /// Returns a new [ListPortfolios200Response] instance.
  ListPortfolios200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<PortfolioView> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final CollectionMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListPortfolios200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory ListPortfolios200Response.fromJson(Map<String, dynamic> json) =>
      _$ListPortfolios200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListPortfolios200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
