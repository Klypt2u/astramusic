import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

/// Bottom-tab shell: Home / Search / Library with a mini player pinned
/// above the navigation bar. The Now Playing screen is pushed on top as a
/// full-screen route, so audio state persists across navigation.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _pages = [HomeScreen(), SearchScreen(), LibraryScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AstraTheme.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            for (final page in _pages)
              Padding(
                // Reserve space for the mini player above the nav bar.
                padding: const EdgeInsets.only(bottom: 0),
                child: page,
              ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(), // auto-hides when nothing is queued
          _NavigationBar(
            current: _index,
            onSelect: (i) => setState(() => _index = i),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Custom bottom nav matching Lyra's flat, icon-first aesthetic.
class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.search_rounded, 'Search'),
    (Icons.library_music_rounded, 'Library'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AstraTheme.background.withOpacity(0.98),
        border: Border(
          top: BorderSide(
            color: AstraTheme.textSecondary.withOpacity(0.08),
            width: 0.6,
          ),
        ),
      ),
      height: 62,
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkResponse(
                onTap: () => onSelect(i),
                radius: 30,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _items[i].$1,
                      size: 25,
                      color: current == i
                          ? AstraTheme.textPrimary
                          : AstraTheme.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _items[i].$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: current == i
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: current == i
                            ? AstraTheme.textPrimary
                            : AstraTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
