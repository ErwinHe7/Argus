//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/portfolio_view.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_portfolio201_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreatePortfolio201Response {
  /// Returns a new [CreatePortfolio201Response] instance.
  CreatePortfolio201Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final PortfolioView data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatePortfolio201Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CreatePortfolio201Response.fromJson(Map<String, dynamic> json) =>
      _$CreatePortfolio201ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreatePortfolio201ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
