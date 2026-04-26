import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'workout_screen.dart';
import 'progress_screen.dart';
import 'map_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static const List<double> _weeklyCalories = [320, 450, 280, 500, 390, 610, 420];
  static const List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'Athlete';
    final totalCalories = _weeklyCalories.reduce((a, b) => a + b).toInt();
    final totalWorkouts = 7;
    final avgCalories = (totalCalories / 7).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF00D4FF)),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              'Hello, $displayName 👋',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text("Let's crush today's workout!",
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 24),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Workouts',
                    value: '$totalWorkouts',
                    unit: 'this week',
                    icon: Icons.fitness_center,
                    color: const Color(0xFF00D4FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Calories',
                    value: '$totalCalories',
                    unit: 'kcal total',
                    icon: Icons.local_fire_department,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Avg/Day',
                    value: avgCalories,
                    unit: 'kcal',
                    icon: Icons.bar_chart,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Weekly Calories Bar Chart
            const Text(
              'Weekly Calories Burned',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 700,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => const Color(0xFF0F3460),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()} kcal',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _weekDays.length) return const SizedBox();
                          return Text(
                            _weekDays[idx],
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Colors.white10, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    _weeklyCalories.length,
                        (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _weeklyCalories[i],
                          color: i == 5
                              ? Colors.orangeAccent
                              : const Color(0xFF00D4FF),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Nav Buttons
            const Text(
              'Quick Access',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NavButton(
                    label: 'Workouts',
                    icon: Icons.fitness_center,
                    color: const Color(0xFF00D4FF),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const WorkoutScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NavButton(
                    label: 'Progress',
                    icon: Icons.show_chart,
                    color: Colors.greenAccent,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProgressScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NavButton(
                    label: 'Gym Map',
                    icon: Icons.map,
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => MapScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Motivational Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F3460), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('💪 Keep Going!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    '"The only bad workout is the one that didn\'t happen."',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ───────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(unit,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}