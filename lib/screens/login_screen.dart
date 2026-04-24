import 'package:flutter/material.dart';
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: email, decoration: InputDecoration(labelText: "Email")),
            TextField(controller: password, decoration: InputDecoration(labelText: "Password"), obscureText: true),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));
              },
              child: Text("Login"),
            )
          ],
        ),
      ),
    );
  }
}