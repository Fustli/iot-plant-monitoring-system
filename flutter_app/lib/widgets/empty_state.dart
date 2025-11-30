import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../constants/app_colors.dart';

/// Types of empty state animations
enum EmptyStateType {
  /// An empty box animation - for "no items" states
  emptyBox,

  /// A growing plant animation - for plant-related empty states
  plant,

  /// A success checkmark animation
  success,

  /// A question mark / no data animation
  noData,
}

/// A widget displaying an animated empty state with Lottie animation
class EmptyStateWidget extends StatelessWidget {
  final EmptyStateType type;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double animationSize;
  final bool repeat;

  const EmptyStateWidget({
    super.key,
    this.type = EmptyStateType.emptyBox,
    required this.title,
    this.subtitle,
    this.action,
    this.animationSize = 180,
    this.repeat = true,
  });

  String get _animationPath {
    switch (type) {
      case EmptyStateType.emptyBox:
        return 'assets/animations/empty_box.json';
      case EmptyStateType.plant:
        return 'assets/animations/plant_growing.json';
      case EmptyStateType.success:
        return 'assets/animations/success.json';
      case EmptyStateType.noData:
        return 'assets/animations/no_data.json';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              _animationPath,
              width: animationSize,
              height: animationSize,
              repeat: repeat,
              errorBuilder: (context, error, stackTrace) {
                // Fallback icon if animation fails
                return Icon(
                  _getFallbackIcon(),
                  size: animationSize * 0.5,
                  color: Colors.grey[400],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  IconData _getFallbackIcon() {
    switch (type) {
      case EmptyStateType.emptyBox:
        return Icons.inbox_outlined;
      case EmptyStateType.plant:
        return Icons.eco_outlined;
      case EmptyStateType.success:
        return Icons.check_circle_outline;
      case EmptyStateType.noData:
        return Icons.help_outline;
    }
  }
}

/// A compact empty state for inline use
class CompactEmptyState extends StatelessWidget {
  final EmptyStateType type;
  final String message;
  final double size;

  const CompactEmptyState({
    super.key,
    this.type = EmptyStateType.emptyBox,
    required this.message,
    this.size = 100,
  });

  String get _animationPath {
    switch (type) {
      case EmptyStateType.emptyBox:
        return 'assets/animations/empty_box.json';
      case EmptyStateType.plant:
        return 'assets/animations/plant_growing.json';
      case EmptyStateType.success:
        return 'assets/animations/success.json';
      case EmptyStateType.noData:
        return 'assets/animations/no_data.json';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset(
          _animationPath,
          width: size,
          height: size,
          repeat: true,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.inbox_outlined,
              size: size * 0.5,
              color: Colors.grey[400],
            );
          },
        ),
        const SizedBox(width: 16),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
        ),
      ],
    );
  }
}

/// A success overlay that can be shown temporarily
class SuccessAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;

  const SuccessAnimation({
    super.key,
    this.onComplete,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation> {
  @override
  void initState() {
    super.initState();
    if (widget.onComplete != null) {
      Future.delayed(widget.duration, widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Lottie.asset(
          'assets/animations/success.json',
          width: 120,
          height: 120,
          repeat: false,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.check_circle,
              size: 80,
              color: AppColors.success,
            );
          },
        ),
      ),
    );
  }
}
