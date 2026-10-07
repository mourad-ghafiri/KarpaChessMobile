import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';
import '../../../core/i18n/translate.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/ui/app_sheet.dart';
import '../application/commentator_controller.dart';
import '../application/imported_games_controller.dart';
import '../domain/imported_game.dart';
import '../domain/move_tree.dart';
import 'game_card.dart';

/// Brings a game into the library.
///
/// Clipboard-first, because that is where a PGN actually comes from — you
/// copied it off a site a moment ago. The sheet checks, and if it is holding a
/// game it shows you the row you are about to add rather than an empty box and
/// a set of instructions.
///
/// Resolves once the sheet closes. A successful import has already been
/// persisted and opened in the studio by then.
Future<void> showStudioImportSheet(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const _StudioImportSheet());

class _StudioImportSheet extends ConsumerStatefulWidget {
  const _StudioImportSheet();

  @override
  ConsumerState<_StudioImportSheet> createState() => _StudioImportSheetState();
}

class _StudioImportSheetState extends ConsumerState<_StudioImportSheet> {
  final _pgn = TextEditingController();
  final _name = TextEditingController();

  /// A failure from the last Import press that parsing could not foresee (a
  /// store write that failed). Local to the sheet because it is only ever
  /// meaningful to the person looking at this field.
  String? _error;

  /// The last picked file was over [_maxImportBytes] and was not read.
  bool _tooLarge = false;

  /// Set once the clipboard has been read, so the sheet knows the difference
  /// between "nothing there" and "not looked yet".
  bool _checkedClipboard = false;

  /// True once the field has been still for [_settleDelay]. Why a text is not
  /// a game is only said then, so a move list typed by hand does not flash an
  /// error at every half-written move.
  bool _settled = true;
  Timer? _settleTimer;
  static const _settleDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _pgn.addListener(() {
      _settleTimer?.cancel();
      _settleTimer = Timer(_settleDelay, () {
        if (mounted) setState(() => _settled = true);
      });
      setState(() {
        _error = null;
        _tooLarge = false;
        _settled = false;
      });
    });
    _readClipboard();
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _pgn.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Peeks at the clipboard once, on open. It only ever fills an empty field,
  /// so it can never overwrite something the reader typed.
  Future<void> _readClipboard() async {
    // Guarded: the clipboard is a platform channel, and a host without one
    // must degrade to the paste field rather than throw into the void.
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on Object {
      data = null;
    }
    if (!mounted) return;
    final text = data?.text ?? '';
    setState(() {
      _checkedClipboard = true;
      if (_pgn.text.isEmpty && _preview(text) != null) _pgn.text = text;
    });
  }

  /// The game [text] describes, or null when it is not one.
  ImportedGame? _preview(String text) => _read(text).game;

  /// The game [text] describes, or why it is not one. Both null for a blank
  /// field, which is waiting rather than wrong.
  ///
  /// Built through the same factory the import uses, so what the preview shows
  /// is exactly what would be stored — including the name currently typed.
  ({ImportedGame? game, PgnImportError? problem}) _read(String text) {
    if (text.trim().isEmpty) return (game: null, problem: null);
    try {
      return (
        game: ImportedGame.fromTree(
          MoveTree.fromPgn(text),
          id: 'preview',
          name: _name.text,
          pgn: text,
          importedAt: DateTime.now(),
        ),
        problem: null,
      );
    } on PgnImportError catch (e) {
      return (game: null, problem: e);
    } on Object {
      return (
        game: null,
        problem: const PgnImportError(PgnProblem.unreadable, 'Unreadable'),
      );
    }
  }

  /// What to tell the reader about [problem], in their language.
  static String _describe(PgnImportError problem, Translate t) =>
      switch (problem.problem) {
        PgnProblem.unreadable => t('commentator.importUnreadable'),
        PgnProblem.noMoves => t('commentator.importNoMoves'),
        PgnProblem.illegalMove => t('commentator.importIllegalMove', {
            'move': problem.detail ?? '',
          }),
        PgnProblem.refusedPosition => t('commentator.importBadPosition'),
      };

  /// The largest file the field will take. A study is one game; a
  /// multi-megabyte database would freeze the field and re-parse on every
  /// keystroke, so it is refused with a message instead.
  static const _maxImportBytes = 1024 * 1024;

