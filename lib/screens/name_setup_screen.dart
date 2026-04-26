import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class NameSetupScreen extends StatefulWidget {
  const NameSetupScreen({Key? key}) : super(key: key);

  @override
  State<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends State<NameSetupScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save name to Firebase Auth profile
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        _nameController.text.trim(),
      );
// Force reload user so displayName updates immediately
      await FirebaseAuth.instance.currentUser?.reload();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to save name. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.waving_hand, size: 60, color: Color(0xFF00D4FF)),
              const SizedBox(height: 24),
              const Text(
                "What's your name?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll use this to personalise your experience.",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),

              // Name input
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'e.g. John',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.person_outline,
                      color: Color(0xFF00D4FF)),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    const BorderSide(color: Color(0xFF00D4FF)),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _saveName(),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),

              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _saveName,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                    "Let's Go! 💪",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}