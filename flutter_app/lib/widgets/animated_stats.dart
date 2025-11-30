import 'package:flutter/material.dart';
import 'package:countup/countup.dart';
import '../constants/app_colors.dart';

/// An animated stat card that counts up to the final value
class AnimatedStatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final Duration animationDuration;
  final String? subtitle;

  const AnimatedStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.onTap,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    final effectiveBgColor = backgroundColor ?? effectiveColor.withOpacity(0.1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: effectiveColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: effectiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Countup(
              begin: 0,
              end: value.toDouble(),
              duration: animationDuration,
              separator: ',',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A row of animated stat cards
class AnimatedStatRow extends StatelessWidget {
  final List<StatData> stats;
  final Duration staggerDuration;

  const AnimatedStatRow({
    super.key,
    required this.stats,
    this.staggerDuration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats.asMap().entries.map((entry) {
        final index = entry.key;
        final stat = entry.value;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index > 0 ? 8 : 0,
              right: index < stats.length - 1 ? 8 : 0,
            ),
            child: AnimatedStatCard(
              title: stat.title,
              value: stat.value,
              icon: stat.icon,
              color: stat.color,
              onTap: stat.onTap,
              animationDuration: Duration(
                milliseconds: 1500 + (index * staggerDuration.inMilliseconds),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Data model for stat cards
class StatData {
  final String title;
  final int value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const StatData({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });
}

/// A compact animated counter for inline use
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 1200),
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix.isNotEmpty)
          Text(
            prefix,
            style: style ?? Theme.of(context).textTheme.titleLarge,
          ),
        Countup(
          begin: 0,
          end: value.toDouble(),
          duration: duration,
          separator: ',',
          style: style ?? Theme.of(context).textTheme.titleLarge,
        ),
        if (suffix.isNotEmpty)
          Text(
            suffix,
            style: style ?? Theme.of(context).textTheme.titleLarge,
          ),
      ],
    );
  }
}

/// A percentage counter with optional progress bar
class AnimatedPercentage extends StatelessWidget {
  final double percentage;
  final TextStyle? style;
  final Duration duration;
  final bool showProgressBar;
  final Color? progressColor;

  const AnimatedPercentage({
    super.key,
    required this.percentage,
    this.style,
    this.duration = const Duration(milliseconds: 1500),
    this.showProgressBar = false,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = progressColor ?? AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Countup(
              begin: 0,
              end: percentage,
              duration: duration,
              precision: 1,
              style: style ??
                  TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
            ),
            Text(
              '%',
              style: style ??
                  TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
            ),
          ],
        ),
        if (showProgressBar) ...[
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percentage / 100),
            duration: duration,
            builder: (context, value, child) {
              return LinearProgressIndicator(
                value: value,
                backgroundColor: effectiveColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(effectiveColor),
                borderRadius: BorderRadius.circular(4),
              );
            },
          ),
        ],
      ],
    );
  }
}
