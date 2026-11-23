// Файл: lib/models/app_models.dart

class UserModel {
  final int? id;
  final String fullName;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  const UserModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  UserModel copyWith({
    int? id,
    String? fullName,
    String? email,
    String? passwordHash,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'full_name': fullName,
      'email': email.trim().toLowerCase(),
      'password_hash': passwordHash,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      fullName: map['full_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      passwordHash: map['password_hash'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

enum GoalPeriod {
  daily,
  weekly,
  monthly;

  static GoalPeriod fromString(String value) {
    switch (value.toLowerCase()) {
      case 'daily':
        return GoalPeriod.daily;
      case 'weekly':
        return GoalPeriod.weekly;
      case 'monthly':
      default:
        return GoalPeriod.monthly;
    }
  }

  String toShortString() => name;

  String get displayName {
    switch (this) {
      case GoalPeriod.daily:
        return 'День';
      case GoalPeriod.weekly:
        return 'Тиждень';
      case GoalPeriod.monthly:
        return 'Місяць';
    }
  }

  String get genitiveLabel {
    switch (this) {
      case GoalPeriod.daily:
        return 'за день';
      case GoalPeriod.weekly:
        return 'за тиждень';
      case GoalPeriod.monthly:
        return 'за місяць';
    }
  }
}

class HabitLogModel {
  final int? id;
  final int habitId;
  final DateTime logDate;
  final bool isCompleted;
  final String? note;

  const HabitLogModel({
    this.id,
    required this.habitId,
    required this.logDate,
    required this.isCompleted,
    this.note,
  });

  HabitLogModel copyWith({
    int? id,
    int? habitId,
    DateTime? logDate,
    bool? isCompleted,
    String? note,
  }) {
    return HabitLogModel(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      logDate: logDate ?? this.logDate,
      isCompleted: isCompleted ?? this.isCompleted,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'habit_id': habitId,
      'log_date': logDate.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'note': (note != null && note!.trim().isNotEmpty) ? note!.trim() : null,
    };
  }

  factory HabitLogModel.fromMap(Map<String, dynamic> map) {
    return HabitLogModel(
      id: map['id'] as int?,
      habitId: map['habit_id'] as int? ?? 0,
      logDate: DateTime.tryParse(map['log_date'] as String? ?? '') ??
          DateTime.now(),
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      note: map['note'] as String?,
    );
  }
}

enum AttachmentType {
  image,
  pdf,
  other;

  static AttachmentType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'image':
        return AttachmentType.image;
      case 'pdf':
        return AttachmentType.pdf;
      default:
        return AttachmentType.other;
    }
  }

  String toShortString() => name;
}

class AttachmentModel {
  final int? id;
  final int? habitId;
  final String fileName;
  final String filePath;
  final AttachmentType fileType;

  const AttachmentModel({
    this.id,
    this.habitId,
    required this.fileName,
    required this.filePath,
    required this.fileType,
  });

  AttachmentModel copyWith({
    int? id,
    int? habitId,
    String? fileName,
    String? filePath,
    AttachmentType? fileType,
  }) {
    return AttachmentModel(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      'file_name': fileName,
      'file_path': filePath,
      'file_type': fileType.toShortString(),
    };
  }

  factory AttachmentModel.fromMap(Map<String, dynamic> map) {
    return AttachmentModel(
      id: map['id'] as int?,
      habitId: map['habit_id'] as int?,
      fileName: map['file_name'] as String? ?? 'file',
      filePath: map['file_path'] as String? ?? '',
      fileType: AttachmentType.fromString(map['file_type'] as String? ?? ''),
    );
  }
}

class HabitModel {
  final int? id;
  final int userId;
  final String title;
  final String? description;
  final int targetCount;
  final GoalPeriod goalPeriod;
  final DateTime createdAt;
  final List<HabitLogModel> logs;
  final List<AttachmentModel> attachments;

  const HabitModel({
    this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.targetCount,
    required this.goalPeriod,
    required this.createdAt,
    this.logs = const [],
    this.attachments = const [],
  });

  bool get hasAttachments => attachments.isNotEmpty;

  bool _isInCurrentPeriod(DateTime date, DateTime now) {
    switch (goalPeriod) {
      case GoalPeriod.daily:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case GoalPeriod.weekly:
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfWeek =
        startOfToday.subtract(Duration(days: now.weekday - 1));
        final startOfNextWeek = startOfWeek.add(const Duration(days: 7));
        return !date.isBefore(startOfWeek) && date.isBefore(startOfNextWeek);
      case GoalPeriod.monthly:
        return date.year == now.year && date.month == now.month;
    }
  }

  List<HabitLogModel> get currentPeriodLogs {
    final now = DateTime.now();
    return logs.where((log) => _isInCurrentPeriod(log.logDate, now)).toList();
  }

  int get completedInCurrentPeriod =>
      currentPeriodLogs.where((log) => log.isCompleted).length;

  int get missedInCurrentPeriod =>
      currentPeriodLogs.where((log) => !log.isCompleted).length;

  double get goalProgress {
    if (targetCount <= 0) return 0.0;
    return (completedInCurrentPeriod / targetCount).clamp(0.0, 1.0);
  }

  // Виправлено баг з 700% — тепер відсоток завжди від 0 до 100
  int get goalProgressPercent {
    return (goalProgress * 100).round();
  }

  bool get isGoalAchieved =>
      targetCount > 0 && completedInCurrentPeriod >= targetCount;

  int get totalCompletedCount => logs.where((log) => log.isCompleted).length;

  int get totalMissedCount => logs.where((log) => !log.isCompleted).length;

  HabitLogModel? get todayLatestLog {
    final now = DateTime.now();
    for (final log in logs) {
      if (log.logDate.year == now.year &&
          log.logDate.month == now.month &&
          log.logDate.day == now.day) {
        return log;
      }
    }
    return null;
  }

  String get goalSummaryText =>
      '$completedInCurrentPeriod / $targetCount ${goalPeriod.genitiveLabel}';

  bool matchesSearchQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final inTitle = title.toLowerCase().contains(q);
    final inDescription = (description ?? '').toLowerCase().contains(q);
    final inPeriod = goalPeriod.genitiveLabel.toLowerCase().contains(q);
    final inNotes = logs.any(
          (log) => (log.note ?? '').toLowerCase().contains(q),
    );

    return inTitle || inDescription || inPeriod || inNotes;
  }

  HabitModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? description,
    int? targetCount,
    GoalPeriod? goalPeriod,
    DateTime? createdAt,
    List<HabitLogModel>? logs,
    List<AttachmentModel>? attachments,
  }) {
    return HabitModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetCount: targetCount ?? this.targetCount,
      goalPeriod: goalPeriod ?? this.goalPeriod,
      createdAt: createdAt ?? this.createdAt,
      logs: logs ?? this.logs,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title.trim(),
      'description': (description != null && description!.trim().isNotEmpty)
          ? description!.trim()
          : null,
      'target_count': targetCount,
      'goal_period': goalPeriod.toShortString(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HabitModel.fromMap(
      Map<String, dynamic> map, {
        List<HabitLogModel> logs = const [],
        List<AttachmentModel> attachments = const [],
      }) {
    return HabitModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 0,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      targetCount: map['target_count'] as int? ?? 1,
      goalPeriod: GoalPeriod.fromString(map['goal_period'] as String? ?? ''),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      logs: logs,
      attachments: attachments,
    );
  }
}