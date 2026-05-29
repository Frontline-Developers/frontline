import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/my_reports_provider.dart';

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myReportsNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.reports.isEmpty
          ? const Center(child: Text('No submissions yet'))
          : ListView.builder(
              itemCount: state.reports.length,
              itemBuilder: (context, i) {
                final r = state.reports[i];
                return ListTile(
                  title: Text(r.category),
                  subtitle: Text(r.description),
                  trailing: Text(r.status),
                );
              },
            ),
    );
  }
}
