import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class WorkoutExercise {
  final String name;
  final int workSeconds, restSeconds;
  const WorkoutExercise({required this.name, required this.workSeconds, required this.restSeconds});

  Map<String, dynamic> toMap() => {'name': name, 'workSeconds': workSeconds, 'restSeconds': restSeconds};

  factory WorkoutExercise.fromMap(Map<String, dynamic> m) => WorkoutExercise(
      name: m['name'] ?? '', workSeconds: m['workSeconds'] ?? 30, restSeconds: m['restSeconds'] ?? 10);
}

class SavedWorkout {
  final String id, name, category;
  final int rounds;
  final List<WorkoutExercise> exercises;
  const SavedWorkout({required this.id, required this.name, required this.rounds, required this.category, required this.exercises});

  factory SavedWorkout.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawEx = d['exercises'] as List<dynamic>?;
    final exercises = rawEx != null && rawEx.isNotEmpty
        ? rawEx.map((e) => WorkoutExercise.fromMap(e as Map<String, dynamic>)).toList()
        : d.containsKey('workoutSeconds')
        ? [WorkoutExercise(name: d['name'] ?? 'Workout', workSeconds: d['workoutSeconds'] ?? 30, restSeconds: d['restSeconds'] ?? 10)]
        : <WorkoutExercise>[];
    return SavedWorkout(id: doc.id, name: d['name'] ?? '', rounds: d['rounds'] ?? 1, category: d['category'] ?? 'General', exercises: exercises);
  }
}

// ── Theme ─────────────────────────────────────────────────────────────────────

