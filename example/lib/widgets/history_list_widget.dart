// example/lib/widgets/history_list_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recognition_record.dart';

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
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无历史记录',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
        final record = widget.records[index];
        return _buildRecordItem(record);
      },
    );
  }

  Widget _buildRecordItem(RecognitionRecord record) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：时间 + 时长 + 操作
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                record.formattedTime(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.timer_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                record.formattedDuration(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              // 收藏按钮
              IconButton(
                icon: Icon(
                  record.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: record.isFavorite
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                onPressed: () {
                  widget.onFavoriteToggle?.call(record, !record.isFavorite);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // 播放按钮
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                onPressed: () {
                  widget.onPlay?.call(record);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // 复制按钮
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: record.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // 删除按钮
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () {
                  widget.onDelete?.call(record);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 文本内容
          Text(
            record.text,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}