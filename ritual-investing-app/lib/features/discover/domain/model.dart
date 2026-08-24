import 'package:flutter/foundation.dart';

@immutable
class DiscoverCard {
  const DiscoverCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

@immutable
class DiscoverModel {
  DiscoverModel({
    required List<DiscoverCard> grimoires,
    required List<DiscoverCard> circles,
  }) : grimoires = List.unmodifiable(grimoires),
       circles = List.unmodifiable(circles);
  final List<DiscoverCard> grimoires;
  final List<DiscoverCard> circles;
}
