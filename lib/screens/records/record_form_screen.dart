// Файл: lib/screens/records/record_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:med_history_app/models/app_models.dart';
import 'package:med_history_app/state/app_controller.dart';

class RecordFormScreen extends StatefulWidget {
  final int? existingRecordId;

  const RecordFormScreen({
    super.key,
    this.existingRecordId,
  });

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetCountController = TextEditingController(text: '12');

  GoalPeriod _selectedPeriod = GoalPeriod.monthly;
  final List<AttachmentModel> _attachments = [];

  bool _isLoaded = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existingRecordId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoaded) {
      if (widget.existingRecordId != null) {
        final controller = AppStateScope.of(context, listen: false);
        final habit = controller.getHabitById(widget.existingRecordId!);
        if (habit != null) {
          _titleController.text = habit.title;
          _descriptionController.text = habit.description ?? '';
          _targetCountController.text = habit.targetCount.toString();
          _selectedPeriod = habit.goalPeriod;
          _attachments.addAll(habit.attachments);
        }
      }
      _isLoaded = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetCountController.dispose();
    super.dispose();
  }

  int get _parsedTargetCount {
    final val = int.tryParse(_targetCountController.text.trim()) ?? 1;
    return val < 1 ? 1 : val;
  }

  void _stepTargetCount(int delta) {
    final next = (_parsedTargetCount + delta).clamp(1, 365);
    setState(() {
      _targetCountController.text = next.toString();
    });
  }

  void _applyPreset({
    required String title,
    required String description,
    required int target,
    required GoalPeriod period,
  }) {
    setState(() {
      _titleController.text = title;
      _descriptionController.text = description;
      _targetCountController.text = target.toString();
      _selectedPeriod = period;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final controller = AppStateScope.of(context, listen: false);
    try {
      final attachment = await controller.pickImageAttachment(source: source);
      if (attachment != null && mounted) {
        setState(() => _attachments.add(attachment));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося вибрати фото: $e')),
      );
    }
  }

  Future<void> _pickDocument() async {
    final controller = AppStateScope.of(context, listen: false);
    try {
      final attachment = await controller.pickDocumentAttachment();
      if (attachment != null && mounted) {
        setState(() => _attachments.add(attachment));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося прикріпити файл: $e')),
      );
    }
  }

  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final controller = AppStateScope.of(context, listen: false);

    try {
      await controller.saveHabit(
        existingId: widget.existingRecordId,
        title: _titleController.text,
        description: _descriptionController.text,
        targetCount: _parsedTargetCount,
        goalPeriod: _selectedPeriod,
        attachments: _attachments,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Звичку та мету успішно оновлено'
                : 'Нову звичку додано до трекера',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetVal = _parsedTargetCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редагування звички' : 'Нова звичка та мета'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Швидкі шаблони
            if (!_isEditing) ...[
              Text(
                'Швидкі приклади:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.fitness_center_rounded, size: 16),
                    label: const Text('12 тренувань / місяць'),
                    onPressed: () => _applyPreset(
                      title: 'Відвідати тренування',
                      description: 'Регулярні заняття спортом.',
                      target: 12,
                      period: GoalPeriod.monthly,
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.coffee_rounded, size: 16),
                    label: const Text('Випити каву / день'),
                    onPressed: () => _applyPreset(
                      title: 'Випити каву',
                      description: 'Контроль щоденної звички пити каву.',
                      target: 1,
                      period: GoalPeriod.daily,
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('Читання 5 разів / тиждень'),
                    onPressed: () => _applyPreset(
                      title: 'Читання книги (30 хв)',
                      description: 'Щоденна порція читання перед сном.',
                      target: 5,
                      period: GoalPeriod.weekly,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // 1. Опис звички
            _SectionHeader(
              icon: Icons.edit_note_rounded,
              title: '1. Опис звички або дії',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Назва звички / дії *',
                hintText: 'Напр.: Відвідати тренування, Випити каву',
                prefixIcon: Icon(Icons.task_alt_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Введіть назву звички (мінімум 2 символи)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Опис або нотатка (необов’язково)',
                hintText: 'Додаткові деталі або мотивація...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // 2. Мета
            _SectionHeader(
              icon: Icons.flag_outlined,
              title: '2. Виставлення мети',
            ),
            const SizedBox(height: 12),
            Text(
              'Період контролю мети:',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<GoalPeriod>(
              segments: const [
                ButtonSegment(
                  value: GoalPeriod.daily,
                  label: Text('День'),
                  icon: Icon(Icons.today_rounded, size: 18),
                ),
                ButtonSegment(
                  value: GoalPeriod.weekly,
                  label: Text('Тиждень'),
                  icon: Icon(Icons.date_range_rounded, size: 18),
                ),
                ButtonSegment(
                  value: GoalPeriod.monthly,
                  label: Text('Місяць'),
                  icon: Icon(Icons.calendar_month_rounded, size: 18),
                ),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (newSelection) {
                setState(() => _selectedPeriod = newSelection.first);
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton.filledTonal(
                  onPressed: () => _stepTargetCount(-1),
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _targetCountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Цільова кількість виконань *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed < 1) return 'Від 1';
                      if (parsed > 365) return 'Макс. 365';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _stepTargetCount(1),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.track_changes_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Поставлена мета: виконати дію $targetVal раз(ів) ${_selectedPeriod.genitiveLabel}.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Файли
            const _SectionHeader(
              icon: Icons.attach_file_rounded,
              title: '3. Прикріплені файли (фото, PDF)',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Фото'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Камера'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDocument,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF / Файл'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_attachments.isNotEmpty)
              ..._attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                final isPdf = file.fileType == AttachmentType.pdf;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      color: isPdf ? Colors.red.shade700 : colorScheme.primary,
                    ),
                    title: Text(
                      file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      isPdf ? 'PDF-документ' : 'Зображення',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.close_rounded, color: colorScheme.error),
                      onPressed: () => setState(() => _attachments.removeAt(index)),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 28),

            // Кнопка збереження
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveHabit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isEditing ? 'Зберегти зміни' : 'Створити звичку',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}