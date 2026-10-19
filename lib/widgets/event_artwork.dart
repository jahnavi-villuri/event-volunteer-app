import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EventArtwork extends StatelessWidget {
  final String eventName;
  final String? imageUrl;
  final double height;
  final BorderRadius borderRadius;

  const EventArtwork({
    super.key,
    required this.eventName,
    this.imageUrl,
    this.height = 164,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  String get _imageUrl {
    final suppliedUrl = imageUrl?.trim();
    if (suppliedUrl != null && suppliedUrl.isNotEmpty) return suppliedUrl;

    final name = eventName.toLowerCase();
    if (name.contains('sport') || name.contains('game') || name.contains('run')) {
      return 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?auto=format&fit=crop&w=1200&q=85';
    }
    if (name.contains('tech') ||
        name.contains('science') ||
        name.contains('conference')) {
      return 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1200&q=85';
    }
    if (name.contains('cultur') || name.contains('music') || name.contains('fest')) {
      return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1200&q=85';
    }
    return 'https://images.unsplash.com/photo-1559027615-cd4628902d4a?auto=format&fit=crop&w=1200&q=85';
  }

  IconData get _fallbackIcon {
    final name = eventName.toLowerCase();
    if (name.contains('sport') || name.contains('game') || name.contains('run')) {
      return Icons.sports_soccer;
    }
    if (name.contains('cultur') || name.contains('music') || name.contains('fest')) {
      return Icons.celebration;
    }
    if (name.contains('tech') || name.contains('science')) {
      return Icons.memory;
    }
    return Icons.volunteer_activism;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Image.network(
          _imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(
                _fallbackIcon,
                color: Colors.white.withValues(alpha: 0.88),
                size: 58,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
