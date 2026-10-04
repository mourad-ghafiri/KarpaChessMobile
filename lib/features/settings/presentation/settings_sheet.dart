import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sound_providers.dart';
import '../../../core/audio/sound_service.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/media/avatar_store.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/theme/themes.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/danger_button.dart';
import '../../../core/ui/picker_strip.dart';
import '../../../progression/presentation/score_card.dart';
import '../../../prefs/application/prefs_controller.dart';
import '../../../progression/application/progression_controller.dart';
import '../../board/presentation/piece_sets.dart';
import 'settings_widgets.dart';

Future<void> showSettingsSheet(BuildContext context) {
  // Landscape phones (a 0.9 sheet over ~1200px of content is 3.6
  // screenfuls) and every tablet window get a centered dialog instead — the
  // iPad mini in portrait included, where a 720dp sheet was a phone's sheet
  // stretched to the window's edges.
  //
  // The route type has to be chosen before the route exists, so this is the
  // one place that reads a size outside a `LayoutBuilder` — but it asks
  // `LayoutSpec` rather than re-deriving the thresholds, which is how the
  // hand-rolled copy here had already lost the `width > height` term.
  final size = MediaQuery.sizeOf(context);
  final safeHeight = size.height - MediaQuery.viewPaddingOf(context).vertical;
  final spec = LayoutSpec.fromSize(size);
  if (spec.landscapeCompact || spec.tablet) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        // Its own width, not the tablet cap every other dialog takes.
        constraints: const BoxConstraints(
          minWidth: 280,
          maxWidth: ContentWidth.form,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ContentWidth.form,
            maxHeight: safeHeight * 0.9,
          ),
          child: SingleChildScrollView(
            child: _SettingsContent(
              showClose: true,
              // A tablet's dialog has the room to show every choice at once.
              pickerColumns: spec.tablet ? _tabletPickerColumns : null,
            ),
          ),
        ),
      ),
    );
  }
  // The one sheet presenter, so settings gets the same width cap and
  // scrolling guarantees as every other sheet in the app.
  return showAppSheet<void>(context, builder: (_) => const _SettingsContent());
}

