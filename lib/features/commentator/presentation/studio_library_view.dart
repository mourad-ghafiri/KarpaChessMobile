import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/domain/models.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/danger_button.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/nav_card.dart';
import '../../../core/ui/picker_strip.dart';
import '../application/commentator_controller.dart';
import '../application/imported_games_controller.dart';
import 'game_card.dart';
import 'studio_import_sheet.dart';

/// The Studio's landing view: the study library, its filters, and the button
/// that brings a game of your own into it.
///
/// One column at a reading measure on phones. Expanded-and-up windows take
/// the wide cap: the search and the import invitation share a row, and the
/// games lay out as a card grid — a 648dp single-column list in a 1400dp
/// window was two-thirds empty screen. (An older `landscapeCompact` fork
/// put a paste form beside a narrow rail; the paste form lives in a sheet
/// now, and this fork is about width, not shortness.)
class StudioLibraryView extends ConsumerStatefulWidget {
  const StudioLibraryView({super.key});

  @override
  ConsumerState<StudioLibraryView> createState() => _StudioLibraryViewState();
}

class _StudioLibraryViewState extends ConsumerState<StudioLibraryView> {
  final _search = TextEditingController();

  /// Shelf currently filtering the list; null is "everything".
  String? _shelf;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The library narrowed by the shelf chip and the search box. Both are plain
  /// predicates over the loaded list — a few hundred games is small enough
  /// that filtering per keystroke costs nothing, and an index would be a cache
  /// to keep honest for no gain.
  List<StudyGame> _visible(StudyLibrary library) {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final game in library.games)
        if ((_shelf == null || game.shelf == _shelf) &&
            (query.isEmpty || game.searchText.contains(query)))
          game,
    ];
  }

  void _open(StudyGame game) {
    ref.read(commentatorControllerProvider.notifier).loadPgn(game.toPgn());
  }

  Future<void> _confirmRemove(StudyGame game, Translate t) async {
    final removed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('commentator.removeGame')),
        content: Text(t('commentator.removeGameBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('ui.button.dismiss')),
          ),
          DangerButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('commentator.remove')),
          ),
        ],
      ),
    );
    if (removed ?? false) {
      await ref.read(importedGamesProvider.notifier).remove(game.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider).requireValue;
    final t = i18n.t;
    final tokens = context.tokens;
    final library = ref.watch(studyLibraryProvider).valueOrNull;
    final games = library == null ? const <StudyGame>[] : _visible(library);

    // The tab's page title, in the `display` role the Learn, Play and
    // Puzzles homes give theirs — at `title` it read as a section heading
    // of some page whose title was missing.
    final header = Text(
      t('commentator.sampleGames'),
      style: context.type.display,
    );

    // Fill, hairline and focus ring come from the theme's one field style.
    final search = TextField(
      controller: _search,
      style: context.type.body.copyWith(color: tokens.text),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: t('commentator.searchGames'),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                // The framework's own "Clear text", localized in all twelve
                // languages — a screen reader announces the button's job.
                tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
                icon: const Icon(Icons.close, size: 18),
                onPressed: _search.clear,
              ),
      ),
    );

    final shelves = SizedBox(
      height: 44,
      child: PickerStrip(
        children: [
          _ShelfChip(
            label: t('commentator.allGames'),
            selected: _shelf == null,
            onTap: () => setState(() => _shelf = null),
          ),
          // Only once there is something on it: an empty shelf is not a
          // filter, it is a dead end.
          if ((library?.importedCount ?? 0) > 0)
            _ShelfChip(
              label: t('commentator.myGames'),
              selected: _shelf == importedShelf,
              onTap: () => setState(() => _shelf = importedShelf),
            ),
          for (final collection in library?.collections ?? const [])
            _ShelfChip(
              label: collection.player,
              selected: _shelf == collection.id,
              onTap: () => setState(() => _shelf = collection.id),
            ),
        ],
      ),
    );

    // Pinned rather than the first row of the list: importing is the one
    // thing a reader does TO this screen, so it should not scroll away, and it
    // should not be a small button fighting the title for width.
    final importTile = _ImportTile(
      t: t,
      onTap: () => showStudioImportSheet(context),
    );

    Widget gameAt(int index) {
      final game = games[index];
      return GameCard(
        game: game,
        t: t,
        p: i18n.plural,
        onTap: () => _open(game),
        // Only the reader's own games can be removed; the bundled
        // corpus is not theirs to prune.
        onRemove: game.shelf == importedShelf
            ? () => _confirmRemove(game, t)
            : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = LayoutSpec.of(constraints);
        final wide = spec.windowClass.atLeastExpanded;
        // A tablet's home pages share one gutter — Learn, Puzzles and Play
        // take `AppInsets.pageFor` — while phones keep the library's own.
        final inset = spec.tablet ? AppSpacing.xl : AppSpacing.lg;

        final list = library == null
            ? const Center(child: CircularProgressIndicator())
            : games.isEmpty
            ? EmptyState(
                icon: Icons.search_off,
                message: t('commentator.noGames'),
              )
            : wide
            // The wide branch deals the self-sizing row cards into
            // fixed-extent grid cells — three ~340dp columns at the
            // wide cap.
            ? GridView.builder(
                padding: EdgeInsetsDirectional.fromSTEB(
                  inset,
                  0,
                  inset,
                  AppSpacing.lg,
                ),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  // Covers the card — monogram row vs title + a
                  // two-line byline — at the largest text scale.
                  mainAxisExtent: slotHeightFor(context, 84, minimum: 76),
                  mainAxisSpacing: AppInsets.gridGap,
                  crossAxisSpacing: AppInsets.gridGap,
                ),
                itemCount: games.length,
                itemBuilder: (context, index) => gameAt(index),
              )
            : ListView.separated(
                padding: EdgeInsetsDirectional.fromSTEB(
                  inset,
                  0,
                  inset,
                  AppSpacing.lg,
                ),
                itemCount: games.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppInsets.gridGap),
                itemBuilder: (context, index) => gameAt(index),
              );

        return Center(
          // The shelf strip may bleed across the column's gutter, never past
          // the column: where the column is narrower than the window (a
          // landscape tablet) the chips used to run on into the margin.
          child: ClipRect(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide ? ContentWidth.wide : ContentWidth.reading,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      inset,
                      AppSpacing.lg,
                      inset,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: AppSpacing.md),
                        if (wide)
                          // Search and the import invitation share the row the
                          // width affords; the tile keeps card presence at a
                          // fixed measure instead of stretching across 1000dp.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: search),
                              const SizedBox(width: AppSpacing.lg),
                              SizedBox(width: 340, child: importTile),
                            ],
                          )
                        else ...[
                          search,
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        shelves,
                        if (!wide) ...[
                          const SizedBox(height: AppSpacing.sm),
                          importTile,
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(child: list),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One shelf in the filter strip. A chip, not a card: it names a filter rather
/// than previewing anything.
class _ShelfChip extends StatelessWidget {
  const _ShelfChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // 44dp of tap target around a 34dp pill, the same trick the drawing
    // bar's buttons use: the chip stays visually light without becoming a
    // target you have to aim at.
    final fill = selected
        ? Color.alphaBlend(tokens.accentSoft, tokens.raised)
        : tokens.raised;
    return Semantics(
      button: true,
      selected: selected,
      child: SizedBox(
      height: 44,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: selected ? tokens.accent : tokens.edge),
          ),
          child: Text(
            label,
            style: context.type.label.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? tokens.legible(tokens.accent, on: fill)
                  : tokens.textDim,
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// The way into the import sheet: a full-width invitation, not a button.
class _ImportTile extends StatelessWidget {
  const _ImportTile({required this.t, required this.onTap});

  final Translate t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NavCard(
    icon: Icons.add,
    title: t('commentator.importTitle'),
    subtitle: t('commentator.importTileBlurb'),
    emphasized: true,
    onTap: onTap,
  );
}
