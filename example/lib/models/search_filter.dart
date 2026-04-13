// example/lib/models/search_filter.dart

/// 搜索过滤器模型
class SearchFilter {
  final String? keyword;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? minDuration;
  final int? maxDuration;
  final bool? isFavorite;

  const SearchFilter({
    this.keyword,
    this.startDate,
    this.endDate,
    this.minDuration,
    this.maxDuration,
    this.isFavorite,
  });

  /// 是否有任何过滤条件
  bool hasFilters() {
    return keyword != null ||
        startDate != null ||
        endDate != null ||
        minDuration != null ||
        maxDuration != null ||
        isFavorite != null;
  }

  /// 清空所有过滤条件
  const SearchFilter.empty()
      : keyword = null,
        startDate = null,
        endDate = null,
        minDuration = null,
        maxDuration = null,
        isFavorite = null;

  /// 复制并修改
  SearchFilter copyWith({
    String? keyword,
    DateTime? startDate,
    DateTime? endDate,
    int? minDuration,
    int? maxDuration,
    bool? isFavorite,
  }) {
    return SearchFilter(
      keyword: keyword ?? this.keyword,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}