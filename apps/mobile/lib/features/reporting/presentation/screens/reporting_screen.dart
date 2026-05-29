import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReportingScreen extends StatelessWidget {
  const ReportingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Report'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: const Center(
        child: Text('Multi-step reporting form — coming soon'),
      ),
    );
  }
}
