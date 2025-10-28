// main.dart - Gamifikatsiya elementlari qo'shilgan versiya
// CalendarScreen ning pastida animatsiyali va colorful Gamification bo'limi qo'shildi

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============ STORAGE SERVICE ============
class StorageService {
  static const String _opportunitiesKey = 'missed_opportunities';
  static const String _goalsKey = 'goals';
  static const String _categoriesKey = 'categories';
  static const String _themeKey = 'isDarkMode';
  static const String _progressKey = 'user_progress';

  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  StorageService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Opportunities
  Future<void> saveOpportunities(List<MissedOpportunity> opportunities) async {
    final jsonList = opportunities.map((o) => o.toJson()).toList();
    await _prefs.setString(_opportunitiesKey, jsonEncode(jsonList));
  }

  List<MissedOpportunity> loadOpportunities() {
    final jsonString = _prefs.getString(_opportunitiesKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => MissedOpportunity.fromJson(json)).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  // Goals (subtasks bilan saqlash uchun yangilandi)
  Future<void> saveGoals(List<Goal> goals) async {
    final jsonList = goals
        .map(
          (g) => {
            'id': g.id,
            'title': g.title,
            'targetDays': g.targetDays,
            'startDate': g.startDate.toIso8601String(),
            'isCompleted': g.isCompleted,
            'subtasks': g.subtasks.map((st) => st.toJson()).toList(),
          },
        )
        .toList();
    await _prefs.setString(_goalsKey, jsonEncode(jsonList));
  }

  List<Goal> loadGoals() {
    final jsonString = _prefs.getString(_goalsKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map(
          (json) => Goal(
            id: json['id'],
            title: json['title'],
            targetDays: json['targetDays'],
            startDate: DateTime.parse(json['startDate']),
            isCompleted: json['isCompleted'] ?? false,
            subtasks: (json['subtasks'] as List<dynamic>? ?? [])
                .map((stJson) => Subtask.fromJson(stJson))
                .toList(),
          ),
        )
        .toList();
  }

  // Categories
  Future<void> saveCategories(List<String> categories) async {
    await _prefs.setStringList(_categoriesKey, categories);
  }

  List<String> loadCategories() {
    return _prefs.getStringList(_categoriesKey) ??
        ['Salomatlik', 'Ta\'lim', 'Ish', 'Ijtimoiy', 'Boshqa'];
  }

  // Theme
  bool isDarkMode() => _prefs.getBool(_themeKey) ?? true;

  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(_themeKey, isDark);
  }

  // User Progress (Gamification)
  Future<void> saveProgress(UserProgress progress) async {
    final json = progress.toJson();
    await _prefs.setString(_progressKey, jsonEncode(json));
  }

  UserProgress loadProgress() {
    final jsonString = _prefs.getString(_progressKey);
    if (jsonString == null) return UserProgress();
    final json = jsonDecode(jsonString);
    return UserProgress.fromJson(json);
  }
}

// ============ GAMIFICATION MODEL ============
class UserProgress {
  int level;
  int xp;
  int currentStreak;
  List<String> badges;

  UserProgress({
    this.level = 1,
    this.xp = 0,
    this.currentStreak = 0,
    this.badges = const [],
  });

  void addXp(int amount) {
    xp += amount;
    if (xp >= level * 100) {
      level++;
      xp = 0;
    }
  }

  void updateStreak(bool didCompleteToday) {
    if (didCompleteToday) {
      currentStreak++;
    } else {
      currentStreak = 0;
    }
  }

  void addBadge(String badge) {
    if (!badges.contains(badge)) {
      badges.add(badge);
    }
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'xp': xp,
    'currentStreak': currentStreak,
    'badges': badges,
  };

  factory UserProgress.fromJson(Map<String, dynamic> json) => UserProgress(
    level: json['level'] ?? 1,
    xp: json['xp'] ?? 0,
    currentStreak: json['currentStreak'] ?? 0,
    badges: List<String>.from(json['badges'] ?? []),
  );
}

// ============ PROGRESS VIEW MODEL ============
final progressProvider = StateNotifierProvider<ProgressViewModel, UserProgress>(
  (ref) => ProgressViewModel(),
);

class ProgressViewModel extends StateNotifier<UserProgress> {
  final StorageService _storage = StorageService();

  ProgressViewModel() : super(UserProgress()) {
    state = _storage.loadProgress();
  }

  void addXp(int amount) {
    state.addXp(amount);
    _storage.saveProgress(state);
    state = UserProgress(
      level: state.level,
      xp: state.xp,
      currentStreak: state.currentStreak,
      badges: state.badges,
    );
  }

  void updateStreak(bool didComplete) {
    state.updateStreak(didComplete);
    _storage.saveProgress(state);
    state = UserProgress(
      level: state.level,
      xp: state.xp,
      currentStreak: state.currentStreak,
      badges: state.badges,
    );
  }

  void addBadge(String badge) {
    state.addBadge(badge);
    _storage.saveProgress(state);
    state = UserProgress(
      level: state.level,
      xp: state.xp,
      currentStreak: state.currentStreak,
      badges: state.badges,
    );
  }
}

// ============ THEME PROVIDER ============
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final StorageService _storage = StorageService();

  ThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  void _loadTheme() {
    state = _storage.isDarkMode() ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _storage.setDarkMode(state == ThemeMode.dark);
  }
}

// ============ APP COLORS ============
class AppColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF0A0E21) : const Color(0xFFF5F5F5);

  static Color cardBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1D1E33) : Colors.white;

  static Color cardBgSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF2B2D42) : const Color(0xFFF0F0F0);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF1A1A1A);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? Colors.grey[400]! : Colors.grey[700]!;

  static Color primary = const Color(0xFF6C63FF);
  static Color secondary = const Color(0xFF4CAF50);
  static Color accent = const Color(0xFF2196F3);
  static Color warning = const Color(0xFFFF9800);
  static Color error = const Color(0xFFFF6B6B);
}

// ============ RESPONSIVE HELPER ============
class ResponsiveHelper {
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isMobile(BuildContext context) => width(context) < 600;

  static bool isTablet(BuildContext context) =>
      width(context) >= 600 && width(context) < 1024;

  static bool isDesktop(BuildContext context) => width(context) >= 1024;

  static double getResponsiveValue(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    return EdgeInsets.all(
      getResponsiveValue(context, mobile: 16, tablet: 24, desktop: 32),
    );
  }

  static double getFontSize(BuildContext context, double baseSize) {
    return baseSize *
        getResponsiveValue(context, mobile: 1.0, tablet: 1.1, desktop: 1.2);
  }

  static int getCrossAxisCount(BuildContext context) {
    if (isDesktop(context)) return 3;
    if (isTablet(context)) return 2;
    return 1;
  }
}

// ============ MODELS ============
class MissedOpportunity {
  final String id;
  final String title;
  final String category;
  final DateTime missedDate;
  final String reason;
  final int impactLevel;
  final int order;

  MissedOpportunity({
    required this.id,
    required this.title,
    required this.category,
    required this.missedDate,
    required this.reason,
    required this.impactLevel,
    this.order = 0,
  });

  MissedOpportunity copyWith({
    String? id,
    String? title,
    String? category,
    DateTime? missedDate,
    String? reason,
    int? impactLevel,
    int? order,
  }) {
    return MissedOpportunity(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      missedDate: missedDate ?? this.missedDate,
      reason: reason ?? this.reason,
      impactLevel: impactLevel ?? this.impactLevel,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'missedDate': missedDate.toIso8601String(),
    'reason': reason,
    'impactLevel': impactLevel,
    'order': order,
  };

  factory MissedOpportunity.fromJson(Map<String, dynamic> json) =>
      MissedOpportunity(
        id: json['id'],
        title: json['title'],
        category: json['category'],
        missedDate: DateTime.parse(json['missedDate']),
        reason: json['reason'],
        impactLevel: json['impactLevel'],
        order: json['order'] ?? 0,
      );
}

class Goal {
  final String id;
  final String title;
  final int targetDays;
  final DateTime startDate;
  final bool isCompleted;
  final List<Subtask> subtasks; // Yangi: Subtasks list qo'shildi

  Goal({
    required this.id,
    required this.title,
    required this.targetDays,
    required this.startDate,
    this.isCompleted = false,
    this.subtasks = const [],
  });

