import 'dart:async';
import 'package:flutter/material.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? _timer;

  int workoutSeconds = 45;
  int restSeconds = 15;
  int totalRounds = 3;

  int currentRound = 1;
  int remainingSeconds = 45;
  bool isRunning = false;
  bool isResting = false;
  bool isFinished = false;

  final List<String> sessionLog = [];

  @override
  void initState() {
    super.initState();
    remainingSeconds = workoutSeconds;
  }

  void startTimer() {
    if (isRunning || isFinished) return;

    setState(() {
      isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        _nextStage();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    setState(() {
      isRunning = false;
    });
  }

  void resetTimer() {
    _timer?.cancel();
    setState(() {
      currentRound = 1;
      isResting = false;
      isRunning = false;
      isFinished = false;
      remainingSeconds = workoutSeconds;
      sessionLog.clear();
    });
  }

  void _nextStage() {
    if (!isResting) {
      sessionLog.add("Round $currentRound workout completed");

      setState(() {
        isResting = true;
        remainingSeconds = restSeconds;
      });
    } else {
      sessionLog.add("Round $currentRound rest completed");

      if (currentRound >= totalRounds) {
        _finishWorkout();
      } else {
        setState(() {
          currentRound++;
          isResting = false;
          remainingSeconds = workoutSeconds;
        });
      }
    }
  }

  void _finishWorkout() {
    _timer?.cancel();

    setState(() {
      isRunning = false;
      isFinished = true;
      remainingSeconds = 0;
      sessionLog.add("Workout session finished");
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Workout completed! Great job!")),
    );
  }

  void updateSettings({
    required int workout,
    required int rest,
    required int rounds,
  }) {
    _timer?.cancel();

    setState(() {
      workoutSeconds = workout;
      restSeconds = rest;
      totalRounds = rounds;
      currentRound = 1;
      remainingSeconds = workoutSeconds;
      isResting = false;
      isRunning = false;
      isFinished = false;
      sessionLog.clear();
    });
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  double get progress {
    final total = isResting ? restSeconds : workoutSeconds;
    if (total == 0) return 0;
    return 1 - (remainingSeconds / total);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void openSettingsDialog() {
    final workoutController =
    TextEditingController(text: workoutSeconds.toString());
    final restController = TextEditingController(text: restSeconds.toString());
    final roundsController = TextEditingController(text: totalRounds.toString());

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Timer Settings"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: workoutController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Workout seconds",
                ),
              ),
              TextField(
                controller: restController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Rest seconds",
                ),
              ),
              TextField(
                controller: roundsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Rounds",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final workout = int.tryParse(workoutController.text) ?? 45;
                final rest = int.tryParse(restController.text) ?? 15;
                final rounds = int.tryParse(roundsController.text) ?? 3;

                updateSettings(
                  workout: workout,
                  rest: rest,
                  rounds: rounds,
                );

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final stageText = isFinished
        ? "Finished"
        : isResting
        ? "Rest Time"
        : "Workout Time";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Workout Session"),
        actions: [
          IconButton(
            onPressed: isRunning ? null : openSettingsDialog,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      stageText,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      formatTime(remainingSeconds),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 10,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Round $currentRound / $totalRounds",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: startTimer,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Start"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pauseTimer,
                    icon: const Icon(Icons.pause),
                    label: const Text("Pause"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: resetTimer,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reset"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Session Log",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: sessionLog.isEmpty
                  ? const Center(child: Text("No activity yet"))
                  : ListView.builder(
                itemCount: sessionLog.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(sessionLog[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}