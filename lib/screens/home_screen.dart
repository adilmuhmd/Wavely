import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'package:wavely/providers/audio_providers.dart';
import 'package:wavely/screens/explore_screen.dart';
import 'package:wavely/widgets/song_tile.dart';
import 'package:wavely/widgets/mini_player.dart';
import 'package:wavely/screens/favorites_screen.dart';

// ==============================================================================
// 1. MAIN HOME SCREEN
// ==============================================================================

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isScrolling = false;
  int _selectedTab = 0; // 0=Library, 1=Likes, 2=Search, 3=Explore
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = index);

    // Animate the PageView to the selected tab
    // Note: We use jumpToPage for distant tabs to avoid scrolling through Search
    if ((index - _pageController.page!.round()).abs() > 1) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }

    if (index != 2) {
      ref.read(searchQueryProvider.notifier).state = '';
    }
  }

  void _onPageChanged(int index) {
    // If user swipes into Search (index 2) from Likes (1), skip to Explore (3)
    if (index == 2) {
      // Determine direction based on previous tab
      if (_selectedTab == 1) {
        // Swiping Right: Go to Explore (3)
        _pageController.jumpToPage(3);
        setState(() => _selectedTab = 3);
      } else if (_selectedTab == 3) {
        // Swiping Left: Go to Likes (1)
        _pageController.jumpToPage(1);
        setState(() => _selectedTab = 1);
      } else {
        // Direct access (e.g. from nav bar), allow it
        setState(() => _selectedTab = 2);
      }
    } else {
      setState(() => _selectedTab = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final currentSong = ref.watch(currentSongProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Global Background
          const _GlobalBackground(),

          // Main Content (Swipeable PageView)
          SafeArea(
            bottom: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  // Only hide nav bar on vertical scrolls, not horizontal page swipes
                  if (notification.metrics.axis == Axis.vertical) {
                    if (notification.direction == ScrollDirection.reverse) {
                      if (!_isScrolling) setState(() => _isScrolling = true);
                    } else if (notification.direction ==
                        ScrollDirection.forward) {
                      if (_isScrolling) setState(() => _isScrolling = false);
                    }
                  }
                }
                return false;
              },
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: const [
                  _LibraryView(), // Index 0
                  ExploreScreen(), // Index 1
                  _SearchView(), // Index 2 (Skipped via swipe logic)
                  FavoritesScreen(), // Index 3
                ],
              ),
            ),
          ),

          // Bottom Navigation
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: _SplitLiquidNavigation(
                currentSong: currentSong,
                isScrolling: _isScrolling,
                selectedTab: _selectedTab,
                onTabChanged: _onTabTapped,
                screenWidth: size.width,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 2. LIBRARY VIEW (UPDATED - CLEAN LOOK)
// ==============================================================================
class _LibraryView extends ConsumerStatefulWidget {
  const _LibraryView();
  @override
  ConsumerState<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<_LibraryView>
    with AutomaticKeepAliveClientMixin {
  // Keep state alive so tab doesn't reload when swiping away
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(songsProvider.notifier).refreshSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive
    final allSongs = ref.watch(songsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.read(songsProvider.notifier).refreshSongs(),
      color: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF1F2937),
      edgeOffset: 140,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
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
                "Your Library",
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
                    colors: [Color(0xFF1E1E2C), Color(0xFF0A0A0A)],
                  ),
                ),
              ),
            ),
          ),

          if (allSongs.isNotEmpty)
            SliverList.builder(
              itemCount: allSongs.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: SongTile(song: allSongs[index]),
              ),
            )
          else
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  "Empty Library",
                  style: TextStyle(color: Colors.white30),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 180)),
        ],
      ),
    );
  }
}

// ==============================================================================
// 3. SEARCH VIEW
// ==============================================================================
class _SearchView extends ConsumerStatefulWidget {
  const _SearchView();

  @override
  ConsumerState<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<_SearchView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Only request focus if this tab was explicitly selected via tap,
    // not just rendered in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Optional: Auto-focus logic can go here if desired
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(filteredSongsProvider);

    ref.listen<LocalSong?>(currentSongProvider, (previous, next) {
      if (previous?.path != next?.path && next != null) {
        ref.read(searchQueryProvider.notifier).state = '';
      }
    });

