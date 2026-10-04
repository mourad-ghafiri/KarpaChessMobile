import 'package:flutter/material.dart';

import '../../../core/i18n/i18n_service.dart';
import '../../../core/theme/tokens_context.dart';

/// Text-entry dialog shared by the drawing overlay (create / tap-to-edit)
/// and the drawing-mode bar's edit button.
Future<String?> showDrawTextDialog(
  BuildContext context,
  Translate t, {
  String initial = '',
}) async {
  final input = TextEditingController(text: initial);
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      // Hosts a TextField: the keyboard leaves little room on a
      // landscape phone, so the content scrolls rather than overflows.
      scrollable: true,
      title: Text(t('commentator.drawTools.text')),
      content: TextField(
        controller: input,
        autofocus: true,
        maxLength: 40,
        style: context.type.body,
        decoration: InputDecoration(
          hintText: t('ui.placeholder.drawText'),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('ui.button.dismiss')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(input.text),
          child: Text(t('ui.button.save')),
        ),
      ],
    ),
  );
  input.dispose();
  return text;
}
