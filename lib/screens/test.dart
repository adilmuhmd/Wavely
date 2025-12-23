import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart'; // For LoopMode
import 'package:wavely/providers/audio_providers.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  // PERFORMANCE: Wait for navigation animation (Hero flight) to finish
  bool _transitionFinished = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _transitionFinished = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);

    if (currentSong == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Dismissible(
        key: const Key('now_playing_dismiss'),
        direction: DismissDirection.down,
        onDismissed: (_) => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // 1. Dynamic Background Layer
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _transitionFinished ? 1.0 : 0.0,
              child: _BackgroundLayer(songPath: currentSong.path),
            ),

            // 2. Main Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _HeaderSection(song: currentSong),
                    const Spacer(flex: 1),
                    _OptimizedArtwork(
                      songPath: currentSong.path,
                      showShadows: _transitionFinished,
                    ),
                    const Spacer(flex: 1),
                    _SongInfoSection(song: currentSong),
                    const SizedBox(height: 32),
                    const _IsolatedProgressBar(),
                    const SizedBox(height: 24),
                    const _IsolatedControls(),
                    const Spacer(flex: 2),
                    _BottomFeatures(song: currentSong),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. HEADER & DETAILS
// -----------------------------------------------------------------------------
class _HeaderSection extends ConsumerWidget {
  final LocalSong song;
  const _HeaderSection({required this.song});

  void _showOptions(BuildContext context, WidgetRef ref) {
    final isFav = ref.read(favoritesProvider).contains(song.id);
    // Get dynamic color
    final accentColor =
        ref.read(nowPlayingColorProvider).value ?? const Color(0xFF6366F1);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(bottom: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF151517).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            _OptionTile(
              icon: isFav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              title: isFav ? 'Remove from Favorites' : 'Add to Favorites',
              color: isFav ? const Color(0xFFEC4899) : Colors.white,
              onTap: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(song.id);
                Navigator.pop(ctx);
              },
            ),
            _OptionTile(
              icon: Icons.share_rounded,
              title: 'Share Song',
              onTap: () {
                Navigator.pop(ctx);
                ref.read(audioControllerProvider).shareSong(song);
              },
            ),
            _OptionTile(
              icon: Icons.info_outline_rounded,
              title: 'Track Details',
              onTap: () {
                Navigator.pop(ctx);
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) _showDetails(context);
                });
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(color: Colors.white10),
            ),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Delete from device',
              color: const Color(0xFFEF4444),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Details", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailText("Title", song.title),
            _DetailText("Artist", song.artist),
            _DetailText("Album", song.album),
            _DetailText("Genre", song.genre),
            _DetailText(
              "Year",
              song.year > 0 ? song.year.toString() : "Unknown",
            ),
            const SizedBox(height: 8),
            _DetailText("Bitrate", "${song.bitrate} kbps"),
            _DetailText("Format", song.format.toUpperCase()),
            _DetailText("Size", song.sizeString),
            _DetailText("Path", song.path, isPath: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Close",
              style: TextStyle(color: Colors.white),
            ), // Kept white for clarity
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Delete?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Permanently delete this file?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              ref.read(audioControllerProvider).deleteSong(song);
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 30,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        Text(
          "NOW PLAYING",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onPressed: () => _showOptions(context, ref),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 2. OPTIMIZED ARTWORK
// -----------------------------------------------------------------------------
class _OptimizedArtwork extends ConsumerWidget {
  final String songPath;
  final bool showShadows;

  const _OptimizedArtwork({required this.songPath, required this.showShadows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artworkAsync = ref.watch(artworkProvider(songPath));
    // Dynamic Shadow Color
    final accentColor =
        ref.watch(nowPlayingColorProvider).value ?? const Color(0xFF6366F1);

    final size = MediaQuery.sizeOf(context);
    final artworkSize = size.height * 0.38;

    return SizedBox(
      width: artworkSize,
      height: artworkSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 1000),
            opacity: showShadows ? 1.0 : 0.0,
            child: RepaintBoundary(
              child: Container(
                width: artworkSize * 0.85,
                height: artworkSize * 0.85,
                transform: Matrix4.translationValues(0, 20, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.5), // Dynamic Shadow
                      blurRadius: 60,
                      spreadRadius: -10,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Hero(
            tag: 'artwork-$songPath',
            child: Container(
              width: artworkSize,
              height: artworkSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF1F2937),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: artworkAsync.when(
                  data: (bytes) {
                    if (bytes != null && bytes.isNotEmpty) {
                      return Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: 800,
                      );
                    }
                    return const _FallbackIcon();
                  },
                  loading: () => const _FallbackIcon(),
                  error: (_, __) => const _FallbackIcon(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. BACKGROUND LAYER
// -----------------------------------------------------------------------------
class _BackgroundLayer extends ConsumerWidget {
  final String songPath;
  const _BackgroundLayer({required this.songPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dynamic Background Color via Provider
    final accentColor =
        ref.watch(nowPlayingColorProvider).value ?? const Color(0xFF1A1A2E);

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.5,
            colors: [accentColor.withOpacity(0.4), const Color(0xFF050505)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. PROGRESS BAR (Themed)
// -----------------------------------------------------------------------------
class _IsolatedProgressBar extends ConsumerWidget {
  const _IsolatedProgressBar();

  String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final accentColor =
        ref.watch(nowPlayingColorProvider).value ?? Colors.white;

    return RepaintBoundary(
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: accentColor, // Themed track
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              overlayColor: accentColor.withOpacity(0.2), // Themed glow
            ),
            child: Slider(
              value: progress,
              onChanged: (v) =>
                  ref.read(audioPlayerProvider).seek(duration * v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _format(position),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  _format(duration),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. CONTROLS (Themed)
// -----------------------------------------------------------------------------
class _IsolatedControls extends ConsumerWidget {
  const _IsolatedControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(playbackStateProvider).value?.playing ?? false;
    final shuffle = ref.watch(shuffleModeProvider).value ?? false;
    final loop = ref.watch(loopModeProvider).value ?? LoopMode.off;
    final audioController = ref.read(audioControllerProvider);

    // Dynamic Accent Color
    final accentColor =
        ref.watch(nowPlayingColorProvider).value ?? const Color(0xFF6366F1);

    IconData loopIcon;
    Color loopColor;
    if (loop == LoopMode.one) {
      loopIcon = Icons.repeat_one_rounded;
      loopColor = accentColor;
    } else if (loop == LoopMode.all) {
      loopIcon = Icons.repeat_rounded;
      loopColor = accentColor;
    } else {
      loopIcon = Icons.repeat_rounded;
      loopColor = Colors.white38;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: () => audioController.toggleShuffle(),
          icon: Icon(
            Icons.shuffle_rounded,
            color: shuffle ? accentColor : Colors.white38,
          ),
          iconSize: 26,
        ),
        _BouncyButton(
          onTap: () => audioController.skipPrevious(),
          child: const Icon(
            Icons.skip_previous_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
        _BouncyButton(
          onTap: () => audioController.togglePlayPause(),
          child: Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black, // Kept black for contrast
              size: 40,
            ),
          ),
        ),
        _BouncyButton(
          onTap: () => audioController.skipNext(),
          child: const Icon(
            Icons.skip_next_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
        IconButton(
          onPressed: () => audioController.cycleLoopMode(),
          icon: Icon(loopIcon, color: loopColor),
          iconSize: 26,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 6. BOTTOM FEATURES (Lyrics & Fav)
// -----------------------------------------------------------------------------
class _BottomFeatures extends ConsumerWidget {
  final LocalSong song;
  const _BottomFeatures({required this.song});

  void _showLyrics(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LyricsModal(song: song),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).contains(song.id);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _FeatureIcon(
          icon: Icons.lyrics_rounded,
          label: 'Lyrics',
          onTap: () => _showLyrics(context),
        ),
        _FeatureIcon(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: 'Favorite',
          isActive: isFav,
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(favoritesProvider.notifier).toggleFavorite(song.id);
          },
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 7. LYRICS MODAL
// -----------------------------------------------------------------------------
class _LyricsModal extends ConsumerWidget {
  final LocalSong song;
  const _LyricsModal({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsAsync = ref.watch(lyricsProvider(song));
    // Dynamic Accent
    final accentColor =
        ref.watch(nowPlayingColorProvider).value ?? const Color(0xFF6366F1);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151517).withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: lyricsAsync.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: accentColor)),
              error: (e, s) => const Center(
                child: Text(
                  "Could not find lyrics",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              data: (text) => SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 8. HELPERS & WIDGETS
// -----------------------------------------------------------------------------

class _SongInfoSection extends ConsumerWidget {
  final LocalSong song;
  const _SongInfoSection({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dynamic color for text
    final accentColor =
        ref.watch(nowPlayingColorProvider).value ?? Colors.white;

    return Column(
      children: [
        Text(
          song.title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accentColor, // Themed Title
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          song.artist,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color == Colors.white ? Colors.white : color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _FeatureIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _BouncyButton({required this.child, required this.onTap});
  @override
  State<_BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<_BouncyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.9).animate(_c),
        child: widget.child,
      ),
    );
  }
}

class _DetailText extends StatelessWidget {
  final String label;
  final String value;
  final bool isPath;
  const _DetailText(this.label, this.value, {this.isPath = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: isPath ? 10 : 14,
                color: isPath ? Colors.white38 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();
  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.music_note_rounded, size: 80, color: Colors.white24);
}