    if (_controller.text != query) {
      _controller.text = query;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: query.length),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: _BigHeader(title: "Search")),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: (val) =>
                    ref.read(searchQueryProvider.notifier).state = val,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: const Color(0xFF6366F1),
                decoration: InputDecoration(
                  hintText: "Songs, Artists, Lyrics",
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            _controller.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                            _focusNode.requestFocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        ),

        if (query.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.manage_search_rounded,
                    size: 60,
                    color: Colors.white10,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Play what you love",
                    style: TextStyle(color: Colors.white38, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Search your library",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else if (results.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                "No matches found",
                style: TextStyle(color: Colors.white38, fontSize: 18),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: results.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SongTile(song: results[index]),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 180)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SPLIT LIQUID GLASS NAVIGATION
// -----------------------------------------------------------------------------
class _SplitLiquidNavigation extends ConsumerStatefulWidget {
  final LocalSong? currentSong;
  final bool isScrolling;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final double screenWidth;

  const _SplitLiquidNavigation({
    required this.currentSong,
    required this.isScrolling,
    required this.selectedTab,
    required this.onTabChanged,
    required this.screenWidth,
  });

  @override
  ConsumerState<_SplitLiquidNavigation> createState() =>
      _SplitLiquidNavigationState();
}

class _SplitLiquidNavigationState
    extends ConsumerState<_SplitLiquidNavigation> {
  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final bool hasSong = widget.currentSong != null;
    final bool hideNav = widget.isScrolling && hasSong;

    const duration = Duration(milliseconds: 450);
    const curve = Curves.easeOutCubic;

    final double horizontalMargin = widget.screenWidth * 0.05;

    return AnimatedPadding(
      duration: duration,
      curve: curve,
      padding: EdgeInsets.only(
        left: horizontalMargin,
        right: horizontalMargin,
        bottom: bottomPadding + (hideNav ? 0 : 16),
      ),
      child: LiquidGlassLayer(
        settings: LiquidGlassSettings(
          thickness: 20.0,
          blur: 10.0,
          refractiveIndex: 1.6,
          lightIntensity: BorderSide.strokeAlignCenter,
          lightAngle: pi / 4,
        ),
        child: LiquidGlassBlendGroup(
          blend: 18.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSong)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: hideNav ? 0.0 : 1.0),
                  duration: duration,
                  curve: curve,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: 1.0 - (0.15 * (1 - scale)),
                      child: Opacity(
                        opacity: scale,
                        child: AnimatedAlign(
                          duration: duration,
                          curve: curve,
                          alignment: hideNav
                              ? Alignment.bottomCenter
                              : Alignment.topCenter,
                          child: Container(
                            height: 70,
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: hideNav ? 0 : 14),
                            child: LiquidGlass.grouped(
                              shape: LiquidRoundedSuperellipse(
                                borderRadius: 36,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(36),
                                  border: Border.all(
                                    color: Colors.white10,
                                    width: 0.8,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: MiniPlayer(shrunk: false),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1.0, end: hideNav ? 0.0 : 1.0),
                duration: duration,
                curve: curve,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, (1 - value) * 80),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Container(
                  height: 64,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: LiquidGlass.grouped(
                          shape: LiquidRoundedSuperellipse(borderRadius: 32),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white12,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _NavIcon(
                                  icon: Icons.library_music_rounded,
                                  label: 'Library',
                                  isSelected: widget.selectedTab == 0,
                                  onTap: () => widget.onTabChanged(0),
                                ),
                                _NavIcon(
                                  icon: Icons.explore_rounded,
                                  label: 'Explore',
                                  isSelected: widget.selectedTab == 3,
                                  onTap: () => widget.onTabChanged(3),
                                ),
                                _NavIcon(
                                  icon: Icons.favorite_rounded,
                                  label: 'Likes',
                                  isSelected: widget.selectedTab == 1,
                                  onTap: () => widget.onTabChanged(1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: GestureDetector(
                          onTap: () => widget.onTabChanged(2),
                          child: LiquidGlass.grouped(
                            shape: LiquidRoundedSuperellipse(borderRadius: 32),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white12,
                                  width: 0.8,
                                ),
                                color: widget.selectedTab == 2
                                    ? Colors.white.withOpacity(0.18)
                                    : Colors.transparent,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.search_rounded,
                                  color: widget.selectedTab == 2
                                      ? Colors.white
                                      : Colors.white60,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
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
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: LiquidStretch(
        stretch: 0.1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white54,
                size: 22,
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER CLASSES
// -----------------------------------------------------------------------------
class _GlobalBackground extends StatelessWidget {
  const _GlobalBackground();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A0A), Color(0xFF16161D), Color(0xFF0F0F1A)],
          ),
        ),
      ),
    );
  }
}

class _BigHeader extends StatelessWidget {
  final String title;
  const _BigHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
