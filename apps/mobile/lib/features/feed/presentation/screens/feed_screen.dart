import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
          ? const Center(child: Text('No news yet'))
          : ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, i) {
                final item = state.items[i];
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.source.name),
                );
              },
            ),
    );
  }
}