  Goal copyWith({bool? isCompleted, List<Subtask>? subtasks}) {
    return Goal(
      id: id,
      title: title,
      targetDays: targetDays,
      startDate: startDate,
      isCompleted: isCompleted ?? this.isCompleted,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}

class Subtask {
  final String title;
  final bool isCompleted;

  Subtask({required this.title, this.isCompleted = false});

  Map<String, dynamic> toJson() => {'title': title, 'isCompleted': isCompleted};

  factory Subtask.fromJson(Map<String, dynamic> json) =>
      Subtask(title: json['title'], isCompleted: json['isCompleted'] ?? false);
}

class AIInsight {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  AIInsight({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ============ VIEW MODELS ============
class OpportunityViewModel
    extends StateNotifier<AsyncValue<List<MissedOpportunity>>> {
  final StorageService _storage = StorageService();

  OpportunityViewModel() : super(const AsyncValue.loading()) {
    _loadOpportunities();
  }

  Future<void> _loadOpportunities() async {
    try {
      final opportunities = _storage.loadOpportunities();
      state = AsyncValue.data(opportunities);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void addOpportunity(MissedOpportunity opportunity) {
    state.whenData((opportunities) {
      final newOrder = opportunities.isEmpty
          ? 0
          : opportunities.map((e) => e.order).reduce(math.max) + 1;
      final newList = [...opportunities, opportunity.copyWith(order: newOrder)];
      state = AsyncValue.data(newList);
      _storage.saveOpportunities(newList);
    });
  }

  void updateOpportunity(MissedOpportunity opportunity) {
    state.whenData((opportunities) {
      final updated = opportunities
          .map((o) => o.id == opportunity.id ? opportunity : o)
          .toList();
      state = AsyncValue.data(updated);
      _storage.saveOpportunities(updated);
    });
  }

  void removeOpportunity(String id) {
    state.whenData((opportunities) {
      final filtered = opportunities.where((o) => o.id != id).toList();
      state = AsyncValue.data(filtered);
      _storage.saveOpportunities(filtered);
    });
  }

  void reorderOpportunities(int oldIndex, int newIndex) {
    state.whenData((opportunities) {
      final items = [...opportunities];
      if (newIndex > oldIndex) newIndex--;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);

      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(order: i);
      }

      state = AsyncValue.data(items);
      _storage.saveOpportunities(items);
    });
  }

  int getLazinessLevel() {
    return state.maybeWhen(
      data: (opportunities) {
        if (opportunities.isEmpty) return 0;
        final totalImpact = opportunities.fold<int>(
          0,
          (sum, opp) => sum + opp.impactLevel,
        );
        final maxPossibleImpact = opportunities.length * 5;
        return ((totalImpact / maxPossibleImpact) * 100).round();
      },
      orElse: () => 0,
    );
  }

  Map<DateTime, int> getCalendarData() {
    return state.maybeWhen(
      data: (opportunities) {
        final Map<DateTime, int> data = {};
        for (var opp in opportunities) {
          final date = DateTime(
            opp.missedDate.year,
            opp.missedDate.month,
            opp.missedDate.day,
          );
          data[date] = (data[date] ?? 0) + 1;
        }
        return data;
      },
      orElse: () => {},
    );
  }

  List<AIInsight> getAIInsights() {
    return state.maybeWhen(
      data: (opportunities) {
        if (opportunities.isEmpty) return [];

        List<AIInsight> insights = [];

        Map<String, int> reasonCount = {};
        for (var opp in opportunities) {
          reasonCount[opp.reason] = (reasonCount[opp.reason] ?? 0) + 1;
        }
        if (reasonCount.isNotEmpty) {
          final topReason = reasonCount.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          insights.add(
            AIInsight(
              title: 'Asosiy sababingiz',
              description: '"${topReason.key}" - ${topReason.value} marta',
              icon: Icons.lightbulb,
              color: AppColors.warning,
            ),
          );
        }

        int morningCount = 0, eveningCount = 0;
        for (var opp in opportunities) {
          if (opp.missedDate.hour < 12) {
            morningCount++;
          } else {
            eveningCount++;
          }
        }
        if (eveningCount > morningCount) {
          insights.add(
            AIInsight(
              title: 'Vaqt naqshi',
              description: 'Kechqurun ko\'proq imkoniyat o\'tkazasiz',
              icon: Icons.nightlight_round,
              color: AppColors.accent,
            ),
          );
        }

        Map<String, int> categoryCount = {};
        for (var opp in opportunities) {
          categoryCount[opp.category] = (categoryCount[opp.category] ?? 0) + 1;
        }
        if (categoryCount.isNotEmpty) {
          final topCategory = categoryCount.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          insights.add(
            AIInsight(
              title: 'E\'tibor bering',
              description: '${topCategory.key} sohasi muammoli',
              icon: Icons.warning_amber,
              color: AppColors.error,
            ),
          );
        }

        insights.add(
          AIInsight(
            title: 'Tavsiya',
            description: 'Har kuni 5 daqiqa rejalashtiring',
            icon: Icons.tips_and_updates,
            color: AppColors.secondary,
          ),
        );

        return insights;
      },
      orElse: () => [],
    );
  }
}

class CategoriesViewModel extends StateNotifier<List<String>> {
  final StorageService _storage = StorageService();

  CategoriesViewModel() : super([]) {
    state = _storage.loadCategories();
  }

  void addCategory(String category) {
    if (!state.contains(category) && category.isNotEmpty) {
      state = [...state, category];
      _storage.saveCategories(state);
    }
  }
}

class GoalsViewModel extends StateNotifier<List<Goal>> {
  final StorageService _storage = StorageService();

  GoalsViewModel() : super([]) {
    state = _storage.loadGoals();
  }

  void addGoal(Goal goal) {
    state = [...state, goal];
    _storage.saveGoals(state);
  }

  void toggleGoalCompletion(String id) {
    state = state.map((goal) {
      if (goal.id == id) {
        return goal.copyWith(isCompleted: !goal.isCompleted);
      }
      return goal;
    }).toList();
    _storage.saveGoals(state);
  }

  void removeGoal(String id) {
    state = state.where((goal) => goal.id != id).toList();
    _storage.saveGoals(state);
  }

  void addSubtask(String goalId, Subtask subtask) {
    state = state.map((goal) {
      if (goal.id == goalId) {
        return goal.copyWith(subtasks: [...goal.subtasks, subtask]);
      }
      return goal;
    }).toList();
    _storage.saveGoals(state);
  }

  void toggleSubtaskCompletion(String goalId, int subtaskIndex) {
    state = state.map((goal) {
      if (goal.id == goalId) {
        final updatedSubtasks = goal.subtasks.asMap().entries.map((entry) {
          final index = entry.key;
          final st = entry.value;
          if (index == subtaskIndex) {
            return Subtask(title: st.title, isCompleted: !st.isCompleted);
          }
          return st;
        }).toList();
        return goal.copyWith(subtasks: updatedSubtasks);
      }
      return goal;
    }).toList();
    _storage.saveGoals(state);
  }
}

// ============ PROVIDERS ============
final opportunityViewModelProvider =
    StateNotifierProvider<
      OpportunityViewModel,
      AsyncValue<List<MissedOpportunity>>
    >((ref) => OpportunityViewModel());

final categoriesProvider =
    StateNotifierProvider<CategoriesViewModel, List<String>>(
      (ref) => CategoriesViewModel(),
    );

final goalsProvider = StateNotifierProvider<GoalsViewModel, List<Goal>>(
  (ref) => GoalsViewModel(),
);

final selectedIndexProvider = StateProvider<int>((ref) => 0);

// ============ MAIN APP ============
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().init();
  runApp(const ProviderScope(child: ShadowHabitsApp()));
}

class ShadowHabitsApp extends ConsumerWidget {
  const ShadowHabitsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Shadow Habits',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        brightness: Brightness.light,
        fontFamily: 'Poppins',
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        brightness: Brightness.dark,
        fontFamily: 'Poppins',
        cardColor: const Color(0xFF1D1E33),
      ),
      home: const MainScreen(),
    );
  }
}

// ============ MAIN SCREEN ============
class MainScreen extends ConsumerWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    final screens = [
      const HomeScreen(),
      const CalendarScreen(),
      const GoalsScreen(),
      const AIInsightsScreen(),
      const AddOpportunityScreen(),
      const StatsScreen(),
    ];

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Row(
          children: [
            _buildSideNav(context, ref),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: screens[selectedIndex],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: screens[selectedIndex],
      ),
      bottomNavigationBar: _buildMobileNav(context, ref),
    );
  }

