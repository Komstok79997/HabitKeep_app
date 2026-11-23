// Файл: lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:med_history_app/state/app_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _handleLogout(
      BuildContext context,
      AppController controller,
      ) async {
    await controller.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
          (route) => false,
    );
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context,
      AppController controller,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          size: 40,
          color: Theme.of(ctx).colorScheme.error,
        ),
        title: const Text('Видалити обліковий запис?'),
        content: const Text(
          'Увага! Ваш профіль, усі створені звички, виставлені цілі та повна історія їх виконання будуть безповоротно видалені з пристрою.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Так, видалити назавжди'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await controller.deleteCurrentAccount();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
            (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Обліковий запис та всі дані звичок успішно видалено.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppStateScope.of(context);
    final user = controller.currentUser;
    final habits = controller.allUserHabits;
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormatter = DateFormat('dd.MM.yyyy');

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Профіль')),
        body: const Center(child: Text('Користувач не авторизований')),
      );
    }

    final int achievedGoalsCount =
        habits.where((h) => h.isGoalAchieved).length;
    final int totalCompletedActions = habits.fold(
      0,
          (sum, h) => sum + h.totalCompletedCount,
    );
    final int totalMissedActions = habits.fold(
      0,
          (sum, h) => sum + h.totalMissedCount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профіль та акаунт'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Картка профілю користувача
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Дата реєстрації: ${dateFormatter.format(user.createdAt)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Загальна статистика звичок',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Сітка статистики (2x2)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.75,
            children: [
              _StatTile(
                icon: Icons.track_changes_rounded,
                label: 'Активних звичок',
                value: '${habits.length}',
              ),
              _StatTile(
                icon: Icons.emoji_events_outlined,
                label: 'Досягнуто цілей',
                value: '$achievedGoalsCount',
              ),
              _StatTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'Виконано дій',
                value: '$totalCompletedActions',
              ),
              _StatTile(
                icon: Icons.cancel_outlined,
                label: 'Пропущено дій',
                value: '$totalMissedActions',
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Кнопка виходу з сесії
          OutlinedButton.icon(
            onPressed: () => _handleLogout(context, controller),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Вийти з облікового запису'),
          ),

          const SizedBox(height: 28),

          // Небезпечна зона: обов'язковий функціонал видалення облікового запису
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.no_accounts_rounded,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Видалення облікового запису',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'При видаленні облікового запису ваш профіль, усі створені звички, поставлені цілі та історія виконань видаляються з бази даних назавжди.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _confirmDeleteAccount(context, controller),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Видалити обліковий запис'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}