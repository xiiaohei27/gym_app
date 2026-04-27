import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _bg = Color(0xFF1A1A2E);
  static const _surface = Color(0xFF16213E);
  static const _cyan = Color(0xFF00D4FF);
  static const _purple = Color(0xFFCC44FF);
  static const _amber = Color(0xFFFFAA00);

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('workout_logs');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String _formatTime(Timestamp ts) {
    final d = ts.toDate();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          'Progress',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _cyan,
          labelColor: _cyan,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Charts'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _logsRef.orderBy('date', descending: false).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _cyan),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _ChartsTab(docs: docs),
              _HistoryTab(
                docs: docs,
                formatDate: _formatDate,
                formatTime: _formatTime,
                formatDuration: _formatDuration,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Charts Tab ─────────────────────────────────────────────────────────────

class _ChartsTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;

  static const _bg = Color(0xFF1A1A2E);
  static const _surface = Color(0xFF16213E);
  static const _cyan = Color(0xFF00D4FF);
  static const _purple = Color(0xFFCC44FF);

  const _ChartsTab({required this.docs});

  // Group docs by day label (last 7 days with data)
  List<_DayData> _buildWeeklyData() {
    final Map<String, _DayData> map = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['date'] as Timestamp?;
      if (ts == null) continue;
      final d = ts.toDate();
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final label = '${d.day} ${months[d.month - 1]}';

      final existing = map[key] ?? _DayData(label: label, calories: 0, workouts: 0);
      map[key] = _DayData(
        label: label,
        calories: existing.calories + (data['caloriesBurned'] as int? ?? 0),
        workouts: existing.workouts + 1,
      );
    }

    final sorted = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    // Keep last 7 days
    final trimmed = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
    return trimmed.map((e) => e.value).toList();
  }

  int get _totalCalories => docs.fold(0, (sum, doc) {
    final data = doc.data() as Map<String, dynamic>;
    return sum + (data['caloriesBurned'] as int? ?? 0);
  });

  int get _totalWorkouts => docs.length;

  double get _avgCalories =>
      docs.isEmpty ? 0 : _totalCalories / _totalWorkouts;

  @override
  Widget build(BuildContext context) {
    final weekData = _buildWeeklyData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Calories',
                  value: '$_totalCalories',
                  unit: 'kcal',
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Workouts Done',
                  value: '$_totalWorkouts',
                  unit: 'sessions',
                  icon: Icons.fitness_center_rounded,
                  color: _cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            label: 'Avg Calories / Session',
            value: _avgCalories.toStringAsFixed(0),
            unit: 'kcal',
            icon: Icons.bar_chart_rounded,
            color: _purple,
            wide: true,
          ),

          const SizedBox(height: 28),

          // Calories Chart
          const Text(
            'Calories Burned',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Last 7 active days',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),

          if (weekData.isEmpty)
            _EmptyChart(message: 'Complete a workout to see your calories chart!')
          else
            _CaloriesChart(weekData: weekData),

          const SizedBox(height: 28),

          // Workouts Chart
          const Text(
            'Workouts Per Day',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Last 7 active days',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),

          if (weekData.isEmpty)
            _EmptyChart(message: 'Complete a workout to see your sessions chart!')
          else
            _WorkoutsChart(weekData: weekData),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DayData {
  final String label;
  final int calories;
  final int workouts;
  const _DayData({required this.label, required this.calories, required this.workouts});
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool wide;

  static const _surface = Color(0xFF16213E);

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: wide
          ? Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(label,
              style:
              const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: '\n$unit',
                  style:
                  const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;
  static const _surface = Color(0xFF16213E);

  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_rounded,
                color: Colors.white24, size: 40),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaloriesChart extends StatelessWidget {
  final List<_DayData> weekData;
  static const _surface = Color(0xFF16213E);
  static const _cyan = Color(0xFF00D4FF);

  const _CaloriesChart({required this.weekData});

  @override
  Widget build(BuildContext context) {
    final maxVal = weekData.map((d) => d.calories).reduce((a, b) => a > b ? a : b);
    final maxY = ((maxVal / 100).ceil() * 100).toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY == 0 ? 100 : maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F3460),
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style:
                  const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= weekData.length) return const SizedBox();
                  // Shorten label if needed
                  final parts = weekData[i].label.split(' ');
                  final short = parts.isNotEmpty ? parts[0] : weekData[i].label;
                  return Text(
                    short,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
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
          barGroups: List.generate(weekData.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weekData[i].calories.toDouble(),
                  color: _cyan,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _WorkoutsChart extends StatelessWidget {
  final List<_DayData> weekData;
  static const _surface = Color(0xFF16213E);
  static const _purple = Color(0xFFCC44FF);

  const _WorkoutsChart({required this.weekData});

  @override
  Widget build(BuildContext context) {
    final spots = weekData
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.workouts.toDouble()))
        .toList();

    final maxVal = weekData.map((d) => d.workouts).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxVal + 1).toDouble(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F3460),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                '${s.y.toInt()} sessions',
                const TextStyle(color: Colors.white, fontSize: 12),
              ))
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= weekData.length) return const SizedBox();
                  final parts = weekData[i].label.split(' ');
                  final short = parts.isNotEmpty ? parts[0] : weekData[i].label;
                  return Text(
                    short,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
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
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _purple,
              barWidth: 3,
              dotData: FlDotData(
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: _purple,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _purple.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Tab ────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String Function(Timestamp) formatDate;
  final String Function(Timestamp) formatTime;
  final String Function(int) formatDuration;

  static const _surface = Color(0xFF16213E);
  static const _cyan = Color(0xFF00D4FF);

  const _HistoryTab({
    required this.docs,
    required this.formatDate,
    required this.formatTime,
    required this.formatDuration,
  });

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'strength': return const Color(0xFF00D4FF);
      case 'cardio': return Colors.orangeAccent;
      case 'hit': return Colors.redAccent;
      case 'flexibility': return Colors.greenAccent;
      default: return const Color(0xFFCC44FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, color: Colors.white24, size: 56),
            SizedBox(height: 16),
            Text(
              'No workout history yet.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Complete a workout session to see it here.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Show newest first
    final reversed = docs.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final data = reversed[index].data() as Map<String, dynamic>;
        final ts = data['date'] as Timestamp?;
        final name = data['workoutName'] as String? ?? 'Workout';
        final category = data['category'] as String? ?? 'General';
        final calories = data['caloriesBurned'] as int? ?? 0;
        final totalSeconds = data['totalSeconds'] as int? ?? 0;
        final rounds = data['rounds'] as int? ?? 1;
        final color = _categoryColor(category);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.fitness_center_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(label: category, color: color),
                        const SizedBox(width: 6),
                        _Chip(
                          label: '$rounds ${rounds == 1 ? "round" : "rounds"}',
                          color: Colors.white38,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          formatDuration(totalSeconds),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.local_fire_department_rounded,
                            size: 12, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        Text(
                          '$calories kcal',
                          style: const TextStyle(
                              color: Colors.orangeAccent, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Date
              if (ts != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDate(ts),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatTime(ts),
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}