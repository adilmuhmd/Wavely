import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wavely/providers/audio_providers.dart';
import 'package:wavely/screens/now_playing_screen.dart';

class MiniPlayer extends ConsumerWidget {
  final bool shrunk;

  const MiniPlayer({super.key, required this.shrunk});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    if (currentSong == null) return const SizedBox.shrink();

    // Layout shrinking animation
    const layoutDuration = Duration(milliseconds: 300);
    const layoutCurve = Curves.fastOutSlowIn;
    final double height = shrunk ? 60.0 : 76.0;

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false, // Essential for transparent background effects
              pageBuilder: (_, __, ___) => const NowPlayingScreen(),
              transitionDuration: const Duration(milliseconds: 400),
              reverseTransitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    // SLIDE UP ANIMATION (Apple Style)
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    const curve = Curves.fastOutSlowIn;

                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
            ),
          );
        },
        child: AnimatedContainer(
          duration: layoutDuration,
          curve: layoutCurve,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.transparent,
          child: Stack(
            children: [
              // Content Row
              Row(
                children: [
                  // 1. CACHED ARTWORK (No Shadow)
                  RepaintBoundary(
                    child: _MiniPlayerArtwork(
                      song: currentSong,
                      shrunk: shrunk,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MiniPlayerInfo(song: currentSong, shrunk: shrunk),
                  ),
                  const _MiniPlayerControls(),
                ],
              ),

              // Progress Bar (Pinned to Bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RepaintBoundary(child: _MiniProgressBar(shrunk: shrunk)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 1. ARTWORK (Clean - No Shadow)
// ==============================================================================
class _MiniPlayerArtwork extends ConsumerWidget {
  final LocalSong song;
  final bool shrunk;

  const _MiniPlayerArtwork({required this.song, required this.shrunk});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artworkAsync = ref.watch(artworkProvider(song.path));

    final double size = shrunk ? 40.0 : 52.0;
    final double radius = shrunk ? 8.0 : 12.0;

    // Simple Container with Image - No Shadows, No Glows
    return Hero(
      tag: 'artwork-${song.path}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: artworkAsync.when(
            data: (bytes) {
              if (bytes != null && bytes.isNotEmpty) {
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: 200, // Small cache for mini player
                );
              }
              return const _FallbackIcon();
            },
            loading: () => const _FallbackIcon(),
            error: (_, __) => const _FallbackIcon(),
          ),
        ),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white30, size: 20),
      ),
    );
  }
}

// ==============================================================================
// 2. TEXT INFO
// ==============================================================================
class _MiniPlayerInfo extends StatelessWidget {
  final LocalSong song;
  final bool shrunk;

  const _MiniPlayerInfo({required this.song, required this.shrunk});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          song.title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: shrunk ? 0.0 : 1.0,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              song.artist,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// 3. CONTROLS
// ==============================================================================
class _MiniPlayerControls extends ConsumerWidget {
  const _MiniPlayerControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
      playbackStateProvider.select((s) => s.value?.playing ?? false),
    );
    final controller = ref.read(audioControllerProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Previous Button
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            controller.skipPrevious();
          },
          icon: const Icon(
            Icons.skip_previous_rounded,
            color: Colors.white,
            size: 28,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),

        // Play/Pause Button (Simple White Circle)
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            controller.togglePlayPause();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Next Button
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            controller.skipNext();
          },
          icon: const Icon(
            Icons.skip_next_rounded,
            color: Colors.white,
            size: 28,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

// ==============================================================================
// 4. PROGRESS BAR (Pure White)
// ==============================================================================
class _MiniProgressBar extends ConsumerWidget {
  final bool shrunk;
  const _MiniProgressBar({required this.shrunk});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;

    final double progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: shrunk ? 0.0 : 1.0,
      child: Container(
        height: 2,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 1), // Align perfectly with bottom
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withOpacity(0.1),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 2,
        ),
      ),
    );
  }
}
