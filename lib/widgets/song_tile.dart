import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wavely/providers/audio_providers.dart';
import 'package:wavely/screens/now_playing_screen.dart';

class SongTile extends ConsumerWidget {
  final LocalSong song;

  const SongTile({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. SELECTORS: Only rebuild if playing status or current song changes
    final currentSongId = ref.watch(currentSongProvider.select((s) => s?.id));
    final isCurrent = currentSongId == song.id;
    final isPlaying = ref.watch(
      playbackStateProvider.select((s) => s.value?.playing ?? false),
    );

    final showWave = isCurrent && isPlaying;
    final audioController = ref.read(audioControllerProvider);
    final artworkAsync = ref.watch(artworkProvider(song.path));

    // 2. STATIC ACCENT COLOR (High Performance)
    // No more palette generation. Instant visual feedback.
    const accentColor = Color(0xFF6366F1);

    // 3. CLEAN SELECTION STYLES
    final titleColor = isCurrent ? accentColor : Colors.white;
    final subtitleColor = isCurrent
        ? accentColor.withOpacity(0.8)
        : Colors.white54;
    final iconColor = isCurrent ? accentColor : Colors.white38;

    // Subtle tint for the selected tile background
    final tileColor = isCurrent
        ? accentColor.withOpacity(0.12)
        : Colors.transparent;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: tileColor,
          onTap: () {
            final allSongs = ref.read(songsProvider);
            final index = allSongs.indexWhere((s) => s.id == song.id);
            if (index != -1) {
              audioController.playPlaylist(allSongs, initialIndex: index);
            }
          },
          leading: SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: artworkAsync.when(
                    data: (bytes) {
                      if (bytes != null && bytes.isNotEmpty) {
                        return Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          width: 52,
                          height: 52,
                          gaplessPlayback: true,
                          // Optimize cache size for list view
                          cacheWidth: 150,
                        );
                      }
                      return const _FallbackCover();
                    },
                    // No spinner in list for smoother scrolling
                    loading: () => const _FallbackCover(),
                    error: (_, __) => const _FallbackCover(),
                  ),
                ),
                // Overlay Wave Animation if playing
                if (showWave)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: WaveBars(color: accentColor)),
                  ),
              ],
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
              fontSize: 15,
              color: titleColor,
            ),
          ),
          subtitle: Text(
            '${song.artist} • ${song.durationString}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: subtitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.more_vert_rounded, color: iconColor, size: 22),
            onPressed: () => _showOptionsSheet(context, ref, song),
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context, WidgetRef ref, LocalSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SongOptionsSheet(song: song),
    );
  }
}

// ==============================================================================
// WAVE ANIMATION (Lightweight)
// ==============================================================================
class WaveBars extends StatefulWidget {
  final Color color;
  const WaveBars({super.key, required this.color});

  @override
  State<WaveBars> createState() => _WaveBarsState();
}

class _WaveBarsState extends State<WaveBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) {
          final delays = [0.0, 0.5, 0.2];
          return _Bar(
            controller: _controller,
            delay: delays[i],
            color: widget.color,
          );
        }),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Color color;

  const _Bar({
    required this.controller,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = (controller.value + delay) % 1.0;
        final progress = (t < 0.5) ? t * 2 : 2 - t * 2;
        final height = 4.0 + (10.0 * progress);

        return Container(
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      },
    );
  }
}

// ==============================================================================
// OPTIONS SHEET
// ==============================================================================
class _SongOptionsSheet extends ConsumerWidget {
  final LocalSong song;
  const _SongOptionsSheet({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).contains(song.id);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151517).withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
      ),
      child: SafeArea(
        top: false,
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
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    song.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12, height: 1),

            _OptionTile(
              icon: isFav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: isFav ? 'Remove from Likes' : 'Add to Likes',
              color: isFav ? const Color(0xFFEC4899) : Colors.white,
              onTap: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(song.id);
                Navigator.pop(context);
              },
            ),
            _OptionTile(
              icon: Icons.share_rounded,
              label: 'Share Song',
              onTap: () async {
                Navigator.pop(context);
                final file = File(song.path);
                if (await file.exists()) {
                  await Share.shareXFiles([
                    XFile(song.path),
                  ], text: '${song.title} - ${song.artist}');
                }
              },
            ),
            _OptionTile(
              icon: Icons.info_outline_rounded,
              label: 'Details',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => _DetailsDialog(song: song),
                );
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete from Device',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref, song);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, LocalSong song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Delete?",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          "This will permanently remove the file from your device.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(audioControllerProvider).deleteSong(song);
              Navigator.pop(ctx);
            },
            child: const Text(
              "Delete",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ==============================================================================
// DETAILS DIALOG
// ==============================================================================
class _DetailsDialog extends StatelessWidget {
  final LocalSong song;
  const _DetailsDialog({required this.song});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        "Details",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow("Title", song.title),
            _DetailRow("Artist", song.artist),
            _DetailRow("Album", song.album),
            _DetailRow("Duration", song.durationString),
            _DetailRow("Format", song.format.toUpperCase()),
            _DetailRow("Size", song.sizeString),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                song.path,
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  color: Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Close",
            style: TextStyle(color: Color(0xFF6366F1)),
          ),
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
          text: "$label: ",
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
          children: [
            TextSpan(
              text: value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// FALLBACK COVER
// ==============================================================================
class _FallbackCover extends StatelessWidget {
  const _FallbackCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.08),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white30, size: 24),
      ),
    );
  }
}
