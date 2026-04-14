// example/lib/widgets/search_filter_widget.dart

import 'package:flutter/material.dart';
import '../models/search_filter.dart';

/// 搜索过滤组件
class SearchFilterWidget extends StatefulWidget {
  final SearchFilter initialFilter;
  final void Function(SearchFilter) onFilterChanged;

  const SearchFilterWidget({
    super.key,
    this.initialFilter = const SearchFilter.empty(),
    required this.onFilterChanged,
  });

  @override
  State<SearchFilterWidget> createState() => _SearchFilterWidgetState();
}

class _SearchFilterWidgetState extends State<SearchFilterWidget> {
  late TextEditingController _keywordController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFavoriteFilter = false;

  @override
  void initState() {
    super.initState();
    _keywordController =
        TextEditingController(text: widget.initialFilter.keyword ?? '');
    _startDate = widget.initialFilter.startDate;
    _endDate = widget.initialFilter.endDate;
    _isFavoriteFilter = widget.initialFilter.isFavorite ?? false;
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // 搜索输入框
          TextField(
            decoration: InputDecoration(
              hintText: '搜索文本内容...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _keywordController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _keywordController.clear();
                        _applyFilter();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              _applyFilter();
            },
            controller: _keywordController,
          ),

          const SizedBox(height: 16),

          // 过滤选项
          Row(
            children: [
              // 日期范围
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(
                    _startDate != null
                        ? '${_formatDate(_startDate!)} - ${_endDate != null ? _formatDate(_endDate!) : '今'}'
                        : '日期范围',
                  ),
                  onPressed: _selectDateRange,
                ),
              ),
              const SizedBox(width: 8),
              // 收藏筛选
              FilterChip(
                label: const Text('收藏'),
                selected: _isFavoriteFilter,
                onSelected: (selected) {
                  setState(() => _isFavoriteFilter = selected);
                  _applyFilter();
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 清除所有过滤
          if (SearchFilter(
            keyword: _keywordController.text,
            startDate: _startDate,
            endDate: _endDate,
            isFavorite: _isFavoriteFilter,
          ).hasFilters())
            TextButton.icon(
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('清除所有'),
              onPressed: _clearAllFilters,
            ),
        ],
      ),
    );
  }

  void _applyFilter() {
    widget.onFilterChanged(SearchFilter(
      keyword:
          _keywordController.text.isEmpty ? null : _keywordController.text,
      startDate: _startDate,
      endDate: _endDate,
      isFavorite: _isFavoriteFilter ? true : null,
    ));
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      _applyFilter();
    }
  }

  void _clearAllFilters() {
    setState(() {
      _keywordController.clear();
      _startDate = null;
      _endDate = null;
      _isFavoriteFilter = false;
    });
    _applyFilter();
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}