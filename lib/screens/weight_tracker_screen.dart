import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class WeightTrackerScreen extends StatefulWidget {
  const WeightTrackerScreen({super.key});

  @override
  State<WeightTrackerScreen> createState() => _WeightTrackerScreenState();
}

class _WeightTrackerScreenState extends State<WeightTrackerScreen> {
  static const _bg = Color(0xFF1A1A2E);
  static const _surface = Color(0xFF16213E);
  static const _cyan = Color(0xFF00D4FF);
  static const _green = Colors.greenAccent;

  final _weightController = TextEditingController();
  bool _isSaving = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _weightRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('weight_logs');

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatShort(Timestamp ts) {
    final d = ts.toDate();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Future<void> _addWeight() async {
    final text = _weightController.text.trim();
    final weight = double.tryParse(text);
    if (weight == null || weight <= 0 || weight > 300) {
      _showSnack('Please enter a valid weight (1–300 kg)');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _weightRef.add({
        'weight': weight,
        'date': FieldValue.serverTimestamp(),
      });
      _weightController.clear();
      _showSnack('Weight logged! ✅');
    } catch (e) {
      _showSnack('Failed to save. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteWeight(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Entry',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Remove this weight entry?',
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _weightRef.doc(docId).delete();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          'Weight Tracker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _weightRef.orderBy('date', descending: false).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _cyan));
          }

          final docs = snapshot.data?.docs ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Log Weight Card ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log Today\'s Weight',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _weightController,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'e.g. 70.5',
                                hintStyle:
                                const TextStyle(color: Colors.white30),
                                suffixText: 'kg',
                                suffixStyle:
                                const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF1A1A2E),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                  const BorderSide(color: _cyan),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _cyan,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isSaving ? null : _addWeight,
                              child: _isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.black, strokeWidth: 2),
                              )
                                  : const Text('Log',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Stats Row ────────────────────────────────────────────
                if (docs.isNotEmpty) ...[
                  _buildStatsRow(docs),
                  const SizedBox(height: 20),

                  // ── Chart ────────────────────────────────────────────
                  const Text(
                    'Weight Over Time',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildChart(docs),
                  const SizedBox(height: 24),
                ],

                // ── History List ─────────────────────────────────────────
                const Text(
                  'History',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (docs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.monitor_weight_outlined,
                            color: Colors.white24, size: 48),
                        SizedBox(height: 12),
                        Text('No weight entries yet.',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Log your first weight above!',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 13)),
                      ],
                    ),
                  )
                else
                // Show newest first
                  ...docs.reversed.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final weight =
                        (data['weight'] as num?)?.toDouble() ?? 0.0;
                    final ts = data['date'] as Timestamp?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.greenAccent
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Icon(
                                Icons.monitor_weight_outlined,
                                color: Colors.greenAccent,
                                size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${weight.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                if (ts != null)
                                  Text(
                                    _formatDate(ts),
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteWeight(doc.id),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 20),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(List<QueryDocumentSnapshot> docs) {
    final weights = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['weight'] as num?)?.toDouble() ?? 0.0;
    }).toList();

    final latest = weights.last;
    final lowest = weights.reduce((a, b) => a < b ? a : b);
    final highest = weights.reduce((a, b) => a > b ? a : b);
    final change = weights.length > 1 ? latest - weights.first : 0.0;

    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Current',
            value: '${latest.toStringAsFixed(1)} kg',
            color: _cyan,
            icon: Icons.monitor_weight_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            label: 'Lowest',
            value: '${lowest.toStringAsFixed(1)} kg',
            color: Colors.greenAccent,
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStatCard(
            label: 'Change',
            value: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
            color: change <= 0 ? Colors.greenAccent : Colors.orangeAccent,
            icon: change <= 0
                ? Icons.trending_down_rounded
                : Icons.trending_up_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildChart(List<QueryDocumentSnapshot> docs) {
    // Take last 10 entries for the chart
    final recent = docs.length > 10 ? docs.sublist(docs.length - 10) : docs;

    final spots = recent.asMap().entries.map((e) {
      final data = e.value.data() as Map<String, dynamic>;
      final weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(e.key.toDouble(), weight);
    }).toList();

    final weights = recent.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['weight'] as num?)?.toDouble() ?? 0.0;
    }).toList();

    final minY = (weights.reduce((a, b) => a < b ? a : b) - 2)
        .clamp(0.0, double.infinity);
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 2;

    final labels = recent.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['date'] as Timestamp?;
      return ts != null ? _formatShort(ts) : '';
    }).toList();

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F3460),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                '${s.y.toStringAsFixed(1)} kg',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ))
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
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
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  // Only show every other label to avoid crowding
                  if (labels.length > 5 && i % 2 != 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels[i],
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            getDrawingHorizontalLine: (_) =>
            const FlLine(color: Colors.white10, strokeWidth: 1),
            getDrawingVerticalLine: (_) =>
            const FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.greenAccent,
              barWidth: 3,
              dotData: FlDotData(
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 5,
                      color: Colors.greenAccent,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.greenAccent.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  static const _surface = Color(0xFF16213E);

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(label,
              style:
              const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}