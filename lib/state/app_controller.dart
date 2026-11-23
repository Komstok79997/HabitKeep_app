// Файл: lib/state/app_controller.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:med_history_app/database/db_helper.dart';
import 'package:med_history_app/database/file_service.dart';
import 'package:med_history_app/models/app_models.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String habitForm = '/habit-form';
  static const String habitDetail = '/habit-detail';
  static const String profile = '/profile';
}

enum HabitFilter { all, inProgress, achieved }

class AppController extends ChangeNotifier {
  static const String _prefUserIdKey = 'habitkeep_active_user_id';
  static const String _prefThemeKey = 'habitkeep_theme_mode';

  final DatabaseHelper _db = DatabaseHelper.instance;
  final FileService _fileService = FileService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final List<HabitModel> _habits = [];

  UserModel? _currentUser;
  String _searchQuery = '';
  HabitFilter _activeFilter = HabitFilter.all;
  bool _isInitialized = false;
  ThemeMode _themeMode = ThemeMode.system;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String get searchQuery => _searchQuery;
  HabitFilter get activeFilter => _activeFilter;
  bool get isInitialized => _isInitialized;
  ThemeMode get themeMode => _themeMode;

  IconData get currentThemeIcon {
    if (_themeMode == ThemeMode.system) return Icons.brightness_auto_rounded;
    if (_themeMode == ThemeMode.light) return Icons.light_mode_rounded;
    return Icons.dark_mode_rounded;
  }

  List<HabitModel> get allUserHabits {
    if (_currentUser == null) return [];
    return List<HabitModel>.unmodifiable(_habits);
  }

  List<HabitModel> get filteredHabits {
    return allUserHabits.where((habit) {
      if (!habit.matchesSearchQuery(_searchQuery)) return false;

      switch (_activeFilter) {
        case HabitFilter.all:
          return true;
        case HabitFilter.inProgress:
          return !habit.isGoalAchieved;
        case HabitFilter.achieved:
          return habit.isGoalAchieved;
      }
    }).toList();
  }

