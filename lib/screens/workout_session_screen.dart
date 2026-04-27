import 'dart:async';
import 'package:flutter/material.dart';

class SavedWorkout {
  final String name;
  final int workoutSeconds;
  final int restSeconds;
  final int rounds;
  final String category;

  SavedWorkout({
    required this.name,
    required this.workoutSeconds,
    required this.restSeconds,
    required this.rounds,
    required this.category,
  });
}

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  Timer? _timer;

  final nameController = TextEditingController();
  final workoutController = TextEditingController();
  final restController = TextEditingController();
  final roundsController = TextEditingController();

  String selectedCategory = "Strength";

  final List<String> categories = [
    "Strength",
    "Cardio",
    "Core",
    "HIIT",
    "Stretching",
  ];

  final List<SavedWorkout> savedWorkouts = [];

  SavedWorkout? selectedWorkout;

  int currentRound = 1;
  int remainingSeconds = 0;
  bool isRunning = false;
  bool isResting = false;
  bool isFinished = false;

  final List<String> sessionLog = [];

  @override
  void dispose() {
    _timer?.cancel();
    nameController.dispose();
    workoutController.dispose();
    restController.dispose();
    roundsController.dispose();
    super.dispose();
  }

  void saveWorkout() {
    final name = nameController.text.trim();
    final workoutSeconds = int.tryParse(workoutController.text) ?? 0;
    final restSeconds = int.tryParse(restController.text) ?? 0;
    final rounds = int.tryParse(roundsController.text) ?? 0;

    if (name.isEmpty || workoutSeconds <= 0 || restSeconds < 0 || rounds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid workout details")),
      );
      return;
    }

    final workout = SavedWorkout(
      name: name,
      workoutSeconds: workoutSeconds,
      restSeconds: restSeconds,
      rounds: rounds,
      category: selectedCategory,
    );

    setState(() {
      savedWorkouts.add(workout);
      selectedWorkout = workout;
      currentRound = 1;
      remainingSeconds = workout.workoutSeconds;
      isRunning = false;
      isResting = false;
      isFinished = false;
      sessionLog.clear();

      nameController.clear();
      workoutController.clear();
      restController.clear();
      roundsController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Workout saved successfully")),
    );
  }

  void selectWorkout(SavedWorkout workout) {
    _timer?.cancel();

    setState(() {
      selectedWorkout = workout;
      currentRound = 1;
      remainingSeconds = workout.workoutSeconds;
      isRunning = false;
      isResting = false;
      isFinished = false;
      sessionLog.clear();
    });
  }

  void deleteWorkout(int index) {
    setState(() {
      if (savedWorkouts[index] == selectedWorkout) {
        selectedWorkout = null;
        remainingSeconds = 0;
        currentRound = 1;
        sessionLog.clear();
      }

      savedWorkouts.removeAt(index);
    });
  }

  void startTimer() {
    if (selectedWorkout == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please save or select a workout first")),
      );
      return;
    }

    if (isRunning || isFinished) return;

    setState(() {
      isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        nextStage();
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
      remainingSeconds = selectedWorkout?.workoutSeconds ?? 0;
      isRunning = false;
      isResting = false;
      isFinished = false;
      sessionLog.clear();
    });
  }

  void nextStage() {
    if (selectedWorkout == null) return;

    if (!isResting) {
      sessionLog.add("Round $currentRound workout completed");

      setState(() {
        isResting = true;
        remainingSeconds = selectedWorkout!.restSeconds;
      });
    } else {
      sessionLog.add("Round $currentRound rest completed");

      if (currentRound >= selectedWorkout!.rounds) {
        finishWorkout();
      } else {
        setState(() {
          currentRound++;
          isResting = false;
          remainingSeconds = selectedWorkout!.workoutSeconds;
        });
      }
    }
  }

  void finishWorkout() {
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

  String formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;

    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  double get progress {
    if (selectedWorkout == null) return 0;

    final total = isResting
        ? selectedWorkout!.restSeconds
        : selectedWorkout!.workoutSeconds;

    if (total == 0) return 0;

    return 1 - (remainingSeconds / total);
  }

  IconData getCategoryIcon(String category) {
    switch (category) {
      case "Cardio":
        return Icons.directions_run;
      case "Core":
        return Icons.self_improvement;
      case "HIIT":
        return Icons.flash_on;
      case "Stretching":
        return Icons.accessibility_new;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stageText = selectedWorkout == null
        ? "No Workout Selected"
        : isFinished
        ? "Finished"
        : isResting
        ? "Rest Time"
        : "Workout Time";

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text(
          "Workout Session",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF16213E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _timerCard(stageText),
            const SizedBox(height: 16),
            _controlButtons(),
            const SizedBox(height: 20),
            _createWorkoutCard(),
            const SizedBox(height: 20),
            _savedWorkoutSection(),
            const SizedBox(height: 20),
            _sessionLogSection(),
          ],
        ),
      ),
    );
  }

  Widget _timerCard(String stageText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F3460),
            Color(0xFF16213E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            selectedWorkout == null
                ? Icons.fitness_center
                : getCategoryIcon(selectedWorkout!.category),
            color: const Color(0xFF00D4FF),
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            selectedWorkout?.name ?? "Create or Select Workout",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stageText,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            formatTime(remainingSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 58,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00D4FF)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            selectedWorkout == null
                ? "Round 0 / 0"
                : "Round $currentRound / ${selectedWorkout!.rounds}",
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _controlButtons() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: "Start",
            icon: Icons.play_arrow,
            color: Colors.greenAccent,
            onTap: startTimer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: "Pause",
            icon: Icons.pause,
            color: Colors.orangeAccent,
            onTap: pauseTimer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: "Reset",
            icon: Icons.refresh,
            color: Colors.redAccent,
            onTap: resetTimer,
          ),
        ),
      ],
    );
  }

  Widget _createWorkoutCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Create Workout",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _InputField(
            controller: nameController,
            label: "Workout Name",
            icon: Icons.edit,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedCategory,
            dropdownColor: const Color(0xFF16213E),
            decoration: _inputDecoration("Category", Icons.category),
            style: const TextStyle(color: Colors.white),
            items: categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCategory = value!;
              });
            },
          ),
          const SizedBox(height: 10),
          _InputField(
            controller: workoutController,
            label: "Workout Time (seconds)",
            icon: Icons.timer,
            numberOnly: true,
          ),
          const SizedBox(height: 10),
          _InputField(
            controller: restController,
            label: "Rest Time (seconds)",
            icon: Icons.hourglass_bottom,
            numberOnly: true,
          ),
          const SizedBox(height: 10),
          _InputField(
            controller: roundsController,
            label: "Rounds",
            icon: Icons.repeat,
            numberOnly: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saveWorkout,
              icon: const Icon(Icons.save),
              label: const Text("Save Workout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedWorkoutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Saved Workouts",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        savedWorkouts.isEmpty
            ? const Text(
          "No saved workouts yet",
          style: TextStyle(color: Colors.white54),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: savedWorkouts.length,
          itemBuilder: (context, index) {
            final workout = savedWorkouts[index];

            return Card(
              color: selectedWorkout == workout
                  ? const Color(0xFF0F3460)
                  : const Color(0xFF16213E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                onTap: () => selectWorkout(workout),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF00D4FF),
                  child: Icon(
                    getCategoryIcon(workout.category),
                    color: Colors.black,
                  ),
                ),
                title: Text(
                  workout.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "${workout.category} • ${workout.workoutSeconds}s workout • ${workout.restSeconds}s rest • ${workout.rounds} rounds",
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => deleteWorkout(index),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _sessionLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Session Log",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        sessionLog.isEmpty
            ? const Text(
          "No activity yet",
          style: TextStyle(color: Colors.white54),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sessionLog.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
              ),
              title: Text(
                sessionLog[index],
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Color(0xFF00D4FF)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF00D4FF)),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool numberOnly;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.numberOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: numberOnly ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFF00D4FF)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00D4FF)),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}