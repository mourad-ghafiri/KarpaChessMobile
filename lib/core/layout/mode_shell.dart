import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/commentator/application/commentator_controller.dart';
import '../../features/commentator/presentation/studio_screen.dart';
import '../../features/academy/presentation/academy_screen.dart';
import '../../features/practice/application/practice_controller.dart';
import '../../features/play/presentation/play_screen.dart';
import '../../features/puzzles/presentation/puzzles_screen.dart';
import '../../features/settings/presentation/settings_sheet.dart';
import '../i18n/i18n_providers.dart';
import '../theme/motion.dart';
import 'window_class.dart';

/// The modes of the app, in the order the nav shows them.
///
/// Declaration order IS the tab order — `AppTab.values` drives both the
/// destinations and the screen stack. Nothing stores a tab by index, so this
/// list can be reordered freely; every reference is by name.
enum AppTab { learn, play, puzzles, studio }

/// Everything a mode contributes to the shell.
typedef _Mode = ({
  IconData icon,
  IconData selectedIcon,
  String labelKey,
  Widget screen,
});

/// One exhaustive switch, so the nav destinations and the screen stack can
/// never fall out of step. They used to be two parallel lists that had to
/// stay index-aligned with [AppTab.values] by hand, with nothing enforcing
/// it; now adding a mode is a compile error until it is described here.
_Mode _modeOf(AppTab tab) => switch (tab) {
      AppTab.learn => (
          icon: Icons.school_outlined,
          selectedIcon: Icons.school,
          labelKey: 'academy.nav',
          screen: const AcademyScreen(),
        ),
      AppTab.play => (
          icon: Icons.sports_esports_outlined,
          selectedIcon: Icons.sports_esports,
          labelKey: 'play.nav',
          screen: const PlayScreen(),
        ),
      AppTab.puzzles => (
          icon: Icons.extension_outlined,
          selectedIcon: Icons.extension,
          labelKey: 'puzzles.nav',
          screen: const PuzzlesScreen(),
        ),
      AppTab.studio => (
          // A branching tree. `theaters` was left over from the commentary
          // booth this used to be, and a book only said "reading", which every
          // other tab could claim too. The move tree is what the Studio is
          // actually built around — you step through a master game and fork
          // side lines off it, and `BoardStage.sideline` recolours the bezel
          // the moment you leave the line that was played. Nothing else in the
          // app branches, so it cannot be read as another tab.
          icon: Icons.account_tree_outlined,
          selectedIcon: Icons.account_tree,
          labelKey: 'studio.nav',
          screen: const StudioScreen(),
        ),
    };

final activeTabProvider = StateProvider<AppTab>((ref) => AppTab.learn);

/// Nightboard shell: translucent top bar with brand + settings, adaptive
/// navigation (bottom bar on phones, rail on tablets), and an IndexedStack
/// so each mode keeps its state while hidden.
class ModeShell extends ConsumerWidget {
  const ModeShell({super.key});

  /// Keeps every mode alive across a layout change.
  ///
  /// The bottom-bar and rail branches below are structurally different trees
  /// — `SafeArea > stack` against `SafeArea > Row > … > Expanded > stack` —
  /// so on rotation Flutter cannot reuse the element at that position and
  /// tears the whole tab subtree down. A `GlobalKey` makes it *reparent* the
  /// subtree instead, which is the difference between rotating the phone and
  /// losing whatever each mode was in the middle of.
  static final _stackKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(activeTabProvider);
    final i18n = ref.watch(i18nProvider).requireValue;

    // A live board takes the whole window. Learn and Puzzles push their
    // boards as fullscreen routes; Play and Studio are tabs, so without
    // this their boards sat under the app bar AND the bottom bar — ~136dp
    // shorter, which clamped the square visibly narrower than the other
    // modes. While the active tab shows a game, both bars yield and the
    // board maths land on the same width-bound size as everywhere else;
    // the in-game `ModeHeaderBar` (close / new game) is the way back out,
    // and ending the game brings the bars home.
    final inGame = switch (tab) {
      AppTab.play => ref.watch(
        practiceControllerProvider.select(
          (s) => s.status == PracticeStatus.active,
        ),
      ),
      AppTab.studio => ref.watch(
        commentatorControllerProvider.select((s) => s.hasGame),
      ),
      _ => false,
    };

