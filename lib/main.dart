import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoginScreen(),
  ));
}



class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}
