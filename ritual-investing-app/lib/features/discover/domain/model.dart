import 'package:flutter/foundation.dart';

enum DiscoverItemKind { asset, coven, grimoire, circleTemplate }

@immutable
class ResearchDemoDisclosure {
  ResearchDemoDisclosure({
    required this.isDemo,
    required this.observedAt,
    required this.sourceLabel,
    required List<String> limitations,
  }) : limitations = List.unmodifiable(limitations);

  final bool isDemo;
  final DateTime observedAt;
  final String sourceLabel;
  final List<String> limitations;
}

@immutable
class SeededCreatorView {
  const SeededCreatorView({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.bio,
    required this.isFictional,
    required this.demo,
  });

  final String id;
  final String slug;
  final String displayName;
  final String bio;
  final bool isFictional;
  final ResearchDemoDisclosure demo;
}

@immutable
class DiscoverItemView {
  const DiscoverItemView({
    required this.id,
    required this.revisionId,
    required this.slug,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.demo,
    this.symbol,
    this.appearanceReason,
    this.theme,
    this.creator,
  });

  final String id;
  final String revisionId;
  final String slug;
  final DiscoverItemKind kind;
  final String title;
  final String subtitle;
  final String? symbol;
  final String? appearanceReason;
  final String? theme;
  final SeededCreatorView? creator;
  final ResearchDemoDisclosure demo;

  bool get isSeededReadOnly => kind != DiscoverItemKind.asset;
}

@immutable
class DiscoverModel {
  DiscoverModel({
    required List<DiscoverItemView> items,
    required List<SeededCreatorView> creators,
    required this.nextCursor,
    required this.hasMore,
  }) : items = List.unmodifiable(items),
       creators = List.unmodifiable(creators);

  final List<DiscoverItemView> items;
  final List<SeededCreatorView> creators;
  final String? nextCursor;
  final bool hasMore;
}
