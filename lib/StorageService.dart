// services/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class StorageService {
  static const String _opportunitiesKey = 'missed_opportunities';
  static const String _goalsKey = 'goals';
  static const String _categoriesKey = 'categories';

  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  StorageService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // === OPPORTUNITIES ===
  Future<void> saveOpportunities(List<MissedOpportunity> opportunities) async {
    final jsonList = opportunities.map((o) => o.toJson()).toList();
    await _prefs.setString(_opportunitiesKey, jsonEncode(jsonList));
  }

  List<MissedOpportunity> loadOpportunities() {
    final jsonString = _prefs.getString(_opportunitiesKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => MissedOpportunity.fromJson(json)).toList();
  }

  // === GOALS ===
  Future<void> saveGoals(List<Goal> goals) async {
    final jsonList = goals.map((g) =>
    {
      'id': g.id,
      'title': g.title,
      'targetDays': g.targetDays,
      'startDate': g.startDate.toIso8601String(),
      'isCompleted': g.isCompleted,
    }).toList();
    await _prefs.setString(_goalsKey, jsonEncode(jsonList));
  }

  List<Goal> loadGoals() {
    final jsonString = _prefs.getString(_goalsKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) =>
        Goal(
          id: json['id'],
          title: json['title'],
          targetDays: json['targetDays'],
          startDate: DateTime.parse(json['startDate']),
          isCompleted: json['isCompleted'] ?? false,
        )).toList();
  }

  // === CATEGORIES ===
  Future<void> saveCategories(List<String> categories) async {
    await _prefs.setStringList(_categoriesKey, categories);
  }

  List<String> loadCategories() {
    return _prefs.getStringList(_categoriesKey) ??
        ['Salomatlik', 'Ta\'lim', 'Ish', 'Ijtimoiy', 'Boshqa'];
  }
}