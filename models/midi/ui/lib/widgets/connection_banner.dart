import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/health_provider.dart';


class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);

    return health.when(
      loading: () => const SizedBox.shrink(),
      error: (err, _) => _Banner(
        color: Theme.of(context).colorScheme.error,
        icon: Icons.cloud_off,
        message: 'Cannot connect to server',
        onRetry: () => ref.invalidate(healthProvider),
      ),
      data: (status) {
        if (!status.modelLoaded) {
          return _Banner(
            color: Colors.amber,
            icon: Icons.warning_amber,
            message: 'Model not loaded on server',
            onRetry: () => ref.invalidate(healthProvider),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  const _Banner({
    required this.color,
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry', style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
