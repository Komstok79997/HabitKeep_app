// Файл: lib/screens/records/record_detail_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import 'package:med_history_app/models/app_models.dart';
import 'package:med_history_app/state/app_controller.dart';

class RecordDetailScreen extends StatelessWidget {
  final int recordId;

  const RecordDetailScreen({
    super.key,
    required this.recordId,
  });

  Future<void> _openAttachment(BuildContext context, AttachmentModel attachment) async {
    final file = File(attachment.filePath);
    if (!await file.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл не знайдено на пристрої (можливо, його переміщено).')),
      );
      return;
    }

    final result = await OpenFilex.open(attachment.filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося відкрити файл: ${result.message}')),
      );
    }
  }

  Future<void> _showAddLogDialog(
      BuildContext context,
      AppController controller,
      HabitModel habit, {
        required bool initialCompleted,
      }) async {
    // Прибрано кутові дужки , щоб компілятор не плутав їх з операторами математики
    final dynamic result = await showDialog(
      context: context,
      builder: (ctx) => _AddLogDialog(initialCompleted: initialCompleted),
    );

    // Перевіряємо тип безпечно після закриття діалогу
    if (result != null && result is Map<String, dynamic> && context.mounted) {
      await controller.addHabitLog(
        habitId: habit.id!,
        isCompleted: result['isCompleted'] as bool,
        logDate: result['date'] as DateTime,
        note: result['note'] as String?,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (result['isCompleted'] as bool)
                ? 'Виконання додано в історію'
                : 'Пропуск зафіксовано в історії',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteHabit(
      BuildContext context,
      AppController controller,
      HabitModel habit,
      ) async {
    final dynamic confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити звичку?'),
        content: Text('Звичку «${habit.title}» та всю її історію (${habit.logs.length} записів) буде безповоротно видалено.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await controller.deleteHabit(recordId);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Звичку видалено'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppStateScope.of(context);
    final habit = controller.getHabitById(recordId);
    final colorScheme = Theme.of(context).colorScheme;
    final dateTimeFormatter = DateFormat('dd.MM.yyyy о HH:mm');

    if (habit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Контроль звички')),
        body: const Center(child: Text('Звичку не знайдено або її було видалено.')),
      );
    }

    final bool achieved = habit.isGoalAchieved;
    final int remaining = (habit.targetCount - habit.completedInCurrentPeriod).clamp(0, 9999);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Контроль звички'),
        actions: [
          IconButton(
            tooltip: 'Редагувати звичку та мету',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.habitForm, arguments: habit.id);
            },
          ),
          IconButton(
            tooltip: 'Видалити звичку',
            icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
            onPressed: () => _confirmDeleteHabit(context, controller, habit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: achieved ? Colors.green.shade600 : colorScheme.outlineVariant,
                width: achieved ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          habit.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        avatar: Icon(
                          achieved ? Icons.emoji_events_rounded : Icons.flag_rounded,
                          size: 16,
                          color: achieved ? Colors.green.shade700 : colorScheme.primary,
                        ),
                        label: Text(achieved ? 'Мету досягнуто' : habit.goalPeriod.displayName),
                        backgroundColor: achieved
                            ? Colors.green.withValues(alpha: 0.14)
                            : colorScheme.primaryContainer.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  if (habit.description != null && habit.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      habit.description!,
                      style: TextStyle(fontSize: 14.5, color: colorScheme.onSurfaceVariant, height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Прогрес: ${habit.goalSummaryText}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${habit.goalProgressPercent}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: achieved ? Colors.green.shade700 : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: habit.goalProgress,
                      minHeight: 12,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        achieved ? Colors.green.shade600 : colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    achieved
                        ? 'Вітаємо! Ви виконали поставлену мету ${habit.goalPeriod.genitiveLabel}.'
                        : 'До виконання мети залишилось: $remaining раз(ів).',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: achieved ? Colors.green.shade700 : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _MiniCounterCard(
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.green.shade700,
                  label: 'Виконано всього',
                  value: '${habit.totalCompletedCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniCounterCard(
                  icon: Icons.cancel_outlined,
                  color: colorScheme.error,
                  label: 'Не виконано',
                  value: '${habit.totalMissedCount}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            'Зафіксувати дію',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showAddLogDialog(context, controller, habit, initialCompleted: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Виконав'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddLogDialog(context, controller, habit, initialCompleted: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Не виконав'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (habit.attachments.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.attach_file_rounded, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Прикріплені файли (${habit.attachments.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...habit.attachments.map((att) {
              final isPdf = att.fileType == AttachmentType.pdf;
              final isImage = att.fileType == AttachmentType.image;
              final fileObj = File(att.filePath);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openAttachment(context, att),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isImage && fileObj.existsSync())
                        SizedBox(
                          height: 160,
                          child: Image.file(
                            fileObj,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ListTile(
                        leading: Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : Icons.image_outlined,
                          color: isPdf ? Colors.red.shade700 : colorScheme.primary,
                        ),
                        title: Text(
                          att.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          isPdf ? 'Натисніть, щоб відкрити PDF' : 'Натисніть, щоб переглянути зображення',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              Icon(Icons.history_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Історія дії (${habit.logs.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (habit.logs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Історія цієї звички поки порожня. Натисніть «Виконав» або «Не виконав» вище, щоб додати перший запис.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          else
            ...habit.logs.map((log) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: log.isCompleted
                        ? Colors.green.withValues(alpha: 0.14)
                        : colorScheme.errorContainer.withValues(alpha: 0.55),
                    child: Icon(
                      log.isCompleted ? Icons.check_rounded : Icons.close_rounded,
                      color: log.isCompleted ? Colors.green.shade700 : colorScheme.error,
                    ),
                  ),
                  title: Text(
                    log.isCompleted ? 'Виконано' : 'Не виконано',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: log.isCompleted ? Colors.green.shade800 : colorScheme.error,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateTimeFormatter.format(log.logDate),
                        style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                      ),
                      if (log.note != null && log.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(log.note!, style: const TextStyle(fontSize: 13.5)),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'Видалити відмітку',
                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                    onPressed: () async {
                      if (log.id != null) {
                        await controller.deleteHabitLog(log.id!);
                      }
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MiniCounterCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MiniCounterCard({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddLogDialog extends StatefulWidget {
  final bool initialCompleted;

  const _AddLogDialog({required this.initialCompleted});

  @override
  State<_AddLogDialog> createState() => _AddLogDialogState();
}

class _AddLogDialogState extends State<_AddLogDialog> {
  late final TextEditingController _noteController;
  late bool _isCompleted;
  DateTime _selectedDate = DateTime.now();
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.initialCompleted;
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isCompleted ? 'Відмітити як виконано' : 'Відмітити як не виконано'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Виконав'),
                  icon: Icon(Icons.check_rounded, size: 18),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Не виконав'),
                  icon: Icon(Icons.close_rounded, size: 18),
                ),
              ],
              selected: {_isCompleted},
              onSelectionChanged: (val) {
                setState(() => _isCompleted = val.first);
              },
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  final now = DateTime.now();
                  setState(() {
                    _selectedDate = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute);
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата дії',
                  prefixIcon: Icon(Icons.event_rounded),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dateFormat.format(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Коментар (необов’язково)',
                hintText: 'Напр.: 50 хв кардіо або причина пропуску',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              'isCompleted': _isCompleted,
              'date': _selectedDate,
              'note': _noteController.text,
            });
          },
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}