  Widget _buildSideNav(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedIndexProvider);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: value * 2 * math.pi,
                  child: Icon(
                    Icons.blur_on,
                    size: 60,
                    color: AppColors.primary,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Shadow Habits',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 40),
            _buildDesktopNavItem(
              context,
              ref,
              0,
              Icons.home_rounded,
              'Bosh sahifa',
              selectedIndex,
            ),
            _buildDesktopNavItem(
              context,
              ref,
              1,
              Icons.calendar_month,
              'Kalendar',
              selectedIndex,
            ),
            _buildDesktopNavItem(
              context,
              ref,
              2,
              Icons.flag,
              'Maqsadlar',
              selectedIndex,
            ),
            _buildDesktopNavItem(
              context,
              ref,
              3,
              Icons.psychology,
              'AI Tahlil',
              selectedIndex,
            ),
            _buildDesktopNavItem(
              context,
              ref,
              4,
              Icons.add_circle,
              'Qo\'shish',
              selectedIndex,
            ),
            _buildDesktopNavItem(
              context,
              ref,
              5,
              Icons.analytics,
              'Statistika',
              selectedIndex,
            ),
            const Spacer(),
            _buildThemeToggle(context, ref),
            const SizedBox(height: 20),
            _buildExportButton(context, ref),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'v2.0.0 Pro',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNavItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    IconData icon,
    String label,
    int selectedIndex,
  ) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => ref.read(selectedIndexProvider.notifier).state = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [AppColors.primary, AppColors.secondary])
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : AppColors.textSecondary(context),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppColors.textSecondary(context),
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              isDark ? 'Tungi rejim' : 'Kunduzgi rejim',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Export qilindi! PDF saqland'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.secondary, AppColors.accent],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Export PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNav(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedIndexProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, ref, 0, Icons.home_rounded, 'Bosh'),
              _buildNavItem(context, ref, 1, Icons.calendar_month, 'Kalendar'),
              _buildNavItem(context, ref, 2, Icons.flag, 'Maqsad'),
              _buildNavItem(context, ref, 3, Icons.psychology, 'AI'),
              _buildNavItem(context, ref, 4, Icons.add_circle, 'Qo\'sh'),
              _buildNavItem(context, ref, 5, Icons.analytics, 'Stat'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    IconData icon,
    String label,
  ) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => ref.read(selectedIndexProvider.notifier).state = index,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Color.lerp(Colors.transparent, AppColors.primary, value),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Color.lerp(
                    AppColors.textSecondary(context),
                    Colors.white,
                    value,
                  ),
                  size: 22,
                ),
                if (value > 0.3)
                  Opacity(
                    opacity: (value - 0.3) / 0.7,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============ HOME SCREEN ============
class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunitiesAsync = ref.watch(opportunityViewModelProvider);

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: ResponsiveHelper.getResponsiveValue(
              context,
              mobile: 180,
              tablet: 220,
              desktop: 260,
            ),
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background(context),
            actions: [
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: AppColors.textPrimary(context),
                ),
                onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Shadow Habits',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveHelper.getFontSize(context, 20),
                  color: AppColors.textPrimary(context),
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.background(context)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 2),
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 2 * math.pi,
                        child: Icon(
                          Icons.blur_on,
                          size: ResponsiveHelper.getResponsiveValue(
                            context,
                            mobile: 60,
                            tablet: 80,
                            desktop: 100,
                          ),
                          color: Colors.white.withOpacity(0.3),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: ResponsiveHelper.getResponsivePadding(context),
            sliver: opportunitiesAsync.when(
              data: (opportunities) {
                if (opportunities.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: ResponsiveHelper.getResponsiveValue(
                              context,
                              mobile: 80,
                              tablet: 100,
                              desktop: 120,
                            ),
                            color: AppColors.textSecondary(context),
                          ),
                          SizedBox(
                            height: ResponsiveHelper.getResponsiveValue(
                              context,
                              mobile: 20,
                              tablet: 30,
                              desktop: 40,
                            ),
                          ),
                          Text(
                            'Hali hech narsa yo\'q',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getFontSize(
                                context,
                                20,
                              ),
                              color: AppColors.textSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'O\'tkazib yuborilgan imkoniyatlarni qo\'shing',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getFontSize(
                                context,
                                14,
                              ),
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverReorderableList(
                  itemBuilder: (context, index) {
                    final opportunity = opportunities[index];
                    return ReorderableDelayedDragStartListener(
                      key: Key(opportunity.id),
                      index: index,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 300 + (index * 100)),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 50 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: OpportunityCard(opportunity: opportunity),
                      ),
                    );
                  },
                  itemCount: opportunities.length,
                  onReorder: (oldIndex, newIndex) {
                    ref
                        .read(opportunityViewModelProvider.notifier)
                        .reorderOpportunities(oldIndex, newIndex);
                  },
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, s) => SliverFillRemaining(
                child: Center(child: Text('Xatolik: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ OPPORTUNITY CARD ============
class OpportunityCard extends ConsumerStatefulWidget {
  final MissedOpportunity opportunity;

  const OpportunityCard({Key? key, required this.opportunity})
    : super(key: key);

  @override
  ConsumerState<OpportunityCard> createState() => _OpportunityCardState();
}

class _OpportunityCardState extends ConsumerState<OpportunityCard>
    with SingleTickerProviderStateMixin {
  bool _showActions = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
      if (_showActions) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _deleteOpportunity() {
    ref
        .read(opportunityViewModelProvider.notifier)
        .removeOpportunity(widget.opportunity.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('O\'chirildi'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _updateOpportunity() {
    _showUpdateDialog();
  }

  void _shareOpportunity() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ulashish: ${widget.opportunity.title}'),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showUpdateDialog() {
    final titleController = TextEditingController(
      text: widget.opportunity.title,
    );
    final reasonController = TextEditingController(
      text: widget.opportunity.reason,
    );
    int impactLevel = widget.opportunity.impactLevel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Tahrirlash',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    labelText: 'Sarlavha',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textSecondary(context),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Sabab',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textSecondary(context),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ta\'sir: $impactLevel/5',
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                    Slider(
                      value: impactLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: AppColors.primary,
                      onChanged: (value) {
                        setDialogState(() => impactLevel = value.toInt());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Bekor qilish',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = widget.opportunity.copyWith(
                  title: titleController.text,
                  reason: reasonController.text,
                  impactLevel: impactLevel,
                );
                ref
                    .read(opportunityViewModelProvider.notifier)
                    .updateOpportunity(updated);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Yangilandi'),
                    backgroundColor: AppColors.secondary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _toggleActions,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.cardBg(context),
                  AppColors.cardBgSecondary(context),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: ResponsiveHelper.getResponsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.opportunity.title,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(context, 18),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(widget.opportunity.category),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.opportunity.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(widget.opportunity.missedDate),
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sabab: ${widget.opportunity.reason}',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Ta\'sir:',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(5, (index) {
                        return Icon(
                          index < widget.opportunity.impactLevel
                              ? Icons.star
                              : Icons.star_border,
                          color: const Color(0xFFFFD700),
                          size: 16,
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_showActions)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildActionButton(
                          icon: Icons.delete,
                          color: AppColors.error,
                          onTap: _deleteOpportunity,
                        ),
                      ),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildActionButton(
                          icon: Icons.edit,
                          color: AppColors.primary,
                          onTap: _updateOpportunity,
                        ),
                      ),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildActionButton(
                          icon: Icons.share,
                          color: AppColors.secondary,
                          onTap: _shareOpportunity,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        _toggleActions();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Salomatlik':
        return const Color(0xFF4CAF50);
      case 'Ta\'lim':
        return const Color(0xFF2196F3);
      case 'Ish':
        return const Color(0xFFFF9800);
      case 'Ijtimoiy':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF9C27B0);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    if (difference == 0) return 'Bugun';
    if (difference == 1) return 'Kecha';
    return '$difference kun oldin';
  }
}

// ============ CALENDAR SCREEN ============
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarData = ref
        .read(opportunityViewModelProvider.notifier)
        .getCalendarData();

    return SafeArea(
      child: Padding(
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kalendar Ko\'rinishi',
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context, 26),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Qaysi kunlarda imkoniyat o\'tkazdingiz',
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context, 15),
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CalendarHeatMap(data: calendarData),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(flex: 1, child: GamificationSection()),
          ],
        ),
      ),
    );
  }
}

class CalendarHeatMap extends StatelessWidget {
  final Map<DateTime, int> data;

  const CalendarHeatMap({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 35,
      itemBuilder: (context, index) {
        final date = DateTime.now().subtract(Duration(days: 34 - index));
        final count = data[DateTime(date.year, date.month, date.day)] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: count == 0
                ? AppColors.textSecondary(context).withOpacity(0.1)
                : AppColors.error.withOpacity(
                    0.2 + (count * 0.2).clamp(0, 0.8),
                  ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============ GAMIFICATION SECTION (Animatsiyali va colorful) ============
class GamificationSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gamifikatsiya',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildLevelProgress(progress, context),
            const SizedBox(height: 16),
            _buildStreakCounter(progress, context),
            const SizedBox(height: 16),
            _buildBadgesList(progress, context),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(progressProvider.notifier).addXp(50);
                ref.read(progressProvider.notifier).updateStreak(true);
                ref
                    .read(progressProvider.notifier)
                    .addBadge('Motivatsiya Ustasi');
              },
              child: const Text('XP Qo\'shish va Streak Yangilash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgress(UserProgress progress, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daraja: ${progress.level}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: progress.xp / (progress.level * 100)),
          duration: const Duration(seconds: 1),
          builder: (context, value, child) {
            return LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.yellow),
              minHeight: 10,
            );
          },
        ),
        Text(
          'XP: ${progress.xp}/${progress.level * 100}',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildStreakCounter(UserProgress progress, BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.fireplace, color: Colors.orange, size: 32),
        const SizedBox(width: 8),
        Text(
          'Ketma-ket kunlar: ${progress.currentStreak}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildBadgesList(UserProgress progress, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nishonlar:',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        Wrap(
          spacing: 8,
          children: progress.badges
              .map(
                (badge) => TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Chip(
                        label: Text(badge),
                        backgroundColor: Colors.green,
                        avatar: const Icon(Icons.star, color: Colors.yellow),
                      ),
                    );
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ============ GOALS SCREEN ============
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  int calculateXp(int targetDays) {
    if (targetDays <= 3) return 100;
    if (targetDays <= 5) return 170;
    if (targetDays <= 10) return 200;
    if (targetDays <= 20) return 300;
    return 500;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);

    // Active va Completed goals ga bo'lish
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    final completedGoals = goals.where((g) => g.isCompleted).toList();

    return SafeArea(
      child: Padding(
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Maqsadlarim',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getFontSize(context, 26),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  onPressed: () => _showAddGoalDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: goals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 80,
                            color: AppColors.textSecondary(context),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Hali maqsad yo\'q',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Active Goals bo'limi
                          Text(
                            'Faol Maqsadlar',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getFontSize(
                                context,
                                20,
                              ),
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (activeGoals.isEmpty)
                            Center(
                              child: Text(
                                'Faol maqsadlar yo\'q',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 16,
                                ),
                              ),
                            )
                          else
                            ...activeGoals.map(
                              (goal) => _buildGoalCard(context, ref, goal),
                            ),
                          const SizedBox(height: 30),
                          // Completed Goals bo'limi
                          Text(
                            'Tugatilgan Maqsadlar',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getFontSize(
                                context,
                                20,
                              ),
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (completedGoals.isEmpty)
                            Center(
                              child: Text(
                                'Tugatilgan maqsadlar yo\'q',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 16,
                                ),
                              ),
                            )
                          else
                            ...completedGoals.map(
                              (goal) => _buildGoalCard(context, ref, goal),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, WidgetRef ref, Goal goal) {
    final daysElapsed = DateTime.now().difference(goal.startDate).inDays;
    final progress = (daysElapsed / goal.targetDays).clamp(0.0, 1.0);
    final isCompleted = goal.isCompleted;
    final isOverdue = daysElapsed > goal.targetDays && !isCompleted;

    // Colorful dizayn: progress ga qarab rang
    final cardColor = isCompleted
        ? AppColors.secondary.withOpacity(0.8)
        : isOverdue
        ? AppColors.error.withOpacity(0.8)
        : AppColors.accent.withOpacity(0.8);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cardColor, cardColor.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.white),
                        onPressed: () => ref
                            .read(goalsProvider.notifier)
                            .removeGoal(goal.id),
                      ),
                      Expanded(
                        child: Text(
                          goal.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isCompleted
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          ref
                              .read(goalsProvider.notifier)
                              .toggleGoalCompletion(goal.id);
                          final updatedGoal = ref
                              .read(goalsProvider)
                              .firstWhere((g) => g.id == goal.id);
                          if (updatedGoal.isCompleted &&
                              daysElapsed >= goal.targetDays) {
                            ref
                                .read(progressProvider.notifier)
                                .addXp(calculateXp(goal.targetDays));
                            ref
                                .read(progressProvider.notifier)
                                .addBadge('Maqsad Ustasi');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$daysElapsed / ${goal.targetDays} kun',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Murakkab logika: Subtasks qo'shish va check qilish
                  if (!isCompleted) // Tugatilgan bo'lsa subtasks ko'rsatilmaydi va qo'shilmaydi
                    _buildSubtasksSection(context, ref, goal),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtasksSection(BuildContext context, WidgetRef ref, Goal goal) {
    // O'ylangan logika: Har bir goal uchun subtasks (kunlik vazifalar) qo'shish
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kunlik Vazifalar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (goal.subtasks.isEmpty)
          const Text(
            'Vazifalar yo\'q',
            style: TextStyle(color: Colors.white70),
          ),
        ...goal.subtasks.asMap().entries.map((entry) {
          final index = entry.key;
          final subtask = entry.value;
          return Row(
            children: [
              Checkbox(
                value: subtask.isCompleted,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(goalsProvider.notifier)
                        .toggleSubtaskCompletion(goal.id, index);
                    if (value) {
                      // Check qilinganda XP qo'shish va streak update
                      ref.read(progressProvider.notifier).addXp(20);
                      ref.read(progressProvider.notifier).updateStreak(true);
                      ref
                          .read(progressProvider.notifier)
                          .addBadge('Kunlik Vazifa Ustasi');
                    }
                  }
                },
                checkColor: AppColors.primary,
                activeColor: Colors.white,
              ),
              Expanded(
                child: Text(
                  subtask.title,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        }),
        ElevatedButton.icon(
          onPressed: () {
            // Subtask qo'shish dialogi (o'zim o'ylagan kreativ logika)
            _showAddSubtaskDialog(context, ref, goal);
          },
          icon: const Icon(Icons.add),
          label: const Text('Yangi Vazifa Qo\'shish'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  void _showAddSubtaskDialog(BuildContext context, WidgetRef ref, Goal goal) {
    final subtaskController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yangi Kunlik Vazifa'),
        content: TextField(
          controller: subtaskController,
          decoration: const InputDecoration(
            hintText: 'Masalan: 30 daqiqa yurish',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () {
              if (subtaskController.text.isNotEmpty) {
                ref
                    .read(goalsProvider.notifier)
                    .addSubtask(
                      goal.id,
                      Subtask(title: subtaskController.text),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Qo\'shish'),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    int targetDays = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.cardBg(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Yangi Maqsad',
            style: TextStyle(color: AppColors.textPrimary(context)),
          ),
          content: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        style: TextStyle(color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          labelText: 'Maqsad',
                          labelStyle: TextStyle(
                            color: AppColors.textSecondary(context),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Muddati: $targetDays kun',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 200,
                            width: 200,
                            child: CircularProgressIndicator(
                              value: targetDays / 666,
                              strokeWidth: 8,
                              backgroundColor: AppColors.secondary.withOpacity(
                                0.3,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            '$targetDays',
                            style: TextStyle(
                              fontSize: 40,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: targetDays.toDouble(),
                        min: 0,
                        max: 666,
                        divisions: 666,
                        activeColor: AppColors.primary,
                        onChanged: (value) =>
                            setState(() => targetDays = value.toInt()),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Bekor',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  ref
                      .read(goalsProvider.notifier)
                      .addGoal(
                        Goal(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text,
                          targetDays: targetDays,
                          startDate: DateTime.now(),
                        ),
                      );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Ajoyib maqsad qo\'shildi!'),
                      backgroundColor: AppColors.secondary,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Qo\'shish'),
            ),
          ],

        ),
      ),
    );
  }
}

// ============ AI INSIGHTS SCREEN ============
class AIInsightsScreen extends ConsumerWidget {
  const AIInsightsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref
        .read(opportunityViewModelProvider.notifier)
        .getAIInsights();

    return SafeArea(
      child: Padding(
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary, size: 32),
                const SizedBox(width: 12),
                Text(
                  'AI Tahlil',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getFontSize(context, 26),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Sun\'iy intellekt tahlili',
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context, 15),
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: insights.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            size: 80,
                            color: AppColors.textSecondary(context),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Tahlil uchun ma\'lumot kerak',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: insights.length,
                      itemBuilder: (context, index) {
                        final insight = insights[index];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 100)),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  insight.color.withOpacity(0.2),
                                  AppColors.cardBg(context),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: insight.color,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: insight.color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(
                                    insight.icon,
                                    color: insight.color,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        insight.title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        insight.description,
                                        style: TextStyle(
                                          color: AppColors.textSecondary(
                                            context,
                                          ),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddOpportunityScreen extends ConsumerStatefulWidget {
  const AddOpportunityScreen({super.key});

  @override
  ConsumerState<AddOpportunityScreen> createState() =>
      _AddOpportunityScreenState();
}

class _AddOpportunityScreenState extends ConsumerState<AddOpportunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _reasonController = TextEditingController();
  String _selectedCategory = 'Salomatlik';
  int _impactLevel = 3;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yangi kategoriya'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(categoriesProvider.notifier)
                    .addCategory(controller.text.trim());
                setState(() => _selectedCategory = controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Qo\'shish'),
          ),
        ],
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final opportunity = MissedOpportunity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        category: _selectedCategory,
        missedDate: _selectedDate,
        reason: _reasonController.text,
        impactLevel: _impactLevel,
      );

      ref
          .read(opportunityViewModelProvider.notifier)
          .addOpportunity(opportunity);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Imkoniyat qo\'shildi!'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _titleController.clear();
      _reasonController.clear();
      setState(() {
        _impactLevel = 3;
        _selectedDate = DateTime.now();
      });

      ref.read(selectedIndexProvider.notifier).state = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yangi Imkoniyat',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context, 26),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'O\'tkazib yuborilgan imkoniyatni qo\'shing',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context, 15),
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sarlavha',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'Masalan: Ertalabki sport',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary(context),
                        ),
                        filled: true,
                        fillColor: AppColors.cardBgSecondary(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Sarlavha kiriting' : null,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Kategoriya',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, color: AppColors.primary),
                          onPressed: _showAddCategoryDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBgSecondary(context),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: AppColors.cardBg(context),
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 16,
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value!),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Sabab',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Nima sabab o\'tkazib yubordingiz?',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary(context),
                        ),
                        filled: true,
                        fillColor: AppColors.cardBgSecondary(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Sabab kiriting' : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Sana',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: AppColors.primary,
                                onPrimary: Colors.white,
                                surface: AppColors.cardBg(context),
                                onSurface: AppColors.textPrimary(context),
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null)
                          setState(() => _selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBgSecondary(context),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: TextStyle(
                                color: AppColors.textPrimary(context),
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ta\'sir darajasi: $_impactLevel/5',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(
                        5,
                        (i) => GestureDetector(
                          onTap: () => setState(() => _impactLevel = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              i < _impactLevel ? Icons.star : Icons.star_border,
                              color: const Color(0xFFFFD700),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Qo\'shish',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ STATS SCREEN ============
class StatsScreen extends ConsumerWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunitiesAsync = ref.watch(opportunityViewModelProvider);
    final lazinessLevel = ref
        .read(opportunityViewModelProvider.notifier)
        .getLazinessLevel();

    return SafeArea(
      child: SingleChildScrollView(
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistika',
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context, 26),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Umumiy ma\'lumotlar va tahlil',
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context, 15),
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Dangasalik darajasi',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(context, 18),
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: lazinessLevel.toDouble()),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: ResponsiveHelper.getResponsiveValue(
                                context,
                                mobile: 180,
                                tablet: 220,
                                desktop: 260,
                              ),
                              height: ResponsiveHelper.getResponsiveValue(
                                context,
                                mobile: 180,
                                tablet: 220,
                                desktop: 260,
                              ),
                              child: CircularProgressIndicator(
                                value: value / 100,
                                strokeWidth: 20,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  value < 30
                                      ? Colors.green
                                      : value < 60
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  '${value.toInt()}%',
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getFontSize(
                                      context,
                                      48,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _getLazinessEmoji(value.toInt()),
                                  style: const TextStyle(fontSize: 40),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _getLazinessText(lazinessLevel),
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(context, 16),
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            opportunitiesAsync.when(
              data: (opportunities) {
                if (opportunities.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Ma\'lumot yo\'q',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }

                Map<String, int> categoryStats = {};
                int totalImpact = 0;

                for (var opp in opportunities) {
                  categoryStats[opp.category] =
                      (categoryStats[opp.category] ?? 0) + 1;
                  totalImpact += opp.impactLevel;
                }

                return Column(
                  children: [
                    _buildStatCard(
                      context,
                      'Jami Imkoniyatlar',
                      '${opportunities.length}',
                      Icons.list_alt,
                      AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      context,
                      'Umumiy Ta\'sir',
                      '$totalImpact',
                      Icons.trending_up,
                      AppColors.warning,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      context,
                      'O\'rtacha Ta\'sir',
                      '${(totalImpact / opportunities.length).toStringAsFixed(1)}/5',
                      Icons.auto_graph,
                      AppColors.accent,
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Kategoriya bo\'yicha',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(context, 20),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...categoryStats.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(context),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textPrimary(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(
                                  entry.key,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${entry.value}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _getCategoryColor(entry.key),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, s) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'Xatolik: $e',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Salomatlik':
        return const Color(0xFF4CAF50);
      case 'Ta\'lim':
        return const Color(0xFF2196F3);
      case 'Ish':
        return const Color(0xFFFF9800);
      case 'Ijtimoiy':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF9C27B0);
    }
  }

  String _getLazinessEmoji(int level) {
    if (level < 20) return '🏆';
    if (level < 40) return '😊';
    if (level < 60) return '😐';
    if (level < 80) return '😟';
    return '🚨';
  }

  String _getLazinessText(int level) {
    if (level < 20) return 'Ajoyib! Siz juda faolsiz!';
    if (level < 40) return 'Yaxshi! Davom eting!';
    if (level < 60) return 'O\'rtacha. Yaxshiroq bo\'lish mumkin';
    if (level < 80) return 'Ogohlik! Ko\'proq harakat qiling';
    return 'Xavfli daraja! Zudlik bilan harakat qiling';
  }
}