/// The settings surface: a centered, max-width column of calm sectioned
/// cards (profile, appearance, sound & feel, language, danger zone) —
/// hosted either by [showAppSheet] (the sheet scrolls and its drag handle
/// dismisses) or by the landscape/desktop dialog (which scrolls it itself
/// and shows a close button instead).
/// The tablet dialog's pickers: ten palettes and ten piece sets as two rows of
/// five, the five colorways as one — every choice in view, nothing clipped at
/// the edge.
const _tabletPickerColumns = 5;

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent({this.showClose = false, this.pickerColumns});

  /// The dialog host has no drag handle, so it gets a close button.
  final bool showClose;

  /// Lays the three appearance pickers out as grids of this many columns;
  /// null keeps them as strips (phones).
  final int? pickerColumns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsControllerProvider);
    final prefsCtl = ref.read(prefsControllerProvider.notifier);
    final i18n = ref.watch(i18nProvider).requireValue;
    final t = i18n.t;
    final tokens = context.tokens;
    final languageNames =
        ref.watch(languageNamesProvider).valueOrNull ?? const {};
    final pieceSet = PieceSetId.fromId(prefs.pieceSet);

    // A plain column: whichever host presents this owns the scrolling
    // (the sheet presenter's scroll view, or the dialog's).
    return Padding(
      padding: AppInsets.sheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('settings.title'),
                  style: context.type.displayAt(24, weight: FontWeight.w600),
                ),
              ),
              if (showClose)
                IconButton(
                  tooltip: t('ui.button.close'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- Profile strip ----
          const ScoreCard(),
          const SizedBox(height: AppSpacing.lg),

          // ---- Appearance ----
          SettingsSection(
            icon: Icons.palette_outlined,
            title: t('nbSettings.appearance'),
            children: [
              SettingsSubLabel(t('nbSettings.appTheme')),
              // On a phone both pickers are one swipeable row: a picker is a
              // filmstrip you scan sideways, and it keeps the whole
              // Appearance section to a fixed height however many palettes
              // ship. A tablet's dialog shows them all as grids.
              PickerStrip(
                columns: pickerColumns,
                children: [
                  for (final id in AppThemeId.values)
                    AppThemePreviewCard(
                      id: id,
                      label: t('nbSettings.appThemeName.${id.name}'),
                      selected: prefs.appTheme == id.name,
                      onTap: () {
                        ref.hapticSelection();
                        prefsCtl.setAppTheme(id.name);
                        // A theme is designed around a board. Adopting it
                        // moves the whole app, not one swatch — the colorway
                        // stays independently changeable just below.
                        prefsCtl.setBoardTheme(id.board.name);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SettingsSubLabel(t('settings.boardTheme')),
              PickerStrip(
                columns: pickerColumns,
                children: [
                  for (final theme in BoardColorTheme.values)
                    BoardThemePreviewCard(
                      theme: theme,
                      pieceAssets: pieceSet.assets,
                      label: t('nbSettings.themeName.${theme.name}'),
                      selected: prefs.boardTheme == theme.name,
                      onTap: () {
                        ref.hapticSelection();
                        prefsCtl.setBoardTheme(theme.name);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SettingsSubLabel(t('nbSettings.pieceSet')),
              // Each set on the reader's own colorway: pieces are judged
              // against the squares they will stand on.
              PickerStrip(
                columns: pickerColumns,
                children: [
                  for (final option in PieceSetId.values)
                    PieceSetPreviewCard(
                      pieceSet: option,
                      colorway: BoardColorTheme.fromId(prefs.boardTheme),
                      label: t('nbSettings.pieceSetName.${option.name}'),
                      selected: pieceSet == option,
                      onTap: () {
                        ref.hapticSelection();
                        prefsCtl.setPieceSet(option.name);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SettingsSubLabel(t('nbSettings.font')),
              Row(
                children: [
                  for (final (i, font) in AppFont.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: FontChoiceCard(
                        font: font,
                        label: t('nbSettings.fontName.${font.name}'),
                        selected: prefs.font == font.name,
                        onTap: () {
                          ref.hapticSelection();
                          prefsCtl.setFont(font.name);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SettingsToggle(
                label: t('settings.toggle.coords'),
                value: prefs.coords,
                onChanged: prefsCtl.setCoords,
              ),
              SettingsToggle(
                label: t('settings.toggle.legal'),
                value: prefs.legalHighlight,
                onChanged: prefsCtl.setLegalHighlight,
              ),
              SettingsToggle(
                label: t('settings.toggle.last'),
                value: prefs.lastMoveHighlight,
                onChanged: prefsCtl.setLastMoveHighlight,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- Sound & feel ----
          SettingsSection(
            icon: Icons.volume_up_outlined,
            title: t('nbSettings.soundFeel'),
            children: [
              Row(
                children: [
                  for (final (i, pack) in const [
                    ('wood', '🪵'),
                    ('plastic', '⚪'),
                    ('soft', '🔈'),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: SoundPackCard(
                        emoji: pack.$2,
                        label: t('nbSettings.soundPack.${pack.$1}'),
                        selected: prefs.soundPack == pack.$1,
                        onTap: () => _selectSoundPack(ref, pack.$1),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SettingsToggle(
                label: t('settings.toggle.sound'),
                value: prefs.sound,
                onChanged: prefsCtl.setSound,
              ),
              SettingsToggle(
                label: t('nbSettings.haptics'),
                value: prefs.haptics,
                onChanged: prefsCtl.setHaptics,
              ),
              SettingsToggle(
                label: t('settings.toggle.animations'),
                value: prefs.animations,
                onChanged: prefsCtl.setAnimations,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- Language ----
          SettingsSection(
            icon: Icons.language,
            title: t('settings.language'),
            children: [
              LanguagePicker(
                names: languageNames,
                selected: prefs.lang,
                onSelect: (lang) {
                  ref.hapticSelection();
                  prefsCtl.setLang(lang);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- About ----
          SettingsSection(
            icon: Icons.info_outline,
            title: t('settings.about'),
            children: [SettingsAbout(t: t)],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- Danger zone ----
          SettingsSection(
            icon: Icons.warning_amber_outlined,
            title: t('settings.dangerZone'),
            color: tokens.danger,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.danger,
                    side: BorderSide(color: tokens.dangerSoft),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(t('settings.resetBtn')),
                  onPressed: () => _confirmReset(context, ref, t),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Persists the pack, then previews it with a move + capture pair
  /// (skipped when the master sound switch is off).
  Future<void> _selectSoundPack(WidgetRef ref, String pack) async {
    ref.hapticSelection();
    await ref.read(prefsControllerProvider.notifier).setSoundPack(pack);
    ref.playSound(AppSound.move);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    ref.playSound(AppSound.capture);
  }

  Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref,
    String Function(String, [Map<String, Object?>?]) t,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('settings.dangerZone')),
        content: Text(t('settings.resetConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('ui.button.dismiss')),
          ),
          DangerButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('settings.resetBtn')),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(prefsControllerProvider.notifier).reset();
      await ref.read(progressionControllerProvider.notifier).reset();
      // The settings no longer point at the player's photo; the file goes
      // too, rather than lingering unseen in the app's storage. The privacy
      // notice promises exactly this.
      await ref.read(avatarStoreProvider).remove();
      if (context.mounted) Navigator.pop(context);
    }
  }
}
