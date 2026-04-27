import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import 'progress_screen.dart';
import 'map_screen.dart';
import 'workout_session_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<String> _weekDays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // Returns calories burned for each day of the current week (Mon–Sun)
  // Index 0 = Monday, index 6 = Sunday
  List<double> _buildWeeklyCalories(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    // Start of current week (Monday)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);

    final List<double> calories = List.filled(7, 0);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['date'] as Timestamp?;
      if (ts == null) continue;
      final d = ts.toDate();
      final dayStart = DateTime(d.year, d.month, d.day);
      final diff = dayStart.difference(weekStart).inDays;
      if (diff >= 0 && diff < 7) {
        calories[diff] += (data['caloriesBurned'] as int? ?? 0).toDouble();
      }
    }
    return calories;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final displayName =
    (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : user?.email?.split('@').first ?? 'Athlete';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF00D4FF)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('workout_logs')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final weeklyCalories = _buildWeeklyCalories(docs);
          final totalCaloriesThisWeek =
          weeklyCalories.reduce((a, b) => a + b).toInt();
          final workoutsThisWeek =
              docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = data['date'] as Timestamp?;
                if (ts == null) return false;
                final d = ts.toDate();
                final now = DateTime.now();
                final monday = now.subtract(Duration(days: now.weekday - 1));
                final weekStart = DateTime(monday.year, monday.month, monday.day);
                return !d.isBefore(weekStart);
              }).length;

          final maxY = weeklyCalories.isEmpty
              ? 700.0
              : (weeklyCalories.reduce((a, b) => a > b ? a : b) * 1.3)
              .clamp(100.0, double.infinity);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $displayName 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Let's crush today's workout!",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),

                const SizedBox(height: 20),

                // This week summary
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'This Week',
                        value: '$totalCaloriesThisWeek kcal',
                        icon: Icons.local_fire_department_rounded,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Sessions',
                        value: '$workoutsThisWeek workouts',
                        icon: Icons.fitness_center_rounded,
                        color: const Color(0xFF00D4FF),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quick Access buttons
                Row(
                  children: [
                    Expanded(
                      child: _NavButton(
                        label: 'Progress',
                        icon: Icons.show_chart,
                        color: Colors.greenAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProgressScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _NavButton(
                        label: 'Gym Map',
                        icon: Icons.map,
                        color: Colors.orangeAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MapScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NavButton(
                        label: 'Workout Session',
                        icon: Icons.fitness_center,
                        color: Colors.purpleAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WorkoutSessionScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Weekly Calories Chart
                const Text(
                  'Weekly Calories Burned',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? 'Loading...'
                      : totalCaloriesThisWeek == 0
                      ? 'No workouts logged this week yet'
                      : '$totalCaloriesThisWeek kcal burned this week',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 12),

                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00D4FF)))
                      : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) =>
                          const Color(0xFF0F3460),
                          getTooltipItem:
                              (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.toInt()} kcal',
                              const TextStyle(
                                  color: Colors.white, fontSize: 12),
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
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 ||
                                  index >= _weekDays.length) {
                                return const SizedBox();
                              }
                              return Text(
                                _weekDays[index],
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles:
                            SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles:
                            SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        getDrawingHorizontalLine: (_) =>
                        const FlLine(
                            color: Colors.white10, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (i) {
                        final hasData = weeklyCalories[i] > 0;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: weeklyCalories[i],
                              color: hasData
                                  ? const Color(0xFF00D4FF)
                                  : const Color(0xFF16213E),
                              width: 16,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Motivational card
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💪 Keep Going!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '"The only bad workout is the one that didn\'t happen."',
                        style:
                        TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
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

// ── Supporting Widgets ─────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                    const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
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
        height: 78,
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
