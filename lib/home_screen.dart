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
    final targetLevel = level ?? LevelProgress.highestUnlockedLevel;
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
    final currentUnlocked = LevelProgress.highestUnlockedLevel;

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

                    // Highest Level Badge Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        'Level $currentUnlocked',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
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
                              currentUnlocked == 1 ? 'PLAY GAME' : 'CONTINUE',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

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
