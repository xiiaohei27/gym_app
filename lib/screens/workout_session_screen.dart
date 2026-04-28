import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class WorkoutExercise {
  final String name;
  final int workSeconds, restSeconds;
  const WorkoutExercise({required this.name, required this.workSeconds, required this.restSeconds});

  Map<String, dynamic> toMap() => {'name': name, 'workSeconds': workSeconds, 'restSeconds': restSeconds};

  factory WorkoutExercise.fromMap(Map<String, dynamic> m) =>
      WorkoutExercise(name: m['name'] ?? '', workSeconds: m['workSeconds'] ?? 30, restSeconds: m['restSeconds'] ?? 10);
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

// ── Alarm Sound ───────────────────────────────────────────────────────────────

enum AlarmSound {
  beep('Beep', Icons.graphic_eq_rounded, 'sounds/beep.mp3'),
  bell('Bell', Icons.notifications_rounded, 'sounds/bell.mp3'),
  buzzer('Buzzer', Icons.volume_up_rounded, 'sounds/buzzer.mp3'),
  chime('Chime', Icons.music_note_rounded, 'sounds/chime.mp3'),
  whistle('Whistle', Icons.sports_rounded, 'sounds/whistle.mp3');

  final String label;
  final IconData icon;
  final String assetPath;
  const AlarmSound(this.label, this.icon, this.assetPath);
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

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _transitioning = false;

  final AudioPlayer _audio = AudioPlayer();
  AlarmSound _alarm = AlarmSound.beep;
  bool _showAlarmPicker = false;

  SavedWorkout? selectedWorkout;
  int currentRound = 1, currentExerciseIndex = 0, remainingSeconds = 0;
  bool isRunning = false, isResting = false, isFinished = false, showCreateWorkout = false;

  final _nameCtrl   = TextEditingController();
  final _roundsCtrl = TextEditingController(text: '3');
  String _category  = 'Strength';
  final List<_ExEntry> _entries = [_ExEntry()];

  late final AnimationController _pulseCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  late final Animation<double> _pulse =
  Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('workouts');

  WorkoutExercise? get _curEx =>
      (selectedWorkout == null || currentExerciseIndex >= selectedWorkout!.exercises.length)
          ? null
          : selectedWorkout!.exercises[currentExerciseIndex];

  Color  get _col   => isFinished ? _T.purple : isResting ? _T.amber : _T.cyan;
  String get _label => isFinished ? 'DONE!'   : isResting ? 'REST'   : 'GO!';

  String get _pillLabel {
    if (!isResting) return _curEx!.name;
    final exs  = selectedWorkout!.exercises;
    final next = currentExerciseIndex + 1;
    if (next < exs.length) return 'Up next: ${exs[next].name}';
    if (currentRound < selectedWorkout!.rounds) {
      return 'Up next: ${exs.first.name}';
    }
    return 'Last rest!';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _nameCtrl.dispose();
    _roundsCtrl.dispose();
    // FIX: stop audio before disposing so it doesn't keep ringing after leaving screen
    _audio.stop();
    _audio.dispose();
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  Future<void> _saveLog() async {
    final w = selectedWorkout;
    if (w == null) return;
    final totalWork = w.exercises.fold(0, (acc, ex) => acc + ex.workSeconds);
    final total     = totalWork * w.rounds;
    await FirebaseFirestore.instance.collection('users').doc(_uid).collection('workout_logs').add({
      'workoutName'    : w.name,
      'category'       : w.category,
      'rounds'         : w.rounds,
      'totalSeconds'   : total,
      'caloriesBurned' : ((total / 60) * 7).round(),
      'date'           : FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveWorkout() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final exs = _entries
        .where((e) => e.nameCtrl.text.trim().isNotEmpty)
        .map((e) => WorkoutExercise(
      name        : e.nameCtrl.text.trim(),
      workSeconds : int.tryParse(e.workCtrl.text) ?? 30,
      restSeconds : int.tryParse(e.restCtrl.text) ?? 10,
    ).toMap())
        .toList();
    if (exs.isEmpty) return;
    await _ref.add({'name': _nameCtrl.text.trim(), 'rounds': int.tryParse(_roundsCtrl.text) ?? 1, 'category': _category, 'exercises': exs});
    _nameCtrl.clear();
    _roundsCtrl.text = '3';
    setState(() {
      for (final e in _entries) {
        e.dispose();
      }
      _entries..clear()..add(_ExEntry());
      showCreateWorkout = false;
    });
  }

  Future<void> _deleteWorkout(SavedWorkout w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Workout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Delete "${w.name}"? This cannot be undone.', style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Delete', style: TextStyle(color: _T.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      await _ref.doc(w.id).delete();
      if (selectedWorkout?.id == w.id) setState(() => selectedWorkout = null);
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _start() {
    if (selectedWorkout == null || isRunning || isFinished) return;
    setState(() => isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remainingSeconds > 1) {
        setState(() => remainingSeconds--);
      } else {
        _timer?.cancel(); _timer = null;
        if (!_transitioning) { _transitioning = true; setState(() => remainingSeconds = 0); _next(); }
      }
    });
  }

  void _pause() { _timer?.cancel(); _timer = null; setState(() => isRunning = false); }

  void _reset() {
    _timer?.cancel(); _timer = null; _transitioning = false;
    // FIX: stop any playing audio when resetting
    _audio.stop();
    setState(() {
      currentRound = 1; currentExerciseIndex = 0;
      remainingSeconds = selectedWorkout!.exercises.first.workSeconds;
      isRunning = false; isResting = false; isFinished = false;
    });
  }

  void _next() {
    _playAlarm();
    final w = selectedWorkout!;
    if (!isResting) {
      setState(() { isResting = true; remainingSeconds = _curEx!.restSeconds; isRunning = false; _transitioning = false; });
      Future.microtask(_start);
    } else {
      final ni = currentExerciseIndex + 1;
      if (ni < w.exercises.length) {
        setState(() { currentExerciseIndex = ni; isResting = false; remainingSeconds = w.exercises[ni].workSeconds; isRunning = false; _transitioning = false; });
        Future.microtask(_start);
      } else if (currentRound < w.rounds) {
        setState(() { currentRound++; currentExerciseIndex = 0; isResting = false; remainingSeconds = w.exercises.first.workSeconds; isRunning = false; _transitioning = false; });
        Future.microtask(_start);
      } else {
        // FIX: removed duplicate _playAlarm() call here — _playAlarm() is already
        // called at the top of _next(), so calling it again caused the alarm to
        // play twice and sometimes linger.
        setState(() { isFinished = true; isRunning = false; _transitioning = false; });
        _saveLog();
      }
    }
  }

  void _selectWorkout(SavedWorkout w) {
    if (w.exercises.isEmpty) { _snack('No stages — create exercises first.'); return; }
    _timer?.cancel(); _timer = null; _transitioning = false;
    // FIX: stop any playing audio when switching workouts
    _audio.stop();
    setState(() {
      selectedWorkout = w; currentRound = 1; currentExerciseIndex = 0;
      remainingSeconds = w.exercises.first.workSeconds;
      isRunning = false; isResting = false; isFinished = false; showCreateWorkout = false;
    });
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  Future<void> _playAlarm() async {
    try {
      // FIX: stop + release before playing to prevent sounds stacking/lingering
      await _audio.stop();
      await _audio.release();
      await _audio.play(AssetSource(_alarm.assetPath));
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
    await HapticFeedback.heavyImpact();
  }

  Future<void> _preview(AlarmSound s) async {
    try {
      // FIX: stop + release before previewing to prevent overlap
      await _audio.stop();
      await _audio.release();
      await _audio.play(AssetSource(s.assetPath));
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
    await HapticFeedback.mediumImpact();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: _T.surface, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _T.bg,
    appBar: _buildAppBar(),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: selectedWorkout == null ? _pickerView() : _sessionView(),
    ),
  );

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _T.bg, elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
      onPressed: () => Navigator.maybePop(context),
    ),
    title: const Text('Workout Session', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    actions: [
      GestureDetector(
        onTap: () => setState(() => _showAlarmPicker = !_showAlarmPicker),
        child: Container(
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: _T.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: _T.amber.withValues(alpha: 0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_alarm.icon, color: _T.amber, size: 14),
            const SizedBox(width: 5),
            Text(_alarm.label, style: const TextStyle(color: _T.amber, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ],
  );

  // ── Alarm Picker ──────────────────────────────────────────────────────────

  Widget _alarmPicker() => AnimatedContainer(
    duration: const Duration(milliseconds: 280), curve: Curves.easeOut,
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _T.amber.withValues(alpha: 0.25), width: 1.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.alarm_rounded, color: _T.amber, size: 14),
        const SizedBox(width: 6),
        const Text('ALARM SOUND', style: TextStyle(color: _T.amber, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const Spacer(),
        GestureDetector(onTap: () => setState(() => _showAlarmPicker = false), child: const Icon(Icons.close_rounded, color: Colors.white30, size: 18)),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: AlarmSound.values.map((s) {
        final sel = _alarm == s;
        return GestureDetector(
          onTap: () { setState(() => _alarm = s); _preview(s); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? _T.amber.withValues(alpha: 0.18) : _T.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? _T.amber : _T.border, width: sel ? 1.5 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(s.icon, color: sel ? _T.amber : Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text(s.label, style: TextStyle(color: sel ? _T.amber : Colors.white60, fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
              if (sel) ...[const SizedBox(width: 5), const Icon(Icons.check_circle_rounded, color: _T.amber, size: 12)],
            ]),
          ),
        );
      }).toList()),
      const SizedBox(height: 6),
      const Text('Tap a sound to preview', style: TextStyle(color: Colors.white24, fontSize: 11)),
    ]),
  );

  // ── Picker View ───────────────────────────────────────────────────────────

  Widget _pickerView() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_showAlarmPicker) _alarmPicker(),
    RichText(text: const TextSpan(children: [
      TextSpan(text: 'Choose your\n', style: TextStyle(color: Colors.white70, fontSize: 22, height: 1.4)),
      TextSpan(text: 'Workout',       style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
    ])),
    const SizedBox(height: 20),
    _workoutList(),
    const SizedBox(height: 16),
    if (!showCreateWorkout)
      _dashedBtn(label: 'Create New Workout', icon: Icons.add_rounded, color: _T.cyan, onTap: () => setState(() => showCreateWorkout = true))
    else
      _createCard(),
  ]);

  Widget _dashedBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5), color: color.withValues(alpha: 0.05)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 18), const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        ),
      );

  // ── Session View ──────────────────────────────────────────────────────────

  Widget _sessionView() => Column(children: [
    if (_showAlarmPicker) _alarmPicker(),
    _stagePill(),
    const SizedBox(height: 14),
    _timerCard(),
    const SizedBox(height: 14),
    _roadmap(),
    const SizedBox(height: 16),
    _controls(),
    const SizedBox(height: 8),
    TextButton.icon(
      onPressed: () {
        _timer?.cancel(); _timer = null;
        // FIX: stop audio when manually changing workout
        _audio.stop();
        setState(() => selectedWorkout = null);
      },
      icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white30, size: 18),
      label: const Text('Change Workout', style: TextStyle(color: Colors.white30, fontSize: 13)),
    ),
  ]);

  Widget _stagePill() => AnimatedContainer(
    duration: const Duration(milliseconds: 350), curve: Curves.easeInOut,
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(color: _col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: _col.withValues(alpha: 0.4), width: 1.5)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(isFinished ? Icons.emoji_events_rounded : isResting ? Icons.self_improvement_rounded : Icons.local_fire_department_rounded, color: _col, size: 18),
      const SizedBox(width: 8),
      Text(_label, style: TextStyle(color: _col, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 3)),
      if (!isFinished && _curEx != null) ...[
        const SizedBox(width: 8),
        Container(width: 1, height: 14, color: _col.withValues(alpha: 0.3)),
        const SizedBox(width: 8),
        Text(_pillLabel, style: TextStyle(color: _col.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    ]),
  );

  Widget _timerCard() => AnimatedContainer(
    duration: const Duration(milliseconds: 350), curve: Curves.easeInOut,
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    decoration: BoxDecoration(
      color: _T.surface, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _col.withValues(alpha: 0.3), width: 1.5),
      boxShadow: [BoxShadow(color: _col.withValues(alpha: 0.10), blurRadius: 30, spreadRadius: 4)],
    ),
    child: Column(children: [
      Text(selectedWorkout!.name, style: const TextStyle(color: Colors.white60, fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      if (_curEx != null && !isFinished)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(isResting ? 'Rest' : _curEx!.name,
              key: ValueKey('${currentExerciseIndex}_$isResting'),
              style: TextStyle(color: _col, fontSize: 24, fontWeight: FontWeight.w800)),
        ),
      const SizedBox(height: 18),
      isRunning ? ScaleTransition(scale: _pulse, child: _digits()) : _digits(),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _pill(Icons.repeat_rounded,   'Round $currentRound/${selectedWorkout!.rounds}',          _T.cyan),
        const SizedBox(width: 10),
        _pill(Icons.list_alt_rounded, 'Ex ${currentExerciseIndex + 1}/${selectedWorkout!.exercises.length}', _T.amber),
      ]),
    ]),
  );

  Widget _digits() => Text(_fmt(remainingSeconds), style: TextStyle(
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

  Widget _roadmap() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _T.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('EXERCISE QUEUE', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      ...List.generate(selectedWorkout!.exercises.length, (i) {
        final ex = selectedWorkout!.exercises[i];
        final done   = i < currentExerciseIndex || isFinished;
        final active = i == currentExerciseIndex && !isFinished;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? _T.purple.withValues(alpha: 0.18) : active ? _col.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: done ? _T.purple : active ? _col : Colors.white24, width: active ? 2 : 1),
              ),
              child: Center(child: done
                  ? const Icon(Icons.check_rounded, size: 15, color: _T.purple)
                  : Text('${i + 1}', style: TextStyle(color: active ? _col : Colors.white38, fontSize: 12, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ex.name, style: TextStyle(
                color: done ? Colors.white30 : active ? Colors.white : Colors.white60,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 14,
                decoration: done ? TextDecoration.lineThrough : null, decorationColor: Colors.white24,
              )),
              const SizedBox(height: 2),
              Text('${ex.workSeconds}s work  ·  ${ex.restSeconds}s rest', style: const TextStyle(color: Colors.white24, fontSize: 11)),
            ])),
            if (active && !isResting)
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _col, boxShadow: [BoxShadow(color: _col.withValues(alpha: 0.55), blurRadius: 6)])),
          ]),
        );
      }),
    ]),
  );

  Widget _controls() => Row(children: [
    Expanded(flex: 2, child: _ctrlBtn(
      label: isRunning ? 'Pause' : isFinished ? 'Done!' : 'Start',
      icon:  isRunning ? Icons.pause_rounded : isFinished ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
      color: isFinished ? _T.purple : _col,
      onTap: isFinished ? () => Navigator.maybePop(context) : isRunning ? _pause : _start,
    )),
    const SizedBox(width: 12),
    Expanded(child: _ctrlBtn(label: 'Reset', icon: Icons.refresh_rounded, color: Colors.white24, textColor: Colors.white60, onTap: _reset, outlined: true)),
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
            Icon(icon, color: textColor ?? Colors.black, size: 20),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: textColor ?? Colors.black, fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
        ),
      );

  // ── Workout List ──────────────────────────────────────────────────────────

  Widget _workoutList() => StreamBuilder<QuerySnapshot>(
    stream: _ref.snapshots(),
    builder: (ctx, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _T.cyan));
      if (!snap.hasData || snap.data!.docs.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _T.border)),
          child: const Center(child: Text('No workouts yet — create one below!', style: TextStyle(color: Colors.white38, fontSize: 13))),
        );
      }
      return Column(children: snap.data!.docs.map(SavedWorkout.fromFirestore).map(_tile).toList());
    },
  );

  Widget _tile(SavedWorkout w) => GestureDetector(
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
        GestureDetector(
          onTap: () => _deleteWorkout(w),
          child: Container(
            margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.all(8),
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

  Widget _createCard() {
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
        _field(_nameCtrl,   'Workout Name', Icons.label_outline_rounded),
        const SizedBox(height: 10),
        _field(_roundsCtrl, 'Rounds',       Icons.repeat_rounded, isNum: true),
        const SizedBox(height: 14),
        const Text('Category', style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: cats.map((c) {
          final sel = _category == c;
          return GestureDetector(
            onTap: () => setState(() => _category = c),
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
        }).toList()),
        const SizedBox(height: 18),
        Row(children: [
          const Text('STAGES', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _entries.add(_ExEntry())),
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
        ..._entries.asMap().entries.map((e) => _exRow(e.key, e.value)),
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

  Widget _exRow(int i, _ExEntry e) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _T.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: _T.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _T.amber.withValues(alpha: 0.15), border: Border.all(color: _T.amber.withValues(alpha: 0.4))),
          child: Center(child: Text('${i + 1}', style: const TextStyle(color: _T.amber, fontSize: 11, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 8),
        const Text('Stage', style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_entries.length > 1)
          GestureDetector(onTap: () => setState(() => _entries.removeAt(i)), child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white24, size: 18)),
      ]),
      const SizedBox(height: 10),
      _field(e.nameCtrl, 'Exercise name (e.g. Push Up)', Icons.accessibility_new_rounded),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _field(e.workCtrl, 'Work (sec)', Icons.timer_rounded, isNum: true)),
        const SizedBox(width: 8),
        Expanded(child: _field(e.restCtrl, 'Rest (sec)', Icons.hourglass_bottom_rounded, isNum: true)),
      ]),
    ]),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {bool isNum = false}) => TextField(
    controller: ctrl,
    keyboardType: isNum ? TextInputType.number : TextInputType.text,
    inputFormatters: isNum ? [FilteringTextInputFormatter.digitsOnly] : null,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white24, size: 16),
      filled: true, fillColor: _T.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _T.cyan, width: 1.2)),
    ),
  );
}

// ── Exercise Form Entry ───────────────────────────────────────────────────────

class _ExEntry {
  final nameCtrl = TextEditingController();
  final workCtrl = TextEditingController(text: '30');
  final restCtrl = TextEditingController(text: '10');
  void dispose() { nameCtrl.dispose(); workCtrl.dispose(); restCtrl.dispose(); }
}