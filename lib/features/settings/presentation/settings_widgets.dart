import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show PieceKind, Side;
import 'package:flutter/material.dart';

import '../../../core/app_info.dart';
import '../../../core/i18n/i18n_service.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/themes.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/surface.dart';
import '../../board/presentation/board_theme_mapper.dart';
import '../../board/presentation/piece_sets.dart';

/// A calm settings section: one [Surface] with a leading icon, a clear
/// header, and generously spaced content below.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.color,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  /// Header/icon tint; defaults to the theme accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final headerColor = color ?? tokens.accent;
    return Surface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: headerColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color ?? tokens.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

/// Small dim sub-label above an option row (e.g. "App theme").
class SettingsSubLabel extends StatelessWidget {
  const SettingsSubLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: context.tokens.textDim,
        ),
      ),
    );
  }
}

/// Compact switch row used inside settings sections.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // A ListTile paints its ink on the nearest Material, and the section's
    // Surface card is an opaque box above that one — so without its own
    // (transparent) Material the tap ripple was drawn underneath the card.
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }
}

/// Large live-preview card for one full app theme.
///
/// It renders the theme's real page, a real card drawn through
/// [AppTokens.surfaceAt] — shadow, hairline and sheen included — and the
/// framed board in the colorway the theme was designed around. Depth is now
/// most of what separates one theme from another, so a preview that showed
/// only flat swatches would no longer show what you are choosing.
class AppThemePreviewCard extends StatelessWidget {
  const AppThemePreviewCard({
    super.key,
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppThemeId id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final AppTokens preview = AppThemes.of(id);
    final board = id.board;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enter,
          width: 120,
          height: 104,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: preview.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? tokens.accent : tokens.edge,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A real card on the theme's real page: this is the step the
              // whole rework is about.
              Container(
                padding: const EdgeInsets.all(5),
                decoration:
                    preview.surfaceAt(Elevation.card).decoration(8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: preview.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: preview.raised,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _MiniBoard(colorway: board),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: preview.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 2x2 board in its bezel — the theme preview's stand-in for [BoardStage].
class _MiniBoard extends StatelessWidget {
  const _MiniBoard({required this.colorway});

  final BoardColorTheme colorway;

  @override
  Widget build(BuildContext context) {
    Widget squares(Color a, Color b) => Expanded(
          child: Row(children: [
            Expanded(child: ColoredBox(color: a)),
            Expanded(child: ColoredBox(color: b)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colorway.bezel,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: colorway.bezelShadow.withValues(alpha: 0.45),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Column(
          children: [
            squares(colorway.lightSquare, colorway.darkSquare),
            squares(colorway.darkSquare, colorway.lightSquare),
          ],
        ),
      ),
    );
  }
}

/// Real mini chessboard preview (an actual position with pieces) for one
/// board colorway, drawn with the reader's own piece set, with the localized
/// name underneath.
class BoardThemePreviewCard extends StatelessWidget {
  const BoardThemePreviewCard({
    super.key,
    required this.theme,
    required this.pieceAssets,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Italian-game position used by every preview so colorways compare fairly.
  static const previewFen =
      'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 0 1';

  /// The preview board's edge. [PieceSetPreviewCard] draws at the same size,
  /// so the two strips in Appearance line up card for card.
  static const double boardSize = 88;

  final BoardColorTheme theme;

  /// The reader's pieces, so a colorway is previewed with what it will
  /// actually carry.
  final PieceAssets pieceAssets;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BoardPreviewFrame(
      label: label,
      selected: selected,
      onTap: onTap,
      child: StaticChessboard(
        size: boardSize,
        fen: previewFen,
        orientation: Side.white,
        settings: StaticChessboardSettings(
          colorScheme: boardColorScheme(theme, context.tokens),
          pieceAssets: pieceAssets,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          animationDuration: Duration.zero,
        ),
      ),
    );
  }
}

/// One piece set, previewed on the reader's own colorway: a 2x2 corner of
/// board holding the pieces whose drawing differs most between sets — both
/// knights, a king and a queen — at four times the size a full-board preview
/// could give them.
class PieceSetPreviewCard extends StatelessWidget {
  const PieceSetPreviewCard({
    super.key,
    required this.pieceSet,
    required this.colorway,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Rank by rank from the top, as a board is read.
  static const _pieces = [
    [PieceKind.blackKing, PieceKind.blackKnight],
    [PieceKind.whiteKnight, PieceKind.whiteQueen],
  ];

  final PieceSetId pieceSet;
  final BoardColorTheme colorway;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const square = BoardThemePreviewCard.boardSize / 2;
    final assets = pieceSet.assets;
    return _BoardPreviewFrame(
      label: label,
      selected: selected,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (rank, row) in _pieces.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (file, kind) in row.indexed)
                    ColoredBox(
                      color: (rank + file).isEven
                          ? colorway.lightSquare
                          : colorway.darkSquare,
                      child: Image(
                        image: assets[kind]!,
                        width: square,
                        height: square,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The frame both board previews wear: a hairline that takes the accent
/// while it is the current choice, and the name underneath. A colorway and a
/// piece set are chosen one strip apart, so their cards share one frame.
///
/// Like [SettingsChoiceFrame], it is one node to a screen reader: [label] is
/// announced once as a selectable button, and the preview beneath it (a
/// position, four pieces) is decoration, not read out square by square.
class _BoardPreviewFrame extends StatelessWidget {
  const _BoardPreviewFrame({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enter,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: selected ? tokens.accent : tokens.edge,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? tokens.accent : tokens.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The frame every settings choice card wears: a `raised` control on a
/// hairline that takes the accent (soft fill, accent edge) while it is the
/// current choice.
///
/// Sound packs, typefaces and languages all draw through it, so the pickers
/// in one sheet cannot drift apart a border width at a time. They had
/// already started to: sound packs selected at 2, typefaces at 1.6.
///
/// It is also one node to a screen reader. [label] is announced once as a
/// selectable button, and what the card shows beneath it (a glyph, a flag,
/// a sample move) is not read out a second time.
class SettingsChoiceFrame extends StatelessWidget {
  const SettingsChoiceFrame({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.padding,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enter,
          padding: padding,
          decoration: BoxDecoration(
            color: selected ? tokens.accentSoft : tokens.raised,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: selected ? tokens.accent : tokens.edge,
              width: selected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// One sound-pack choice: an emoji glyph over a label.
class SoundPackCard extends StatelessWidget {
  const SoundPackCard({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SettingsChoiceFrame(
      label: label,
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? tokens.text : tokens.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Typeface choice: the label is drawn in the face it selects, so the card
/// previews the decision rather than describing it.
class FontChoiceCard extends StatelessWidget {
  const FontChoiceCard({
    super.key,
    required this.font,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppFont font;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SettingsChoiceFrame(
      label: label,
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nf3',
            style: TextStyle(
              fontFamily: font.display,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: selected ? tokens.accent : tokens.text,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? tokens.accent : tokens.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// One language in the switcher: its flag beside its own name, in the frame
/// every settings choice shares.
///
/// The name is the endonym («Português», «العربية»), so readers can find
/// their own language whatever the app is currently speaking. It keeps one
/// weight and one color whether or not it is selected, because a name that
/// turned bold when chosen would re-wrap under the reader's finger.
class LanguageChoiceCard extends StatelessWidget {
  const LanguageChoiceCard({
    super.key,
    required this.flag,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  /// The narrowest a card may be at 1× text. It fits the padding, the flag
  /// and the longest single word of any name («Português», «Indonesia») on
  /// one line. [LanguagePicker] scales it to the reader's text size.
  static const double minWidth = 128;

  /// The card's height at 1× text. It holds a name on two lines («Bahasa
  /// Indonesia») and clears the 44dp tap target. [LanguagePicker] scales it
  /// through `slotHeightFor`.
  static const double height = 56;

  final String flag;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsChoiceFrame(
      label: name,
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // The sound-pack cards' glyph idiom: an emoji at 22, which every
          // target platform draws as the real flag.
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.type.body.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: context.tokens.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The language switcher: every supported language as a
/// [LanguageChoiceCard], laid out the way the app lays out its other choice
/// grids (the Play personas, the puzzle packs).
///
/// All twelve are on screen at once. A language is chosen rarely and by
/// reading its name, not by comparing previews. That is the opposite of a
/// theme, and why this is a grid rather than a `PickerStrip`.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    required this.names,
    required this.selected,
    required this.onSelect,
  });

  /// Each language's own name, by code. A missing name shows its code.
  final Map<String, String> names;

  /// The code of the language in use.
  final String selected;

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // The delegate lays out ceil(width / extent) columns, so no card is ever
    // narrower than half the extent. An extent of twice the narrowest card
    // therefore guarantees that minimum. The result is two columns on phones
    // 360dp and up, three in the wide dialog, and one column on a small phone
    // at the largest text size, where two would split «Português» mid-word.
    final minWidth =
        MediaQuery.textScalerOf(context).scale(LanguageChoiceCard.minWidth);
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // A null padding would pull the MediaQuery padding into the grid.
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 2 * minWidth,
        mainAxisSpacing: AppInsets.gridGap,
        crossAxisSpacing: AppInsets.gridGap,
        mainAxisExtent: slotHeightFor(
          context,
          LanguageChoiceCard.height,
          minimum: LanguageChoiceCard.height,
        ),
      ),
      children: [
        for (final lang in I18nService.supportedLangs)
          LanguageChoiceCard(
            flag: I18nService.flagFor(lang),
            name: names[lang] ?? lang,
            selected: selected == lang,
            onTap: () => onSelect(lang),
          ),
      ],
    );
  }
}

/// Settings › About: what this build is, the license it ships under and
/// where its source is published, and Flutter's open-source licenses page.
///
/// KarpaChess embeds GPL-3.0 code (Stockfish, chessground, dartchess), so
/// the app itself is GPL-3.0-or-later; stating that — with the source
/// address — inside the app is part of distributing it. The address is
/// selectable text rather than a link: the app has no network access and no
/// URL plugin, and a reader can still copy it.
class SettingsAbout extends StatelessWidget {
  const SettingsAbout({super.key, required this.t});

  final Translate t;

  static const _logo = 'assets/images/icon.png';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget logo(double size) => ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            _logo,
            width: size,
            height: size,
            // The asset is 1024px; decode it at the size it is drawn.
            cacheWidth: (size * dpr).round(),
            filterQuality: FilterQuality.medium,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            logo(40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppInfo.name, style: context.type.heading),
                  Text(
                    t('settings.version', {'version': AppInfo.version}),
                    style: context.type.caption.copyWith(
                      color: tokens.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SelectableText(
          t('settings.sourceNotice', {'url': AppInfo.sourceUrl}),
          style: context.type.caption.copyWith(
            color: tokens.textDim,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(t('settings.licenses')),
              onPressed: () => showLicensePage(
                context: context,
                applicationName: AppInfo.name,
                applicationVersion: AppInfo.version,
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: logo(48),
                ),
                applicationLegalese:
                    '${AppInfo.copyright} · ${AppInfo.license}',
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.privacy_tip_outlined, size: 18),
              label: Text(t('settings.privacy')),
              onPressed: () => _showPrivacy(context),
            ),
          ],
        ),
      ],
    );
  }

  /// The privacy notice, in the reader's language, with the address of the
  /// full policy. Both stores require the policy, and Apple requires it to be
  /// reachable inside the app (Guideline 5.1.1(i)). The app has no network
  /// access, so the notice itself is here rather than behind a link.
  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('settings.privacy')),
        content: SingleChildScrollView(
          child: SelectableText(
            t('settings.privacyBody', {'url': AppInfo.privacyUrl}),
            style: context.type.body.copyWith(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('ui.button.close')),
          ),
        ],
      ),
    );
  }
}
