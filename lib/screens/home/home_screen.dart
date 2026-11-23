// Файл: lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';

import 'package:med_history_app/models/app_models.dart';
import 'package:med_history_app/state/app_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppStateScope.of(context);
    if (_searchController.text != controller.searchQuery) {
      _searchController.text = controller.searchQuery;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateHabit(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.habitForm, arguments: null);
  }

  void _openHabitDetails(BuildContext context, int habitId) {
    Navigator.of(context).pushNamed(AppRoutes.habitDetail, arguments: habitId);
  }

  Future<void> _quickLogAction(
      BuildContext context,
      AppController controller,
      HabitModel habit,
      bool isCompleted,
      ) async {
    await controller.addHabitLog(
      habitId: habit.id!,
      isCompleted: isCompleted,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCompleted
              ? '«${habit.title}» — відмічено як виконано'
              : '«${habit.title}» — відмічено як не виконано',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppStateScope.of(context);
    final user = controller.currentUser;
    final allHabits = controller.allUserHabits;
    final filteredHabits = controller.filteredHabits;
    final colorScheme = Theme.of(context).colorScheme;

    final int achievedCount = allHabits.where((h) => h.isGoalAchieved).length;
    final int inProgressCount = allHabits.length - achievedCount;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Мої звички та цілі',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            if (user != null)
              Text(
                user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        actions: [
          // НОВА КНОПКА ЗМІНИ ТЕМИ
          IconButton(
            tooltip: 'Змінити тему (Авто/Темна/Світла)',
            icon: Icon(controller.currentThemeIcon),
            onPressed: controller.cycleTheme,
          ),
          IconButton(
            tooltip: 'Профіль та керування акаунтом',
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.person_rounded, size: 20, color: colorScheme.primary),
            ),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.profile);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: controller.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Пошук звички, мети або нотатки...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: controller.searchQuery.isNotEmpty
                        ? IconButton(
                      tooltip: 'Очистити пошук',
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        controller.setSearchQuery('');
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('Усі (${allHabits.length})'),
                        selected: controller.activeFilter == HabitFilter.all,
                        onSelected: (_) => controller.setFilter(HabitFilter.all),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.timelapse_rounded, size: 16),
                        label: Text('У процесі ($inProgressCount)'),
                        selected: controller.activeFilter == HabitFilter.inProgress,
                        onSelected: (_) => controller.setFilter(HabitFilter.inProgress),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                        label: Text('Мету досягнуто ($achievedCount)'),
                        selected: controller.activeFilter == HabitFilter.achieved,
                        onSelected: (_) => controller.setFilter(HabitFilter.achieved),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredHabits.isEmpty
                ? _buildEmptyState(
              context,
              hasAnyHabits: allHabits.isNotEmpty,
              onResetFilters: () {
                _searchController.clear();
                controller.resetSearchAndFilters();
              },
            )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
              itemCount: filteredHabits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final habit = filteredHabits[index];
                return _HabitCard(
                  habit: habit,
                  onTap: () => _openHabitDetails(context, habit.id!),
                  onMarkDone: () => _quickLogAction(context, controller, habit, true),
                  onMarkMissed: () => _quickLogAction(context, controller, habit, false),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateHabit(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Нова звичка'),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, {
        required bool hasAnyHabits,
        required VoidCallback onResetFilters,
      }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAnyHabits ? Icons.manage_search_rounded : Icons.track_changes_rounded,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              hasAnyHabits ? 'За вашим запитом нічого не знайдено' : 'Список звичок поки порожній',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasAnyHabits
                  ? 'Спробуйте змінити текст пошуку або скинути фільтри.'
                  : 'Натисніть «Нова звичка», щоб додати дію (напр., «Випити каву» або «12 тренувань за місяць») і почати контроль.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (hasAnyHabits) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onResetFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Скинути пошук і фільтри'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final HabitModel habit;
  final VoidCallback onTap;
  final VoidCallback onMarkDone;
  final VoidCallback onMarkMissed;

  const _HabitCard({
    required this.habit,
    required this.onTap,
    required this.onMarkDone,
    required this.onMarkMissed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final todayLog = habit.todayLatestLog;
    final bool achieved = habit.isGoalAchieved;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: achieved ? Colors.green.shade600 : colorScheme.outlineVariant,
          width: achieved ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      habit.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: achieved ? Colors.green.withValues(alpha: 0.15) : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          achieved ? Icons.emoji_events_rounded : Icons.calendar_today_rounded,
                          size: 13,
                          color: achieved ? Colors.green.shade700 : colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          achieved ? 'Виконано!' : habit.goalPeriod.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: achieved ? Colors.green.shade800 : colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (habit.description != null && habit.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  habit.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Мета: ${habit.goalSummaryText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${habit.goalProgressPercent}%',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: achieved ? Colors.green.shade700 : colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: habit.goalProgress,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    achieved ? Colors.green.shade600 : colorScheme.primary,
                  ),
                ),
              ),
              if (todayLog != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      todayLog.isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 16,
                      color: todayLog.isCompleted ? Colors.green.shade700 : colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        todayLog.isCompleted ? 'Сьогодні: виконано' : 'Сьогодні: не виконано',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: todayLog.isCompleted ? Colors.green.shade700 : colorScheme.error,
                        ),
                      ),
                    ),
                    Text(
                      'Історія: ${habit.logs.length}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onMarkDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.withValues(alpha: 0.14),
                        foregroundColor: Colors.green.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Виконав', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMarkMissed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.45)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Не виконав', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}