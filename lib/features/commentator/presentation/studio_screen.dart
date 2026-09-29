import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/mode_shell.dart';
import '../application/commentator_controller.dart';
import 'studio_library_view.dart';
import 'studio_recap_sheet.dart';
import 'studio_study_view.dart';

/// Commentator Studio: the study library when no game is loaded, otherwise
/// the board-first study view. Also owns the recap modal lifecycle — the
/// controller opens the recap state (manually or automatically at the end of
/// a finished game) and this screen presents/dismisses the sheet — and the
/// visibility catch-up: engine work is suspended while the Studio tab is
/// hidden, so activating the tab kicks any pending analysis and presents a
/// recap that arrived in the background.
class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  bool _recapSheetOpen = false;

  void _onRecapChanged(RecapState? previous, RecapState? next) {
    if (previous != null || next == null) return;
    _maybeShowRecapSheet();
  }

  void _onTabChanged(AppTab? previous, AppTab next) {
    if (next != AppTab.studio) return;
    ref.read(commentatorControllerProvider.notifier).ensureCurrentAnalyzed();
    _maybeShowRecapSheet();
  }

  /// Presents the recap sheet — but only while the Studio tab is visible.
  /// A recap opening on a hidden tab stays pending in state and is shown by
  /// [_onTabChanged] on the next activation.
  void _maybeShowRecapSheet() {
    if (_recapSheetOpen) return;
    if (ref.read(activeTabProvider) != AppTab.studio) return;
    if (ref.read(commentatorControllerProvider).recap == null) return;
    _recapSheetOpen = true;
    showStudioRecapSheet(context).whenComplete(() {
      _recapSheetOpen = false;
      if (mounted) {
        ref.read(commentatorControllerProvider.notifier).closeRecap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RecapState?>(
      commentatorControllerProvider.select((s) => s.recap),
      _onRecapChanged,
    );
    ref.listen<AppTab>(activeTabProvider, _onTabChanged);
    final hasGame = ref.watch(
      commentatorControllerProvider.select((s) => s.hasGame),
    );
    return hasGame ? const StudioStudyView() : const StudioLibraryView();
  }
}
