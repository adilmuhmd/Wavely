import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wavely/providers/audio_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favSongs = ref.watch(favoriteSongsProvider);
    final audioController = ref.read(audioControllerProvider);

    // --- 1. EMPTY STATE ---
    if (favSongs.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0A0A),
          elevation: 0,
          title: const Text(
            "Liked Songs",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 64,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "No liked songs yet",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Songs you love will appear here",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // --- 2. MAIN CONTENT ---
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // A. APP BAR (MATCHING LIBRARY THEME)
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0A),
            pinned: true,
            floating: false,
            expandedHeight: 140.0,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.fadeTitle],
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              centerTitle: false,
              title: const Text(
                "Liked Songs",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF3B1E28), // Subtle Pink/Red Tint for Likes
                      Color(0xFF0A0A0A), // Blends into background
                    ],
                  ),
                ),
              ),
            ),
          ),

          // B. ACTIONS ROW (Song Count & Shuffle)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${favSongs.length} songs",
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final shuffled = List<LocalSong>.from(favSongs)
                        ..shuffle();
                      audioController.playPlaylist(shuffled);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954), // Spotify Green
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shuffle, color: Colors.black, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "SHUFFLE",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // C. SONG LIST
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: _FavSongTile(song: favSongs[index]),
              );
            }, childCount: favSongs.length),
          ),

          // D. BOTTOM PADDING
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LOCAL TILE WIDGET
// -----------------------------------------------------------------------------
class _FavSongTile extends ConsumerWidget {
  final LocalSong song;
  const _FavSongTile({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSongId = ref.watch(currentSongProvider.select((s) => s?.id));
    final isCurrent = currentSongId == song.id;
    final isPlaying = ref.watch(
      playbackStateProvider.select((s) => s.value?.playing ?? false),
    );

    final art = ref.watch(artworkProvider(song.path));

    final titleColor = isCurrent ? const Color(0xFF6366F1) : Colors.white;
    final subtitleColor = isCurrent
        ? const Color(0xFF6366F1).withOpacity(0.7)
        : Colors.white54;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isCurrent
          ? const Color(0xFF6366F1).withOpacity(0.1)
          : Colors.transparent,
      onTap: () {
        final allFavs = ref.read(favoriteSongsProvider);
        ref
            .read(audioControllerProvider)
            .playPlaylist(allFavs, initialIndex: allFavs.indexOf(song));
      },
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              art.when(
                data: (bytes) => bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                      )
                    : const Icon(Icons.music_note, color: Colors.white24),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              if (isCurrent && isPlaying)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Icon(
                      Icons.graphic_eq,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: titleColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: subtitleColor, fontSize: 13),
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFEC4899),
          size: 22,
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          ref.read(favoritesProvider.notifier).toggleFavorite(song.id);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Removed from Likes",
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF1F2937),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}
