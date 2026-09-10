import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core.dart';
import 'board.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _startGame([int? level]) {
    HapticFeedback.selectionClick();
    final targetLevel = level ?? LevelProgress.currentLevel;
    LevelProgress.setCurrentLevel(targetLevel);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ArrowPuzzleScreen(initialLevel: targetLevel),
          ),
        )
        .then((_) {
          // Re-render when returning to home so unlocked levels and progress update
          if (mounted) setState(() {});
        });
  }

  void _showLevelSelectModal() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final highestUnlocked = LevelProgress.highestUnlockedLevel;
        final totalLevelsToShow = max(highestUnlocked + 5, 15);

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Stage',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.0,
                        ),
                    itemCount: totalLevelsToShow,
                    itemBuilder: (context, index) {
                      final levelNum = index + 1;
                      final isUnlocked = LevelProgress.isUnlocked(levelNum);
                      final stars = LevelProgress.starsForLevel(levelNum);
                      final isCurrent = levelNum == LevelProgress.currentLevel;

                      return InkWell(
                        onTap: isUnlocked
                            ? () {
                                Navigator.of(context).pop();
                                _startGame(levelNum);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? (isCurrent
                                      ? const Color(
                                          0xFFFFB703,
                                        ).withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.08))
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFFFFB703)
                                  : (isUnlocked
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.05)),
                              width: isCurrent ? 2.0 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isUnlocked) ...[
                                Text(
                                  '$levelNum',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent
                                        ? const Color(0xFFFFB703)
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (sIdx) {
                                    return Icon(
                                      sIdx < stars
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 14,
                                      color: sIdx < stars
                                          ? const Color(0xFFFFB703)
                                          : Colors.white30,
                                    );
                                  }),
                                ),
                              ] else ...[
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Colors.white30,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$levelNum',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white30,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHowToPlay() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'How to Play',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRuleItem(
                  icon: Icons.touch_app_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Tap to Slither & Exit',
                  description:
                      'Tap any arrow to make it slither forward and escape the grid in its head direction.',
                ),
                const SizedBox(height: 14),
                _buildRuleItem(
                  icon: Icons.block_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Watch for Obstacles',
                  description:
                      'Arrows cannot pass through other arrows. Tapping a blocked arrow turns it red and costs 1 heart.',
                ),
                const SizedBox(height: 14),
                _buildRuleItem(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFEC4899),
                  title: 'Protect Your 3 Hearts',
                  description:
                      'You have 3 hearts per puzzle. Tapping already-blocked red arrows will not cost extra hearts!',
                ),
                const SizedBox(height: 14),
                _buildRuleItem(
                  icon: Icons.stars_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Clear to Unlock Next Stage',
                  description:
                      'Clear all arrows to earn up to 3 stars and unlock progressively larger grids!',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A2E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Got It!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLevel = LevelProgress.currentLevel;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1E), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Subtle background decorative arrow accents
              Positioned(
                top: 40,
                left: -20,
                child: Transform.rotate(
                  angle: -0.4,
                  child: Icon(
                    Icons.navigation_rounded,
                    size: 140,
                    color: Colors.white.withValues(alpha: 0.025),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                right: -30,
                child: Transform.rotate(
                  angle: 0.6,
                  child: Icon(
                    Icons.navigation_rounded,
                    size: 180,
                    color: Colors.amber.withValues(alpha: 0.03),
                  ),
                ),
              ),

              // Main Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  children: [
                    const Spacer(flex: 1),

                    // Hero Logo & Title
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1.0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB703), Color(0xFFFB8500)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFB8500,
                              ).withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.near_me_rounded,
                            size: 56,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Game Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'ARROW ',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Color(0xFFFFB703),
                          ),
                        ),
                        Text(
                          'PUZZLE',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Untangle the paths • Clear the board',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.65),
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Level & Star Money Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            'Level $activeLevel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ValueListenableBuilder<int>(
                          valueListenable: StarMoney.notifier,
                          builder: (context, balance, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFB703,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFFFFB703,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    color: Color(0xFFFFB703),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$balance',
                                    style: const TextStyle(
                                      color: Color(0xFFFFB703),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const Spacer(flex: 2),

                    // Action Buttons
                    // 1. Play / Continue Primary Button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB703),
                          foregroundColor: const Color(0xFF1A1A2E),
                          elevation: 6,
                          shadowColor: const Color(
                            0xFFFFB703,
                          ).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => _startGame(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 30),
                            const SizedBox(width: 8),
                            Text(
                              activeLevel == 1 &&
                                      LevelProgress.starsForLevel(1) == 0
                                  ? 'PLAY GAME'
                                  : 'CONTINUE (STAGE $activeLevel)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. Select Level Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.20),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                        ),
                        onPressed: _showLevelSelectModal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.grid_view_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'SELECT STAGE',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3. How to Play Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: _showHowToPlay,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.help_outline_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'HOW TO PLAY',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),
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
