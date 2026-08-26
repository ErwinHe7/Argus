import '../domain/model.dart';

abstract interface class SearchService {
  Future<SearchPage> search(SearchRequest request);
}

class SearchRepository {
  const SearchRepository({required this.service});

  final SearchService service;

  Future<SearchPage> search(SearchRequest request) => service.search(request);
}