class _T {
  static const bg         = Color(0xFF0F1923);
  static const surface    = Color(0xFF162032);
  static const surfaceAlt = Color(0xFF1C2A3A);
  static const cyan       = Color(0xFF00D9FF);
  static const amber      = Color(0xFFFFAA00);
  static const purple     = Color(0xFFCC44FF);
  static const red        = Color(0xFFFF4466);
  static const border     = Color(0xFF233040);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key});
  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen>
    with SingleTickerProviderStateMixin {

  Timer? _timer;
  bool _transitioning = false;

  SavedWorkout? selectedWorkout;
  int currentRound = 1, currentExerciseIndex = 0, remainingSeconds = 0;
  bool isRunning = false, isResting = false, isFinished = false, showCreateWorkout = false;

  final _nameCtrl   = TextEditingController();
  final _roundsCtrl = TextEditingController(text: '3');
  String _selectedCategory = 'Strength';
  final List<_ExerciseFormEntry> _exerciseEntries = [_ExerciseFormEntry()];

  late final AnimationController _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  late final Animation<double> _pulse = Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get _workoutRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('workouts');

  WorkoutExercise? get _currentExercise {
    if (selectedWorkout == null || currentExerciseIndex >= selectedWorkout!.exercises.length) return null;
    return selectedWorkout!.exercises[currentExerciseIndex];
  }

  Color get _stageColor => isFinished ? _T.purple : isResting ? _T.amber : _T.cyan;
  String get _stageLabel => isFinished ? 'DONE!' : isResting ? 'REST' : 'GO!';

  // During work: current exercise name.
  // During rest: the NEXT exercise name, or "Last rest!" if none remains.
  String get _pillLabel {
    if (!isResting) return _currentExercise!.name;
    final exercises = selectedWorkout!.exercises;
    final nextIdx = currentExerciseIndex + 1;
    if (nextIdx < exercises.length) return 'Up next: ${exercises[nextIdx].name}';
    if (currentRound < selectedWorkout!.rounds) return 'Up next: ${exercises.first.name}';
    return 'Last rest!';
  }

  @override
  void dispose() {
    _timer?.cancel(); _pulseCtrl.dispose();
    _nameCtrl.dispose(); _roundsCtrl.dispose();
    for (final e in _exerciseEntries) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _saveWorkoutLog() async {
    final w = selectedWorkout;
    if (w == null) return;

    // Total work seconds across all exercises x rounds
    final totalWorkSeconds = w.exercises
        .fold(0, (sum, ex) => sum + ex.workSeconds);
    final totalSeconds = totalWorkSeconds * w.rounds;

    // ~7 kcal per minute of work
    final caloriesBurned = ((totalSeconds / 60) * 7).round();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('workout_logs')
        .add({
      'workoutName': w.name,
      'category': w.category,
      'rounds': w.rounds,
      'totalSeconds': totalSeconds,
      'caloriesBurned': caloriesBurned,
      'date': FieldValue.serverTimestamp(),
    });
  }

  // ── Timer Logic ───────────────────────────────────────────────────────────

  void _startTimer() {
    if (selectedWorkout == null || isRunning || isFinished) return;
    setState(() => isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remainingSeconds > 1) {
        setState(() => remainingSeconds--);
      } else {
        _timer?.cancel(); _timer = null;
        if (!_transitioning) { _transitioning = true; setState(() => remainingSeconds = 0); _nextStage(); }
      }
    });
  }

  void _pauseTimer() { _timer?.cancel(); _timer = null; setState(() => isRunning = false); }

  void _resetTimer() {
    _timer?.cancel(); _timer = null; _transitioning = false;
    setState(() {
      currentRound = 1; currentExerciseIndex = 0;
      remainingSeconds = selectedWorkout!.exercises.first.workSeconds;
      isRunning = false; isResting = false; isFinished = false;
    });
  }

  void _nextStage() {
    _playAlarm();
    final w = selectedWorkout!;
    if (!isResting) {
      setState(() { isResting = true; remainingSeconds = _currentExercise!.restSeconds; isRunning = false; _transitioning = false; });
      Future.microtask(_startTimer);
    } else {
      final nextIdx = currentExerciseIndex + 1;
      if (nextIdx < w.exercises.length) {
        setState(() { currentExerciseIndex = nextIdx; isResting = false; remainingSeconds = w.exercises[nextIdx].workSeconds; isRunning = false; _transitioning = false; });
        Future.microtask(_startTimer);
      } else if (currentRound < w.rounds) {
        setState(() { currentRound++; currentExerciseIndex = 0; isResting = false; remainingSeconds = w.exercises.first.workSeconds; isRunning = false; _transitioning = false; });
        Future.microtask(_startTimer);
      } else {
        _finishWorkout();
      }
    }
  }

  void _finishWorkout() {
    _playAlarm();
    setState(() { isFinished = true; isRunning = false; _transitioning = false; });
    _saveWorkoutLog();
  }

  Future<void> _playAlarm() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
  }

  void _selectWorkout(SavedWorkout w) {
    if (w.exercises.isEmpty) {
      _showSnack("This workout has no stages — tap Create to add exercises.");
      return;
    }
    _timer?.cancel(); _timer = null; _transitioning = false;
    setState(() {
      selectedWorkout = w; currentRound = 1; currentExerciseIndex = 0;
      remainingSeconds = w.exercises.first.workSeconds;
      isRunning = false; isResting = false; isFinished = false; showCreateWorkout = false;
    });
  }

  Future<void> _saveWorkout() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final exercises = _exerciseEntries
        .where((e) => e.nameCtrl.text.trim().isNotEmpty)
        .map((e) => WorkoutExercise(
      name: e.nameCtrl.text.trim(),
      workSeconds: int.tryParse(e.workCtrl.text) ?? 30,
      restSeconds: int.tryParse(e.restCtrl.text) ?? 10,
    ).toMap())
        .toList();
    if (exercises.isEmpty) return;
    await _workoutRef.add({'name': _nameCtrl.text.trim(), 'rounds': int.tryParse(_roundsCtrl.text) ?? 1, 'category': _selectedCategory, 'exercises': exercises});
    _nameCtrl.clear(); _roundsCtrl.text = '3';
    setState(() {
      for (final e in _exerciseEntries) {
        e.dispose();
      }
      _exerciseEntries..clear()..add(_ExerciseFormEntry());
      showCreateWorkout = false;
    });
  }

  Future<void> _deleteWorkout(SavedWorkout w) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Workout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Delete "${w.name}"? This cannot be undone.', style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: _T.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _workoutRef.doc(w.id).delete();
      if (selectedWorkout?.id == w.id) setState(() => selectedWorkout = null);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: _T.surface, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _T.bg,
    appBar: _appBar(),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: selectedWorkout == null ? _pickerView() : _sessionView(),
    ),
  );

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: _T.bg, elevation: 0,
    leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18), onPressed: () => Navigator.maybePop(context)),
    title: const Text('Workout Session', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: _T.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: _T.purple.withValues(alpha: 0.3))),
        child: const Icon(Icons.fitness_center_rounded, color: _T.purple, size: 16),
      ),
    ],
  );

  // ── Picker View ───────────────────────────────────────────────────────────

  Widget _pickerView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(text: const TextSpan(children: [
        TextSpan(text: 'Choose your\n', style: TextStyle(color: Colors.white70, fontSize: 22, height: 1.4)),
        TextSpan(text: 'Workout', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
      ])),
      const SizedBox(height: 20),
      _savedWorkoutSection(),
      const SizedBox(height: 16),
      if (!showCreateWorkout)
        _dashedButton(label: 'Create New Workout', icon: Icons.add_rounded, color: _T.cyan, onTap: () => setState(() => showCreateWorkout = true))
      else
        _createWorkoutCard(),
    ],
  );

  Widget _dashedButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5), color: color.withValues(alpha: 0.05)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 18), const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        ),
      );

  // ── Session View ──────────────────────────────────────────────────────────

  Widget _sessionView() => Column(
    children: [
      _stagePill(), const SizedBox(height: 14),
      _timerCard(),   const SizedBox(height: 14),
      _exerciseRoadmap(), const SizedBox(height: 16),
      _controls(),    const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () { _timer?.cancel(); _timer = null; setState(() => selectedWorkout = null); },
        icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white30, size: 18),
        label: const Text('Change Workout', style: TextStyle(color: Colors.white30, fontSize: 13)),
      ),
    ],
  );

  Widget _stagePill() => AnimatedContainer(
    duration: const Duration(milliseconds: 350), curve: Curves.easeInOut,
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(color: _stageColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: _stageColor.withValues(alpha: 0.4), width: 1.5)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(isFinished ? Icons.emoji_events_rounded : isResting ? Icons.self_improvement_rounded : Icons.local_fire_department_rounded, color: _stageColor, size: 18),
      const SizedBox(width: 8),
      Text(_stageLabel, style: TextStyle(color: _stageColor, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 3)),
      if (!isFinished && _currentExercise != null) ...[
        const SizedBox(width: 8), Container(width: 1, height: 14, color: _stageColor.withValues(alpha: 0.3)), const SizedBox(width: 8),
        Text(_pillLabel, style: TextStyle(color: _stageColor.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    ]),
  );

  Widget _timerCard() => AnimatedContainer(
    duration: const Duration(milliseconds: 350), curve: Curves.easeInOut,
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    decoration: BoxDecoration(
      color: _T.surface, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _stageColor.withValues(alpha: 0.3), width: 1.5),
      boxShadow: [BoxShadow(color: _stageColor.withValues(alpha: 0.10), blurRadius: 30, spreadRadius: 4)],
    ),
    child: Column(children: [
      Text(selectedWorkout!.name, style: const TextStyle(color: Colors.white60, fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      if (_currentExercise != null && !isFinished)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(isResting ? 'Rest' : _currentExercise!.name,
              key: ValueKey('${currentExerciseIndex}_$isResting'),
              style: TextStyle(color: _stageColor, fontSize: 24, fontWeight: FontWeight.w800)),
        ),
      const SizedBox(height: 18),
      isRunning ? ScaleTransition(scale: _pulse, child: _timerDigits()) : _timerDigits(),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _pill(Icons.repeat_rounded, 'Round $currentRound/${selectedWorkout!.rounds}', _T.cyan),
        const SizedBox(width: 10),
        _pill(Icons.list_alt_rounded, 'Ex ${currentExerciseIndex + 1}/${selectedWorkout!.exercises.length}', _T.amber),
      ]),
    ]),
  );

  Widget _timerDigits() => Text(_fmt(remainingSeconds), style: TextStyle(
    fontSize: 80, fontWeight: FontWeight.w900,
    color: isFinished ? _T.purple : Colors.white,
    letterSpacing: -4, fontFeatures: const [FontFeature.tabularFigures()], height: 1,
  ));

  Widget _pill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color), const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _exerciseRoadmap() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _T.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('EXERCISE QUEUE', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      ...List.generate(selectedWorkout!.exercises.length, (i) {
        final ex = selectedWorkout!.exercises[i];
        final isDone   = i < currentExerciseIndex || isFinished;
        final isActive = i == currentExerciseIndex && !isFinished;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? _T.purple.withValues(alpha: 0.18) : isActive ? _stageColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: isDone ? _T.purple : isActive ? _stageColor : Colors.white24, width: isActive ? 2 : 1),
              ),
              child: Center(child: isDone
                  ? const Icon(Icons.check_rounded, size: 15, color: _T.purple)
                  : Text('${i + 1}', style: TextStyle(color: isActive ? _stageColor : Colors.white38, fontSize: 12, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ex.name, style: TextStyle(
                color: isDone ? Colors.white30 : isActive ? Colors.white : Colors.white60,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, fontSize: 14,
                decoration: isDone ? TextDecoration.lineThrough : null, decorationColor: Colors.white24,
              )),
              const SizedBox(height: 2),
              Text('${ex.workSeconds}s work  ·  ${ex.restSeconds}s rest', style: const TextStyle(color: Colors.white24, fontSize: 11)),
            ])),
            if (isActive && !isResting)
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _stageColor, boxShadow: [BoxShadow(color: _stageColor.withValues(alpha: 0.55), blurRadius: 6)])),
          ]),
        );
      }),
    ]),
  );

  Widget _controls() => Row(children: [
    Expanded(flex: 2, child: _ctrlBtn(
      label: isRunning ? 'Pause' : isFinished ? 'Done!' : 'Start',
      icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
      color: isFinished ? _T.purple : _stageColor,
      onTap: isFinished ? null : isRunning ? _pauseTimer : _startTimer,
    )),
    const SizedBox(width: 12),
    Expanded(child: _ctrlBtn(label: 'Reset', icon: Icons.refresh_rounded, color: Colors.white24, textColor: Colors.white60, onTap: _resetTimer, outlined: true)),
  ]);

  Widget _ctrlBtn({required String label, required IconData icon, required Color color, Color? textColor, VoidCallback? onTap, bool outlined = false}) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: outlined ? Border.all(color: color) : null,
            boxShadow: outlined ? null : [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: textColor ?? Colors.black, size: 20), const SizedBox(width: 6),
            Text(label, style: TextStyle(color: textColor ?? Colors.black, fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
        ),
      );

  // ── Saved Workout Section ─────────────────────────────────────────────────

  Widget _savedWorkoutSection() => StreamBuilder<QuerySnapshot>(
    stream: _workoutRef.snapshots(),
    builder: (ctx, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _T.cyan));
      if (!snap.hasData || snap.data!.docs.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _T.border)),
          child: const Center(child: Text('No workouts yet — create one below!', style: TextStyle(color: Colors.white38, fontSize: 13))),
        );
      }
      return Column(children: snap.data!.docs.map(SavedWorkout.fromFirestore).map(_workoutTile).toList());
    },
  );

  Widget _workoutTile(SavedWorkout w) => GestureDetector(
    onTap: () => _selectWorkout(w),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _T.border)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _T.cyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _T.cyan.withValues(alpha: 0.25))),
          child: const Icon(Icons.fitness_center_rounded, color: _T.cyan, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(w.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 3),
          Text('${w.exercises.length} ${w.exercises.length == 1 ? "stage" : "stages"} · ${w.rounds} ${w.rounds == 1 ? "round" : "rounds"} · ${w.category}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ])),
        // ── Delete button ──────────────────────────────────────────────
        GestureDetector(
          onTap: () => _deleteWorkout(w),
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _T.red.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: _T.red.withValues(alpha: 0.25))),
            child: const Icon(Icons.delete_outline_rounded, color: _T.red, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
      ]),
    ),
  );

  // ── Create Workout Form ───────────────────────────────────────────────────

  Widget _createWorkoutCard() {
    const cats = ['Strength', 'Cardio', 'HIT', 'Flexibility', 'Mixed'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _T.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('NEW WORKOUT', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(onTap: () => setState(() => showCreateWorkout = false), child: const Icon(Icons.close_rounded, color: Colors.white30, size: 20)),
        ]),
        const SizedBox(height: 14),
        _formField(_nameCtrl, 'Workout Name', Icons.label_outline_rounded),
        const SizedBox(height: 10),
        _formField(_roundsCtrl, 'Rounds', Icons.repeat_rounded, isNum: true),
        const SizedBox(height: 14),
        const Text('Category', style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 6,
          children: cats.map((c) {
            final sel = _selectedCategory == c;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _T.cyan.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _T.cyan : Colors.transparent),
                ),
                child: Text(c, style: TextStyle(color: sel ? _T.cyan : Colors.white60, fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Row(children: [
          const Text('STAGES', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _exerciseEntries.add(_ExerciseFormEntry())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _T.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: _T.amber.withValues(alpha: 0.3))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: _T.amber, size: 14), SizedBox(width: 4),
                Text('Add Stage', style: TextStyle(color: _T.amber, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ..._exerciseEntries.asMap().entries.map((e) => _exerciseFormRow(e.key, e.value)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _saveWorkout,
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_T.cyan, _T.cyan.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _T.cyan.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Center(child: Text('Save Workout', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15))),
          ),
        ),
      ]),
    );
  }

  Widget _exerciseFormRow(int index, _ExerciseFormEntry e) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _T.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: _T.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _T.amber.withValues(alpha: 0.15), border: Border.all(color: _T.amber.withValues(alpha: 0.4))),
          child: Center(child: Text('${index + 1}', style: const TextStyle(color: _T.amber, fontSize: 11, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 8),
        const Text('Stage', style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_exerciseEntries.length > 1)
          GestureDetector(onTap: () => setState(() => _exerciseEntries.removeAt(index)), child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white24, size: 18)),
      ]),
      const SizedBox(height: 10),
      _formField(e.nameCtrl, 'Exercise name (e.g. Push Up)', Icons.accessibility_new_rounded),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _formField(e.workCtrl, 'Work (sec)', Icons.timer_rounded, isNum: true)),
        const SizedBox(width: 8),
        Expanded(child: _formField(e.restCtrl, 'Rest (sec)', Icons.hourglass_bottom_rounded, isNum: true)),
      ]),
    ]),
  );

  Widget _formField(TextEditingController ctrl, String hint, IconData icon, {bool isNum = false}) => TextField(
    controller: ctrl,
    keyboardType: isNum ? TextInputType.number : TextInputType.text,
    inputFormatters: isNum ? [FilteringTextInputFormatter.digitsOnly] : null,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white24, size: 16),
      filled: true, fillColor: _T.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _T.cyan, width: 1.2)),
    ),
  );
}

// ── Exercise Form Entry ───────────────────────────────────────────────────────

class _ExerciseFormEntry {
  final nameCtrl = TextEditingController();
  final workCtrl = TextEditingController(text: '30');
  final restCtrl = TextEditingController(text: '10');

  void dispose() { nameCtrl.dispose(); workCtrl.dispose(); restCtrl.dispose(); }
}