  Future<void> initializeApp() async {
    if (_isInitialized) return;

    await _db.database;
    final prefs = await SharedPreferences.getInstance();

    // Відновлюємо тему
    final savedTheme = prefs.getInt(_prefThemeKey);
    if (savedTheme != null && savedTheme >= 0 && savedTheme < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[savedTheme];
    }

    final savedUserId = prefs.getInt(_prefUserIdKey);
    if (savedUserId != null) {
      final user = await _db.getUserById(savedUserId);
      if (user != null) {
        _currentUser = user;
        await _reloadCurrentUserHabits();
      } else {
        await prefs.remove(_prefUserIdKey);
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> cycleTheme() async {
    if (_themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefThemeKey, _themeMode.index);
  }

  Future<void> _reloadCurrentUserHabits() async {
    _habits.clear();
    if (_currentUser?.id == null) return;
    final loaded = await _db.getHabitsForUser(_currentUser!.id!);
    _habits.addAll(loaded);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(HabitFilter filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void resetSearchAndFilters() {
    _searchQuery = '';
    _activeFilter = HabitFilter.all;
    notifyListeners();
  }

  Future<String?> login({required String email, required String password}) async {
    final user = await _db.getUserByEmail(email);
    if (user == null) return 'Користувача з таким Email не знайдено.';
    if (user.passwordHash != password) return 'Невірний пароль.';

    _currentUser = user;
    resetSearchAndFilters();
    await _reloadCurrentUserHabits();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefUserIdKey, user.id!);

    notifyListeners();
    return null;
  }

  Future<String?> register({required String fullName, required String email, required String password}) async {
    final existing = await _db.getUserByEmail(email);
    if (existing != null) return 'Користувач із цим Email вже зареєстрований.';

    final createdUser = await _db.insertUser(UserModel(
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: password,
      createdAt: DateTime.now(),
    ));

    _currentUser = createdUser;
    _habits.clear();
    resetSearchAndFilters();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefUserIdKey, createdUser.id!);

    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    _currentUser = null;
    _habits.clear();
    resetSearchAndFilters();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUserIdKey);
    notifyListeners();
  }

  Future<void> deleteCurrentAccount() async {
    final user = _currentUser;
    if (user?.id == null) return;

    final filePaths = await _db.getUserAttachmentPaths(user!.id!);
    await _fileService.deleteMultipleFiles(filePaths);

    await _db.deleteUserById(user.id!);

    _currentUser = null;
    _habits.clear();
    resetSearchAndFilters();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUserIdKey);

    notifyListeners();
  }

  HabitModel? getHabitById(int habitId) {
    try {
      return _habits.firstWhere((h) => h.id == habitId);
    } catch (_) {
      return null;
    }
  }

  Future<HabitModel> saveHabit({
    int? existingId,
    required String title,
    String? description,
    required int targetCount,
    required GoalPeriod goalPeriod,
    required List<AttachmentModel> attachments,
  }) async {
    if (_currentUser?.id == null) throw StateError('Помилка авторизації.');

    if (existingId != null) {
      final old = getHabitById(existingId);
      if (old != null) {
        final newPaths = attachments.map((a) => a.filePath).toSet();
        final removedPaths = old.attachments
            .map((a) => a.filePath)
            .where((oldPath) => !newPaths.contains(oldPath));
        await _fileService.deleteMultipleFiles(removedPaths);
      }
    }

    final List<AttachmentModel> persistedAttachments = [];
    for (final att in attachments) {
      final permanentPath = await _fileService.saveFilePermanently(
        sourcePath: att.filePath,
        originalFileName: att.fileName,
      );
      persistedAttachments.add(att.copyWith(filePath: permanentPath));
    }

    final existing = existingId != null ? getHabitById(existingId) : null;
    final habitToSave = HabitModel(
      id: existingId,
      userId: _currentUser!.id!,
      title: title.trim(),
      description: description?.trim(),
      targetCount: targetCount < 1 ? 1 : targetCount,
      goalPeriod: goalPeriod,
      createdAt: existing?.createdAt ?? DateTime.now(),
      attachments: persistedAttachments,
    );

    final saved = await _db.saveHabit(habitToSave);
    await _reloadCurrentUserHabits();
    notifyListeners();
    return saved;
  }

  Future<void> deleteHabit(int habitId) async {
    final target = getHabitById(habitId);
    if (target != null) {
      final paths = target.attachments.map((a) => a.filePath);
      await _fileService.deleteMultipleFiles(paths);
    }

    await _db.deleteHabit(habitId);
    _habits.removeWhere((h) => h.id == habitId);
    notifyListeners();
  }

  Future<void> addHabitLog({
    required int habitId,
    required bool isCompleted,
    DateTime? logDate,
    String? note,
  }) async {
    final newLog = HabitLogModel(
      habitId: habitId,
      logDate: logDate ?? DateTime.now(),
      isCompleted: isCompleted,
      note: note,
    );
    await _db.insertHabitLog(newLog);
    await _reloadCurrentUserHabits();
    notifyListeners();
  }

  Future<void> deleteHabitLog(int logId) async {
    await _db.deleteHabitLog(logId);
    await _reloadCurrentUserHabits();
    notifyListeners();
  }

  Future<AttachmentModel?> pickImageAttachment({required ImageSource source}) async {
    final XFile? picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return null;

    final permanentPath = await _fileService.saveFilePermanently(
      sourcePath: picked.path,
      originalFileName: picked.name,
    );

    return AttachmentModel(
      fileName: picked.name,
      filePath: permanentPath,
      fileType: AttachmentType.image,
    );
  }

  Future<AttachmentModel?> pickDocumentAttachment() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (file == null || file.path == null) return null;

    final ext = (file.extension ?? '').toLowerCase();
    final type = ext == 'pdf'
        ? AttachmentType.pdf
        : (['jpg', 'jpeg', 'png'].contains(ext) ? AttachmentType.image : AttachmentType.other);

    final permanentPath = await _fileService.saveFilePermanently(
      sourcePath: file.path!,
      originalFileName: file.name,
    );

    return AttachmentModel(
      fileName: file.name,
      filePath: permanentPath,
      fileType: type,
    );
  }
}

class AppStateScope extends InheritedNotifier<AppController> {
  const AppStateScope({super.key, required super.notifier, required super.child});

  static AppController of(BuildContext context, {bool listen = true}) {
    if (listen) return context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier! as AppController;
    return (context.getElementForInheritedWidgetOfExactType<AppStateScope>()!.widget as AppStateScope).notifier! as AppController;
  }
}