import 'package:flutter/material.dart';
import 'workout_screen.dart';
import 'progress_screen.dart';
import 'map_screen.dart';
import 'timer_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Gym App")),
      body: ListView(
        children: [
          ListTile(
            title: Text("Workout"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutScreen())),
          ),
          ListTile(
            title: Text("Progress"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProgressScreen())),
          ),
          ListTile(
            title: Text("Gym Locator"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapScreen())),
          ),
          ListTile(
            title: const Text("Workout Timer"),
            leading: const Icon(Icons.timer),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimerScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}