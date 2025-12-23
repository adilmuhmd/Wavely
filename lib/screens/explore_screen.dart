import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wavely/providers/audio_providers.dart';

// ==============================================================================
// 1. DATA MODELS & LOGIC
// ==============================================================================

class GeneratedMix {
  final String title;
  final String subtitle;
  final List<LocalSong> songs;
  final Color accentColor;
  final String type; // 'Genre', 'Artist', 'Daily'

  GeneratedMix({
    required this.title,
    required this.subtitle,
    required this.songs,
    required this.accentColor,
    required this.type,
  });
}

// Optimized Generator
final mixGeneratorProvider = FutureProvider<List<GeneratedMix>>((ref) async {
  final allSongs = ref.watch(songsProvider);
  if (allSongs.isEmpty) return [];

  // Running heavy logic in a microtask or separate isolate is preferred for massive lists,
  // but for <5000 songs, this logic is fast enough.
  final List<GeneratedMix> mixes = [];
  final random = Random();

  Color getRandomColor() {
    const colors = [
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF673AB7),
      Color(0xFF3F51B5),
      Color(0xFF2196F3),
      Color(0xFF009688),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFFFF5722),
    ];
    return colors[random.nextInt(colors.length)];
  }

  // 1. Genre Clusters
  final Map<String, List<LocalSong>> genreMap = {};
  for (var song in allSongs) {
    if (song.genre != 'Unknown Genre' && song.genre != 'Music') {
      genreMap.putIfAbsent(song.genre, () => []).add(song);
    }
  }

  genreMap.forEach((genre, songs) {
    if (songs.length >= 5) {
      songs.shuffle();
      mixes.add(
        GeneratedMix(
          title: "$genre Mix",
          subtitle: "Best of $genre",
          songs: songs.take(20).toList(),
          accentColor: getRandomColor(),
          type: 'Genre',
        ),
      );
    }
  });

  // 2. Artist Clusters
  final Map<String, List<LocalSong>> artistMap = {};
  for (var song in allSongs) {
    if (song.artist != 'Unknown Artist') {
      artistMap.putIfAbsent(song.artist, () => []).add(song);
    }
  }

  artistMap.forEach((artist, songs) {
    if (songs.length >= 4) {
      songs.shuffle();
      mixes.add(
        GeneratedMix(
          title: "This is $artist",
          subtitle: "Essentials by $artist",
          songs: songs,
          accentColor: getRandomColor(),
          type: 'Artist',
        ),
      );
    }
  });

  // 3. Daily Mixes
  for (int i = 1; i <= 6; i++) {
    final seedSong = allSongs[random.nextInt(allSongs.length)];
    final similarSongs = allSongs
        .where((s) => s.genre == seedSong.genre || s.artist == seedSong.artist)
        .toList();

    if (similarSongs.length < 15) {
      final remaining = allSongs
          .where((s) => !similarSongs.contains(s))
          .toList();
      remaining.shuffle();
      similarSongs.addAll(remaining.take(15 - similarSongs.length));
    }

    similarSongs.shuffle();
    final artistNames = similarSongs
        .take(3)
        .map((s) => s.artist)
        .toSet()
        .join(", ");

    mixes.add(
      GeneratedMix(
        title: "Daily Mix $i",
        subtitle: artistNames,
        songs: similarSongs.take(20).toList(),
        accentColor: getRandomColor(),
        type: 'Daily',
      ),
    );
  }

  mixes.shuffle();
  return mixes;
});

