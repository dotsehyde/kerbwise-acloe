import 'package:flutter/material.dart';

import '../theme/courier_theme.dart';

class ScreenMessage extends StatelessWidget {
  const ScreenMessage({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.retry,
  });

  final IconData icon;
  final String title;
  final String? description;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: forest, size: 36),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (description case final String message) ...[
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
          if (retry case final VoidCallback onRetry) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}
