// Файл: lib/database/db_helper.dart

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:med_history_app/models/app_models.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  // Щоб база гарантовано перестворилася з новою таблицею attachments — я підняв версію
  static const String _dbName = 'habitkeep_v2.db';
  static const int _dbVersion = 1;

  static const String tableUsers = 'users';
  static const String tableHabits = 'habits';
  static const String tableHabitLogs = 'habit_logs';
  static const String tableAttachments = 'attachments';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableUsers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableHabits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        target_count INTEGER NOT NULL DEFAULT 1,
        goal_period TEXT NOT NULL DEFAULT 'monthly',
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableHabitLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        log_date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 1,
        note TEXT,
        FOREIGN KEY (habit_id) REFERENCES $tableHabits (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableAttachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_type TEXT NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES $tableHabits (id) ON DELETE CASCADE
      )
    ''');

    await _seedInitialDemoData(db);
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableUsers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final normalized = email.trim().toLowerCase();
    final rows = await db.query(
      tableUsers,
      where: 'LOWER(email) = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<UserModel> insertUser(UserModel user) async {
    final db = await database;
    final id = await db.insert(
      tableUsers,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return user.copyWith(id: id);
  }

  Future<List<String>> getUserAttachmentPaths(int userId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.file_path
      FROM $tableAttachments a
      INNER JOIN $tableHabits h ON a.habit_id = h.id
      WHERE h.user_id = ?
    ''', [userId]);

    return rows
        .map((row) => row['file_path'] as String? ?? '')
        .where((path) => path.isNotEmpty)
        .toList();
  }

  Future<void> deleteUserById(int userId) async {
    final db = await database;
    await db.delete(
      tableUsers,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<HabitModel>> getHabitsForUser(int userId) async {
    final db = await database;

    final habitRows = await db.query(
      tableHabits,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC, id DESC',
    );

    if (habitRows.isEmpty) return [];

    final List<HabitModel> result = [];

    for (final row in habitRows) {
      final int habitId = row['id'] as int;

      final logRows = await db.query(
        tableHabitLogs,
        where: 'habit_id = ?',
        whereArgs: [habitId],
        orderBy: 'log_date DESC, id DESC',
      );

      final attRows = await db.query(
        tableAttachments,
        where: 'habit_id = ?',
        whereArgs: [habitId],
        orderBy: 'id ASC',
      );

      final logs = logRows.map((m) => HabitLogModel.fromMap(m)).toList();
      final attachments = attRows.map((m) => AttachmentModel.fromMap(m)).toList();

      result.add(HabitModel.fromMap(row, logs: logs, attachments: attachments));
    }

    return result;
  }

  Future<HabitModel> saveHabit(HabitModel habit) async {
    final db = await database;

    return db.transaction<HabitModel>((txn) async {
      late final int habitId;

      if (habit.id == null) {
        habitId = await txn.insert(tableHabits, habit.toMap());
      } else {
        habitId = habit.id!;
        await txn.update(
          tableHabits,
          habit.toMap(),
          where: 'id = ?',
          whereArgs: [habitId],
        );
        await txn.delete(
          tableAttachments,
          where: 'habit_id = ?',
          whereArgs: [habitId],
        );
      }

      final List<AttachmentModel> savedAttachments = [];
      for (final att in habit.attachments) {
        final attToInsert = att.copyWith(habitId: habitId);
        final attMap = attToInsert.toMap()..remove('id');
        final attId = await txn.insert(tableAttachments, attMap);
        savedAttachments.add(attToInsert.copyWith(id: attId));
      }

      return habit.copyWith(id: habitId, attachments: savedAttachments);
    });
  }

  Future<void> deleteHabit(int habitId) async {
    final db = await database;
    await db.delete(
      tableHabits,
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<HabitLogModel> insertHabitLog(HabitLogModel log) async {
    final db = await database;
    final id = await db.insert(tableHabitLogs, log.toMap());
    return log.copyWith(id: id);
  }

  Future<void> deleteHabitLog(int logId) async {
    final db = await database;
    await db.delete(
      tableHabitLogs,
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  Future<void> _seedInitialDemoData(Database db) async {
    final now = DateTime.now();

    final userId = await db.insert(tableUsers, {
      'full_name': 'Назарій Дмитренко',
      'email': 'demo@habit.ua',
      'password_hash': '123456',
      'created_at': now.subtract(const Duration(days: 20)).toIso8601String(),
    });

    final gymHabitId = await db.insert(tableHabits, {
      'user_id': userId,
      'title': 'Тренування в спортзалі',
      'description': 'Силове тренування або кардіо тривалістю від 45 хвилин.',
      'target_count': 12,
      'goal_period': GoalPeriod.monthly.toShortString(),
      'created_at': now.subtract(const Duration(days: 15)).toIso8601String(),
    });

    await db.insert(tableHabitLogs, {
      'habit_id': gymHabitId,
      'log_date': now.subtract(const Duration(days: 2)).toIso8601String(),
      'is_completed': 1,
      'note': 'Інтенсивне тренування',
    });
  }
}