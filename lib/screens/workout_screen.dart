import 'package:flutter/material.dart';
import 'models/workout.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<Workout> workouts = [];
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void addWorkout() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      workouts.add(Workout(name: controller.text.trim(), duration: 30));
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Workouts")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: "Workout name"),
            ),
          ),
          ElevatedButton(onPressed: addWorkout, child: Text("Add")),
          Expanded(
            child: ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(workouts[i].name),
                subtitle: Text("${workouts[i].duration} mins"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}