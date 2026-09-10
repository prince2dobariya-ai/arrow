import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressStorage {
  static const String _keyHighestUnlockedLevel = 'arrow_highest_unlocked_level';
  static const String _keyCurrentLevel = 'arrow_current_level';
  static const String _keyStarMoney = 'arrow_star_money';
  static const String _keyLevelStars = 'arrow_level_stars';

  static int highestUnlockedLevel = 1;
  static int currentLevel = 1;
  static int starMoney = 0;
  static Map<int, int> levelStars = {};

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      highestUnlockedLevel = prefs.getInt(_keyHighestUnlockedLevel) ?? 1;
      currentLevel = prefs.getInt(_keyCurrentLevel) ?? 1;
      starMoney = prefs.getInt(_keyStarMoney) ?? 0;

      final starsJson = prefs.getString(_keyLevelStars);
      if (starsJson != null && starsJson.isNotEmpty) {
        final decoded = jsonDecode(starsJson) as Map<String, dynamic>;
        levelStars = decoded.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );
      } else {
        levelStars = {};
      }
    } catch (e) {
      // Fallback defaults on error
      highestUnlockedLevel = 1;
      currentLevel = 1;
      starMoney = 0;
      levelStars = {};
    }
  }

  static Future<void> saveHighestUnlockedLevel(int level) async {
    highestUnlockedLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHighestUnlockedLevel, level);
  }

  static Future<void> saveCurrentLevel(int level) async {
    currentLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCurrentLevel, level);
  }

  static Future<void> saveStarMoney(int balance) async {
    starMoney = balance;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStarMoney, balance);
  }

  static Future<void> saveLevelStars(Map<int, int> starsMap) async {
    levelStars = Map.from(starsMap);
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      starsMap.map((key, value) => MapEntry(key.toString(), value)),
    );
    await prefs.setString(_keyLevelStars, jsonString);
  }

  static Future<void> saveAll({
    required int highestUnlocked,
    required int currentLvl,
    required int starBalance,
    required Map<int, int> starsMap,
  }) async {
    highestUnlockedLevel = highestUnlocked;
    currentLevel = currentLvl;
    starMoney = starBalance;
    levelStars = Map.from(starsMap);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHighestUnlockedLevel, highestUnlocked);
    await prefs.setInt(_keyCurrentLevel, currentLvl);
    await prefs.setInt(_keyStarMoney, starBalance);

    final jsonString = jsonEncode(
      starsMap.map((key, value) => MapEntry(key.toString(), value)),
    );
    await prefs.setString(_keyLevelStars, jsonString);
  }

  static Future<void> resetAll() async {
    highestUnlockedLevel = 1;
    currentLevel = 1;
    starMoney = 0;
    levelStars = {};

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHighestUnlockedLevel);
    await prefs.remove(_keyCurrentLevel);
    await prefs.remove(_keyStarMoney);
    await prefs.remove(_keyLevelStars);
  }
}