  Future<void> _pickFile() async {
    final String? path;
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pgn', 'txt'],
      );
      path = picked?.path;
    } on Object {
      return; // Picker unavailable — leave the field untouched.
    }
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.length() > _maxImportBytes) {
        if (mounted) setState(() => _tooLarge = true);
        return;
      }
      final text = _decodePgn(await file.readAsBytes());
      if (!mounted) return;
      setState(() {
        _pgn.text = text;
        _error = null;
        _tooLarge = false;
      });
    } on Exception {
      // Unreadable file — leave the field untouched.
    }
  }

  /// A PGN file's text. PGN predates Unicode, and files exported on Windows
  /// are often Latin-1, which a strict UTF-8 read rejects outright — the
  /// import then silently did nothing. UTF-8 is tried first (a byte-order
  /// mark dropped); Latin-1, which decodes any byte, is the fallback.
  static String _decodePgn(List<int> bytes) {
    final hasBom = bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;
    final body = hasBom ? bytes.sublist(3) : bytes;
    try {
      return utf8.decode(body);
    } on FormatException {
      return latin1.decode(body);
    }
  }

  /// Parses, persists, then opens. Nothing is stored unless it parses, so the
  /// library can never hold a game that will not open.
  Future<void> _import() async {
    try {
      final game = await ref.read(importedGamesProvider.notifier).import(
            pgn: _pgn.text,
            name: _name.text,
            now: DateTime.now(),
          );
      if (!mounted) return;
      ref.read(commentatorControllerProvider.notifier).loadPgn(game.pgn);
      Navigator.of(context).pop();
    } on PgnImportError {
      // The field already knows why; say it now rather than after the pause.
      setState(() => _settled = true);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } on Exception catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider).requireValue;
    final t = i18n.t;
    final tokens = context.tokens;
    final read = _read(_pgn.text);
    final preview = read.game;
    final problem = _settled ? read.problem : null;
    // Danger is chosen for cards; this sheet floats a plane higher.
    final errorInk = tokens.legible(
      tokens.danger,
      on: tokens.surfaceAt(Elevation.floating).fill,
    );

    return Padding(
      padding: AppInsets.sheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('commentator.importTitle'), style: context.type.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            preview != null
                ? t('commentator.importFound')
                : t('commentator.importLede'),
            style: context.type.body.copyWith(color: tokens.textDim),
          ),
          const SizedBox(height: AppSpacing.lg),

          // The row this game will become, shown before it becomes it.
          if (preview != null) ...[
            GameCard(game: preview, t: t, p: i18n.plural),
            const SizedBox(height: AppSpacing.md),
          ],

          // Once a game is on the table the raw text is a detail, so it folds
          // away behind a disclosure rather than dominating the sheet.
          _PgnField(
            controller: _pgn,
            collapsed: preview != null,
            hint: t('ui.placeholder.pgnInput'),
            label: t('commentator.pasteInstead'),
          ),
          // Why Import is still greyed out, right under the text it is about.
          if (problem != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                _describe(problem, t),
                style: context.type.caption.copyWith(color: errorInk),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(t('ui.button.chooseFile')),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            style: context.type.body.copyWith(color: tokens.text),
            decoration: InputDecoration(
              labelText: t('commentator.importName'),
              // A pasted move list carries no players and no event, so
              // without this it would land in the library as "Untitled".
              helperText: t('commentator.importNameHelp'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              t('ui.toast.parseFail', {'error': _error!}),
              style: context.type.caption.copyWith(color: errorInk),
            ),
          ] else if (_tooLarge) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              t('ui.toast.fileTooLarge'),
              style: context.type.caption.copyWith(color: errorInk),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t('ui.button.dismiss')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  // Dead until there is something to import, so the button
                  // never promises an error message.
                  onPressed: _checkedClipboard && preview != null
                      ? _import
                      : null,
                  child: Text(t('commentator.import')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The raw PGN box: open when there is nothing else to show, folded behind a
/// disclosure once a game has been recognised.
class _PgnField extends StatefulWidget {
  const _PgnField({
    required this.controller,
    required this.collapsed,
    required this.hint,
    required this.label,
  });

  final TextEditingController controller;
  final bool collapsed;
  final String hint;
  final String label;

  @override
  State<_PgnField> createState() => _PgnFieldState();
}

class _PgnFieldState extends State<_PgnField> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (widget.collapsed && !_open) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = true),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(widget.label),
        ),
      );
    }
    return TextField(
      controller: widget.controller,
      minLines: 5,
      maxLines: 8,
      // Notation is mono, as it is everywhere else in the app.
      style: context.type.san.copyWith(height: 1.45, color: tokens.text),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: context.type.label.copyWith(
          fontWeight: FontWeight.w400,
          color: tokens.textFaint,
        ),
      ),
    );
  }
}
