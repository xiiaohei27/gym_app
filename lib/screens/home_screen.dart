import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import 'progress_screen.dart';
import 'map_screen.dart';
import 'workout_session_screen.dart';
import 'login_screen.dart';
import 'weight_tracker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _bg = Color(0xFF1A1A2E);
  static const _surface = Color(0xFF16213E);
  static const _cyan = Color(0xFF00D4FF);

  static const List<String> _weekDays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  // Default weekly calorie goal
  int _weeklyGoal = 2000;
  final _goalController = TextEditingController();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _goalRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('goal')
          .doc('weekly');

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _loadGoal() async {
    try {
      final doc = await _goalRef.get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['weeklyCalorieGoal'] != null) {
          setState(() => _weeklyGoal = data['weeklyCalorieGoal'] as int);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveGoal(int goal) async {
    await _goalRef.set({'weeklyCalorieGoal': goal});
    setState(() => _weeklyGoal = goal);
  }

  void _showGoalDialog() {
    _goalController.text = _weeklyGoal.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set Weekly Calorie Goal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many calories do you want to burn this week?',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _goalController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 2000',
                hintStyle: const TextStyle(color: Colors.white30),
                suffixText: 'kcal',
                suffixStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _cyan),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyan, foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = int.tryParse(_goalController.text.trim());
              if (val != null && val > 0) {
                _saveGoal(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<double> _buildWeeklyCalories(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
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

  int _bestSessionCalories(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['caloriesBurned'] as int? ?? 0;
    }).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
    (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : user?.email?.split('@').first ?? 'Athlete';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: _cyan),
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
            .doc(_uid)
            .collection('workout_logs')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final weeklyCalories = _buildWeeklyCalories(docs);
          final totalCaloriesThisWeek =
          weeklyCalories.reduce((a, b) => a + b).toInt();
          final now = DateTime.now();
          final monday = now.subtract(Duration(days: now.weekday - 1));
          final weekStart = DateTime(monday.year, monday.month, monday.day);
          final workoutsThisWeek = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['date'] as Timestamp?;
            if (ts == null) return false;
            return !ts.toDate().isBefore(weekStart);
          }).length;

          final maxY = weeklyCalories.isEmpty
              ? 700.0
              : (weeklyCalories.reduce((a, b) => a > b ? a : b) * 1.3)
              .clamp(100.0, double.infinity);

          final goalProgress =
          (_weeklyGoal > 0 ? totalCaloriesThisWeek / _weeklyGoal : 0.0)
              .clamp(0.0, 1.0);
          final goalReached = totalCaloriesThisWeek >= _weeklyGoal;
          final bestCal = _bestSessionCalories(docs);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $displayName 👋',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                const Text("Let's crush today's workout!",
                    style: TextStyle(color: Colors.white54, fontSize: 14)),

                const SizedBox(height: 20),

                // ── Summary Cards ──────────────────────────────────────
                Row(children: [
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
                      color: _cyan,
                    ),
                  ),
                ]),

                const SizedBox(height: 12),

                // ── Weekly Goal Progress ───────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: goalReached
                          ? Colors.greenAccent.withValues(alpha: 0.5)
                          : _cyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(
                              goalReached
                                  ? Icons.check_circle_rounded
                                  : Icons.flag_rounded,
                              color: goalReached ? Colors.greenAccent : _cyan,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              goalReached ? 'Weekly Goal Reached! 🎉' : 'Weekly Goal',
                              style: TextStyle(
                                color: goalReached ? Colors.greenAccent : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ]),
                          GestureDetector(
                            onTap: _showGoalDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _cyan.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _cyan.withValues(alpha: 0.3)),
                              ),
                              child: const Text('Edit',
                                  style: TextStyle(
                                      color: _cyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: goalProgress,
                          minHeight: 10,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goalReached ? Colors.greenAccent : _cyan,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalCaloriesThisWeek / $_weeklyGoal kcal  (${(goalProgress * 100).toInt()}%)',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Personal Best ──────────────────────────────────────
                if (bestCal > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.amberAccent.withValues(alpha: 0.35)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Colors.amberAccent, size: 22),
                      const SizedBox(width: 10),
                      const Text('Personal Best:  ',
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                      Text('$bestCal kcal',
                          style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ]),
                  ),

                const SizedBox(height: 16),

                // ── Nav Buttons ────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: _NavButton(
                      label: 'Progress',
                      icon: Icons.show_chart,
                      color: Colors.greenAccent,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ProgressScreen())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NavButton(
                      label: 'Weight',
                      icon: Icons.monitor_weight_outlined,
                      color: Colors.purpleAccent,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const WeightTrackerScreen())),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _NavButton(
                      label: 'Gym Map',
                      icon: Icons.map,
                      color: Colors.orangeAccent,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MapScreen())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NavButton(
                      label: 'Workout',
                      icon: Icons.fitness_center,
                      color: _cyan,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const WorkoutSessionScreen())),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Weekly Calories Chart ──────────────────────────────
                const Text('Weekly Calories Burned',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
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
                    color: _surface, borderRadius: BorderRadius.circular(16),
                  ),
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator(color: _cyan))
                      : BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF0F3460),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem('${rod.toY.toInt()} kcal',
                                const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 36,
                        getTitlesWidget: (value, meta) => Text('${value.toInt()}',
                            style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      )),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _weekDays.length) return const SizedBox();
                          return Text(_weekDays[index],
                              style: const TextStyle(color: Colors.white54, fontSize: 11));
                        },
                      )),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Colors.white10, strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (i) => BarChartGroupData(
                      x: i,
                      barRods: [BarChartRodData(
                        toY: weeklyCalories[i],
                        color: weeklyCalories[i] > 0 ? _cyan : _surface,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      )],
                    )),
                  )),
                ),

                const SizedBox(height: 24),

                // ── Motivational Card ──────────────────────────────────
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
                      Text('💪 Keep Going!',
                          style: TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('"The only bad workout is the one that didn\'t happen."',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
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
  final String label, value;
  final IconData icon;
  final Color color;
  static const _surface = Color(0xFF16213E);

  const _SummaryCard({
    required this.label, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  static const _surface = Color(0xFF16213E);

  const _NavButton({
    required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}