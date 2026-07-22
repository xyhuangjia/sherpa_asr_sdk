// example/lib/widgets/history_list_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recognition_record.dart';
import '../theme/app_theme.dart';

/// 历史记录列表组件
class HistoryListWidget extends StatefulWidget {
  final List<RecognitionRecord> records;
  final void Function(RecognitionRecord)? onPlay;
  final void Function(RecognitionRecord)? onDelete;
  final void Function(RecognitionRecord, bool)? onFavoriteToggle;

  const HistoryListWidget({
    super.key,
    required this.records,
    this.onPlay,
    this.onDelete,
    this.onFavoriteToggle,
  });

  @override
  State<HistoryListWidget> createState() => _HistoryListWidgetState();
}

class _HistoryListWidgetState extends State<HistoryListWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 56,
              color: AppColors.onBgDim.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              '暂无历史记录',
              style: TextStyle(fontSize: 14, color: AppColors.onBgDim),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.records.length,
      itemBuilder: (context, index) {
        return _buildRecordItem(widget.records[index]);
      },
    );
  }

  Widget _buildRecordItem(RecognitionRecord record) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧青色强调条
              Container(
                width: 3,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(record),
                      const SizedBox(height: 8),
                      Text(
                        record.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.onBg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(RecognitionRecord record) {
    return Row(
      children: [
        const Icon(Icons.schedule_rounded, size: 12, color: AppColors.onBgDim),
        const SizedBox(width: 4),
        Text(
          record.formattedTime(),
          style: mono(size: 10, color: AppColors.onBgDim),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.timer_outlined, size: 12, color: AppColors.onBgDim),
        const SizedBox(width: 4),
        Text(
          record.formattedDuration(),
          style: mono(size: 10, color: AppColors.onBgDim),
        ),
        const Spacer(),
        _iconBtn(
          Icons.play_arrow_rounded,
          color: AppColors.primary,
          onTap: () => widget.onPlay?.call(record),
        ),
        _favBtn(record),
        _iconBtn(
          Icons.copy_outlined,
          onTap: () {
            Clipboard.setData(ClipboardData(text: record.text));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
          },
        ),
        _iconBtn(
          Icons.delete_outline_rounded,
          color: AppColors.error,
          onTap: () => widget.onDelete?.call(record),
        ),
      ],
    );
  }

  Widget _favBtn(RecognitionRecord record) {
    final fav = record.isFavorite;
    return InkWell(
      onTap: () => widget.onFavoriteToggle?.call(record, !record.isFavorite),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 18,
          color: fav ? AppColors.primary : AppColors.onBgDim,
          shadows: fav
              ? const [Shadow(color: AppColors.primary, blurRadius: 8)]
              : null,
        ),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon, {
    VoidCallback? onTap,
    Color color = AppColors.onBgDim,
    double size = 18,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