    final modes = [for (final t in AppTab.values) _modeOf(t)];

    // TickerMode silences hidden tabs' animations: an IndexedStack keeps
    // every child alive, and without it an off-screen ticker (thinking
    // dots, pulsing highlights) would keep firing at 60fps.
    final stack = _TabTransition(
      key: _stackKey,
      index: tab.index,
      child: IndexedStack(
        index: tab.index,
        children: [
          for (var i = 0; i < modes.length; i++)
            TickerMode(enabled: i == tab.index, child: modes[i].screen),
        ],
      ),
    );

    final appBar = AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The real launcher icon (capped knight, gen_icon.py), so the
          // header and the home screen wear the same mark.
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/images/icon.png',
              width: 26,
              height: 26,
              // The asset is 1024px: decoded at full size it held ~4 MB of
              // memory to draw a 26dp mark.
              cacheWidth: (26 * MediaQuery.devicePixelRatioOf(context)).round(),
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: 8),
          Text(i18n.t('ui.brand.title')),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: i18n.t('ui.button.settings'),
          onPressed: () => showSettingsSheet(context),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = LayoutSpec.of(constraints);
        final windowClass = spec.windowClass;
        // Labelled rows only where the width is genuinely spare: a 13" iPad
        // in landscape is 1376dp, and a 168dp rail there came straight out
        // of the in-game board.
        final extendedRail = constraints.maxWidth >= WindowClass.extendedRailAt;
        // Landscape phones: a dense rail preserves board height; the bottom
        // bar would steal ~64dp of the short axis.
        if (windowClass.isCompact && !spec.landscapeCompact) {
          return Scaffold(
            appBar: inGame ? null : appBar,
            body: SafeArea(child: stack),
            bottomNavigationBar: inGame
                ? null
                : NavigationBar(
                    selectedIndex: tab.index,
                    onDestinationSelected: (i) => ref
                        .read(activeTabProvider.notifier)
                        .state = AppTab.values[i],
                    destinations: [
                      for (final mode in modes)
                        NavigationDestination(
                          icon: Icon(mode.icon),
                          selectedIcon: Icon(mode.selectedIcon),
                          label: i18n.t(mode.labelKey),
                        ),
                    ],
                  ),
          );
        }
        return Scaffold(
          // Landscape phones skip the app bar entirely — the settings gear
          // moves into the rail so the board keeps the full height. In-game
          // it goes on every window; the rail stays, since it costs width
          // (which these branches have) rather than board height.
          appBar: spec.landscapeCompact || inGame ? null : appBar,
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  trailing: spec.landscapeCompact
                      ? Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: IconButton(
                                icon: const Icon(Icons.settings_outlined),
                                tooltip: i18n.t('ui.button.settings'),
                                onPressed: () => showSettingsSheet(context),
                              ),
                            ),
                          ),
                        )
                      : null,
                  selectedIndex: tab.index,
                  onDestinationSelected: (i) =>
                      ref.read(activeTabProvider.notifier).state =
                          AppTab.values[i],
                  extended: extendedRail,
                  // An extended rail carries its labels beside the icons;
                  // both switch on the same test so no rail loses them.
                  labelType: spec.landscapeCompact || extendedRail
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  minWidth: spec.landscapeCompact ? 56 : 72,
                  minExtendedWidth: 168,
                  destinations: [
                    for (final mode in modes)
                      NavigationRailDestination(
                        icon: Icon(mode.icon),
                        selectedIcon: Icon(mode.selectedIcon),
                        label: Text(i18n.t(mode.labelKey)),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: stack),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fades and lifts the mode stack whenever the tab changes.
///
/// A plain [IndexedStack] swaps modes between one frame and the next, which
/// reads as a glitch rather than a navigation. The animation wraps the stack
/// instead of replacing it, so every mode keeps the state it was holding.
class _TabTransition extends StatefulWidget {
  const _TabTransition({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<_TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<_TabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.base,
    value: 1,
  );

  @override
  void didUpdateWidget(_TabTransition old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Motion.enter);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}
