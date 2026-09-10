import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo/progress_storage.dart';
import 'package:demo/core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgressStorage.init();
    LevelProgress.loadFromStorage();
  });

  test('Initial state defaults to Level 1 and 0 stars', () {
    expect(LevelProgress.highestUnlockedLevel, 1);
    expect(LevelProgress.currentLevel, 1);
    expect(StarMoney.balance, 0);
    expect(LevelProgress.starsForLevel(1), 0);
  });

  test('Completing level 1 saves progress, unlocks level 2 and awards stars', () async {
    await LevelProgress.completeLevel(1, 3);

    expect(LevelProgress.highestUnlockedLevel, 2);
    expect(LevelProgress.currentLevel, 2);
    expect(StarMoney.balance, 3);
    expect(LevelProgress.starsForLevel(1), 3);

    // Verify persistence after re-init
    await ProgressStorage.init();
    LevelProgress.loadFromStorage();

    expect(LevelProgress.highestUnlockedLevel, 2);
    expect(LevelProgress.currentLevel, 2);
    expect(StarMoney.balance, 3);
    expect(LevelProgress.starsForLevel(1), 3);
  });

  test('Resetting progress clears saved data', () async {
    await LevelProgress.completeLevel(1, 3);
    await LevelProgress.completeLevel(2, 2);

    expect(LevelProgress.highestUnlockedLevel, 3);

    await LevelProgress.reset();

    expect(LevelProgress.highestUnlockedLevel, 1);
    expect(LevelProgress.currentLevel, 1);
    expect(StarMoney.balance, 0);
    expect(LevelProgress.starsForLevel(1), 0);

    // Verify persistence after re-init
    await ProgressStorage.init();
    LevelProgress.loadFromStorage();

    expect(LevelProgress.highestUnlockedLevel, 1);
    expect(LevelProgress.currentLevel, 1);
    expect(StarMoney.balance, 0);
  });
}
