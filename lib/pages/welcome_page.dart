import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wine_bar,
              size: 64,
              color: Colors.purple,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Wine Launcher',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Manage your Wine and Proton prefixes with ease',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 