// ==============================================================================
// 2. MAIN EXPLORE SCREEN
// ==============================================================================

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  String _getQuote() {
    const quotes = [
      "Where words leave off, music begins.",
      "Music is the soundtrack of your life.",
      "Life is a song. Love is the music.",
      "Music gives a soul to the universe.",
      "Without music, life would be a mistake.",
    ];
    return quotes[Random().nextInt(quotes.length)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSongs = ref.watch(songsProvider);
    final mixesAsync = ref.watch(mixGeneratorProvider);
    final size = MediaQuery.of(context).size;

    // Responsive Grid Count
    final int gridCrossAxisCount = size.width > 600 ? 4 : 2;

    if (allSongs.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    final featuredSong = allSongs[Random().nextInt(allSongs.length)];

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Smart Silver App Bar
          SliverAppBar(
            backgroundColor: Colors.black,
            floating: false,
            pinned: true,
            expandedHeight: 140.0,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.fadeTitle],
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              centerTitle: false,
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 22, // Adjusted for Sliver collapse
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _getQuote(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E1E2C), Colors.black],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {}, // Add search logic
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
            ],
          ),

          // 2. Featured Hero (SliverToBoxAdapter)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: _FeaturedHero(song: featuredSong),
            ),
          ),

          // 3. Mixes Content
          mixesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(50.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (e, s) => SliverToBoxAdapter(child: Text("Error: $e")),
            data: (mixes) {
              final dailyMixes = mixes
                  .where((m) => m.type == 'Daily')
                  .take(6)
                  .toList();
              final artistMixes = mixes
                  .where((m) => m.type == 'Artist')
                  .take(10)
                  .toList();
              final genreMixes = mixes
                  .where((m) => m.type == 'Genre')
                  .take(10)
                  .toList();

              return SliverList(
                delegate: SliverChildListDelegate.fixed([
                  // -- Daily Mixes (Horizontal Scroll) --
                  if (dailyMixes.isNotEmpty) ...[
                    const _SectionHeader(title: "Your Daily Mixes"),
                    SizedBox(
                      height: 240, // Fixed height for performance
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: dailyMixes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        // Using builder for lazy loading
                        itemBuilder: (context, index) =>
                            _DailyMixCard(mix: dailyMixes[index]),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // -- Artist Mixes (Horizontal Scroll) --
                  if (artistMixes.isNotEmpty) ...[
                    const _SectionHeader(title: "Your Favorite Artists"),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: artistMixes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 20),
                        itemBuilder: (context, index) =>
                            _ArtistMixCircle(mix: artistMixes[index]),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // -- Recently Added (Compact List) --
                  const _SectionHeader(title: "Recently Added"),
                  // Performance note: Mapping 5 items is fine. If this list grows, use SliverList.builder
                  ...allSongs
                      .take(5)
                      .map(
                        (song) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _CompactSongTile(song: song),
                        ),
                      ),
                  const SizedBox(height: 32),

                  // -- Genre Grid (Embedded GridView) --
                  if (genreMixes.isNotEmpty) ...[
                    const _SectionHeader(title: "Browse by Genre"),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap:
                            true, // Necessary inside nested scroll view (careful with massive lists)
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridCrossAxisCount,
                          childAspectRatio: 1.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: genreMixes.length,
                        itemBuilder: (context, index) =>
                            _GenreCard(mix: genreMixes[index]),
                      ),
                    ),
                  ],

                  const SizedBox(height: 120), // Bottom padding for player bar
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 3. MIX DETAIL POPUP (Draggable Bottom Sheet)
// ==============================================================================

void showMixPopup(BuildContext context, GeneratedMix mix) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Allows full height
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (context) => _MixDetailBottomSheet(mix: mix),
  );
}

class _MixDetailBottomSheet extends ConsumerWidget {
  final GeneratedMix mix;
  const _MixDetailBottomSheet({required this.mix});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DraggableScrollableSheet gives that nice "pull up" feel
    // and links the internal scroll position to the sheet position
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: CustomScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverAppBar(
                  pinned: true,
                  backgroundColor: mix.accentColor.withOpacity(0.9),
                  expandedHeight: 300,
                  automaticallyImplyLeading: false, // Hide default back button
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [mix.accentColor, Colors.black],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: _MixCollageArt(songs: mix.songs, size: 160),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            mix.title,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            mix.subtitle,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Play Button Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${mix.songs.length} songs",
                          style: GoogleFonts.poppins(color: Colors.white54),
                        ),
                        GestureDetector(
                          onTap: () {
                            ref
                                .read(audioControllerProvider)
                                .playPlaylist(mix.songs);
                            // Optional: Close popup on play
                            // Navigator.pop(context);
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1DB954),
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Efficient Song List using SliverList.builder
                SliverList.builder(
                  itemCount: mix.songs.length,
                  itemBuilder: (context, index) {
                    return _CompactSongTile(song: mix.songs[index]);
                  },
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==============================================================================
// 4. OPTIMIZED WIDGETS
// ==============================================================================

class _DailyMixCard extends StatelessWidget {
  final GeneratedMix mix;
  const _DailyMixCard({required this.mix});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showMixPopup(context, mix),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _MixCollageArt(songs: mix.songs, size: 160),
            ),
            const SizedBox(height: 12),
            Text(
              mix.title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mix.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MixCollageArt extends StatelessWidget {
  final List<LocalSong> songs;
  final double size;
  const _MixCollageArt({required this.songs, required this.size});

  @override
  Widget build(BuildContext context) {
    // Logic to get exactly 4 paths (or repeat if < 4)
    final coverSongs = songs.take(4).toList();
    while (coverSongs.length < 4 && coverSongs.isNotEmpty) {
      coverSongs.add(coverSongs.first);
    }

    // Fallback if empty
    if (coverSongs.isEmpty) return Container(color: Colors.grey[850]);

    // RepaintBoundary improves performance for static complex collages
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _TinyArt(songPath: coverSongs[0].path)),
                  Expanded(
                    child: _TinyArt(
                      songPath: coverSongs.length > 1 ? coverSongs[1].path : '',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _TinyArt(
                      songPath: coverSongs.length > 2 ? coverSongs[2].path : '',
                    ),
                  ),
                  Expanded(
                    child: _TinyArt(
                      songPath: coverSongs.length > 3 ? coverSongs[3].path : '',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyArt extends ConsumerWidget {
  final String songPath;
  const _TinyArt({required this.songPath});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songPath.isEmpty) return Container(color: Colors.grey[900]);

    final art = ref.watch(artworkProvider(songPath));
    return art.when(
      data: (bytes) => bytes != null
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              cacheWidth: 200, // Memory optimization
            )
          : Container(color: Colors.grey[850]),
      loading: () => Container(color: Colors.grey[900]),
      error: (_, __) => Container(color: Colors.grey[900]),
    );
  }
}

class _FeaturedHero extends ConsumerWidget {
  final LocalSong song;
  const _FeaturedHero({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artworkAsync = ref.watch(artworkProvider(song.path));
    return GestureDetector(
      onTap: () => ref.read(audioControllerProvider).playPlaylist([song]),
      child: Stack(
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF2A2A2A),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: artworkAsync.when(
                data: (bytes) => bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.6),
                        colorBlendMode: BlendMode.darken,
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                        ),
                      ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: artworkAsync.when(
                      data: (bytes) => bytes != null
                          ? Image.memory(bytes, fit: BoxFit.cover)
                          : const Icon(Icons.music_note, color: Colors.white),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "SUGGESTED",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistMixCircle extends ConsumerWidget {
  final GeneratedMix mix;
  const _ArtistMixCircle({required this.mix});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artPath = mix.songs.isNotEmpty ? mix.songs.first.path : '';
    final art = ref.watch(artworkProvider(artPath));
    return GestureDetector(
      onTap: () => showMixPopup(context, mix),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
              ],
            ),
            child: ClipOval(
              child: art.when(
                data: (bytes) => bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 200, // Optimize
                      )
                    : Container(
                        color: mix.accentColor,
                        child: Center(
                          child: Text(
                            mix.title.split(' ').last[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                            ),
                          ),
                        ),
                      ),
                loading: () => Container(color: Colors.grey[900]),
                error: (_, __) => Container(color: Colors.grey[900]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 120,
            child: Text(
              mix.title.replaceAll("This is ", ""),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreCard extends ConsumerWidget {
  final GeneratedMix mix;
  const _GenreCard({required this.mix});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showMixPopup(context, mix),
      child: Container(
        decoration: BoxDecoration(
          color: mix.accentColor,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                mix.title.replaceAll(" Mix", ""),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              right: -15,
              bottom: -5,
              child: Transform.rotate(
                angle: 0.4,
                child: Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _TinyArt(
                      songPath: mix.songs.isNotEmpty
                          ? mix.songs.first.path
                          : '',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSongTile extends ConsumerWidget {
  final LocalSong song;
  const _CompactSongTile({required this.song});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = ref.watch(artworkProvider(song.path));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: () => ref.read(audioControllerProvider).playPlaylist([song]),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: art.when(
            data: (bytes) => bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 100, // Small image, small cache
                  )
                : const Icon(Icons.music_note, color: Colors.white24),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
      ),
      trailing: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
