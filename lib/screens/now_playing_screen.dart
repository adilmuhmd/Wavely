import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wavely/providers/audio_providers.dart';

// -----------------------------------------------------------------------------
// MAIN SCREEN
// -----------------------------------------------------------------------------

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _uiVisible = false;

  @override
  void initState() {
    super.initState();
    // Fade in UI elements slightly after navigation to ensure smoothness
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _uiVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);

    // Handle close if no song
    if (currentSong == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. SMOOTH BACKGROUND (The Foundation)
          Positioned.fill(
            child: _SmoothGradientBackground(songPath: currentSong.path),
          ),

          // 2. MAIN UI CONTENT
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: _uiVisible ? 1.0 : 0.0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Header
                    _HeaderSection(song: currentSong),

                    const Spacer(flex: 1),

                    // Artwork
                    RepaintBoundary(
                      child: _ArtworkSection(songPath: currentSong.path),
                    ),

                    const Spacer(flex: 1),

                    // Info (Title/Artist) - Fixed Height for Consistency
                    SizedBox(
                      height: 80, // Fixed height to prevent UI jumping
                      child: _SongInfoSection(song: currentSong),
                    ),

                    const SizedBox(height: 24),

                    // Seek Bar with Hi-Res Tag
                    _IsolatedProgressBar(format: currentSong.format),

                    const SizedBox(height: 16),

                    // Controls
                    const _SimplePlayerControls(),

                    const Spacer(flex: 2),

                    // Bottom Features (Lyrics/Fav)
                    _BottomFeatures(song: currentSong),

                    const SizedBox(height: 32),
                  ],
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
// 1. SMOOTH GRADIENT BACKGROUND
// -----------------------------------------------------------------------------
class _SmoothGradientBackground extends ConsumerWidget {
  final String songPath;
  const _SmoothGradientBackground({required this.songPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorAsync = ref.watch(dominantColorProvider(songPath));

    // Default color if extraction fails or is loading (Deep Grey/Black)
    final targetColor = colorAsync.value ?? const Color(0xFF151515);

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(
        milliseconds: 1200,
      ), // Slow, luxurious transition
      curve: Curves.easeInOutCubic, // Smooth start and end
      tween: ColorTween(begin: const Color(0xFF151515), end: targetColor),
      builder: (context, color, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2), // Centered slightly up
              radius: 1.6, // Spread wide
              colors: [(color ?? Colors.black).withOpacity(0.55), Colors.black],
              stops: const [0.0, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// 2. ARTWORK SECTION
// -----------------------------------------------------------------------------
class _ArtworkSection extends ConsumerWidget {
  final String songPath;

  const _ArtworkSection({required this.songPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artworkAsync = ref.watch(artworkProvider(songPath));
    final size = MediaQuery.sizeOf(context);
    // Artwork size logic
    final artworkSize = size.height * 0.38;

    return SizedBox(
      width: artworkSize,
      height: artworkSize,
      child: Hero(
        tag: 'artwork-$songPath',
        child: Container(
          width: artworkSize,
          height: artworkSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF1F2937),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: -5,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
    );
  }
}

// -----------------------------------------------------------------------------
// 3. SIMPLE PLAYER CONTROLS
// -----------------------------------------------------------------------------
class _SimplePlayerControls extends ConsumerWidget {
  const _SimplePlayerControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(playbackStateProvider).value?.playing ?? false;
    final shuffle = ref.watch(shuffleModeProvider).value ?? false;
    final loop = ref.watch(loopModeProvider).value ?? LoopMode.off;
    final audioController = ref.read(audioControllerProvider);
    final activeColor = const Color(0xFF6366F1);

    IconData loopIcon = Icons.repeat_rounded;
    if (loop == LoopMode.one) loopIcon = Icons.repeat_one_rounded;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: audioController.toggleShuffle,
          icon: Icon(
            Icons.shuffle_rounded,
            color: shuffle ? activeColor : Colors.white24,
          ),
          iconSize: 22,
        ),
        IconButton(
          onPressed: audioController.skipPrevious,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          iconSize: 42,
        ),
        // Big Play Button
        _BouncyButton(
          onTap: audioController.togglePlayPause,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 38,
            ),
          ),
        ),
        IconButton(
          onPressed: audioController.skipNext,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          iconSize: 42,
        ),
        IconButton(
          onPressed: audioController.cycleLoopMode,
          icon: Icon(
            loopIcon,
            color: loop != LoopMode.off ? activeColor : Colors.white24,
          ),
          iconSize: 22,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 4. ISOLATED PROGRESS BAR (WITH HI-RES TAG)
// -----------------------------------------------------------------------------
class _IsolatedProgressBar extends ConsumerWidget {
  final String format;
  const _IsolatedProgressBar({this.format = ''});

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

    final isHiRes =
        format.toLowerCase() == 'flac' || format.toLowerCase() == 'wav';

    return Column(
      children: [
        // Top Labels Row (Hi-Res Tag + Timers)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left side: Hi-Res Tag (if applicable)
              if (isHiRes)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "Hi-Res Audio",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else
                const SizedBox(
                  height: 20,
                ), // Placeholder to maintain height if no tag
              // Right side: You could put bitrate here if you wanted,
              // but purely requested layout keeps it simple.
            ],
          ),
        ),

        // The Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: Colors.white10,
            trackShape: _CustomTrackShape(), // Removes default padding
          ),
          child: Slider(
            value: progress,
            onChanged: (v) => ref.read(audioPlayerProvider).seek(duration * v),
          ),
        ),

        const SizedBox(height: 4),

        // Timers below slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _format(position),
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
            ),
            Text(
              _format(duration),
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

// Helper to align slider perfectly with edges
class _CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

// -----------------------------------------------------------------------------
// 5. HEADER & OPTIONS
// -----------------------------------------------------------------------------
class _HeaderSection extends ConsumerWidget {
  final LocalSong song;
  const _HeaderSection({required this.song});

  void _showOptions(BuildContext context, WidgetRef ref) {
    final isFav = ref.read(favoritesProvider).contains(song.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _GlassModalContainer(
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
              title: isFav ? 'Remove from Likes' : 'Add to Likes',
              color: isFav ? const Color(0xFFEC4899) : Colors.white,
              onTap: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(song.id);
                Navigator.pop(ctx);
              },
            ),
            _OptionTile(
              icon: Icons.info_outline_rounded,
              title: 'View Details',
              onTap: () {
                Navigator.pop(ctx);
                // Simple delay to allow modal to close before dialog opens
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (context.mounted) _showDetails(context);
                });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Details",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow("Title", song.title),
            _DetailRow("Artist", song.artist),
            _DetailRow("Album", song.album),
            _DetailRow("Format", song.format),
            _DetailRow("Size", song.sizeString),
            _DetailRow("Path", song.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Close",
              style: GoogleFonts.poppins(color: Colors.blueAccent),
            ),
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
        title: Text("Delete?", style: GoogleFonts.poppins(color: Colors.white)),
        content: Text(
          "Permanently delete this file?",
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(audioControllerProvider).deleteSong(song);
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(color: Colors.red),
            ),
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        Text(
          "NOW PLAYING",
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. SONG INFO (WITH SCROLLING TEXT)
// -----------------------------------------------------------------------------
class _SongInfoSection extends StatelessWidget {
  final LocalSong song;
  const _SongInfoSection({required this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title with Marquee Effect
        _MarqueeText(
          text: song.title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        // Artist
        Text(
          song.artist,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 16),
        ),
      ],
    );
  }
}

// Custom Marquee Widget to fix overflow/movement issues
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (mounted) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) break;
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(
            seconds: (widget.text.length * 0.2).round().clamp(3, 10),
          ),
          curve: Curves.linear,
        );
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) break;
        await _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      } else {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35, // Fixed height for title area
      child: Center(
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(), // Disable user scroll
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ), // Padding for fade effect area
            child: Text(widget.text, style: widget.style),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 7. BOTTOM FEATURES (ROUNDER, CLEANER BUTTONS)
// -----------------------------------------------------------------------------
class _BottomFeatures extends ConsumerWidget {
  final LocalSong song;
  const _BottomFeatures({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).contains(song.id);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundedFeatureButton(
          icon: Icons.lyrics_outlined,
          label: "Lyrics",
          onTap: () {}, // Lyrics logic here
        ),
        const SizedBox(width: 32),
        _RoundedFeatureButton(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: "Favorite",
          isActive: isFav,
          activeColor: const Color(0xFFEC4899),
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(favoritesProvider.notifier).toggleFavorite(song.id);
          },
        ),
      ],
    );
  }
}

class _RoundedFeatureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  const _RoundedFeatureButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1), // Glassy background
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(
              icon,
              color: isActive ? (activeColor ?? Colors.white) : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassModalContainer extends StatelessWidget {
  final Widget child;
  const _GlassModalContainer({required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF151517).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white10),
          ),
          child: child,
        ),
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
        style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
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
        child: Icon(Icons.music_note_rounded, size: 80, color: Colors.white24),
      ),
    );
  }
}
