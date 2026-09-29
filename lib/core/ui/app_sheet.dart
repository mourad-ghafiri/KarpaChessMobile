import 'package:flutter/material.dart';

import '../layout/content_width.dart';

/// The app's one modal sheet.
///
/// Every sheet used to configure itself, and none of them survived a
/// landscape phone: without `isScrollControlled` Material caps a sheet at
/// 9/16 of the viewport — about 180dp on a 320dp-tall window — and without a
/// scroll view the content simply overflows instead of scrolling. The result
/// was end-of-game buttons, and both actions of the pattern sheet, sitting
/// below the fold with no way to reach them.
///
/// This presenter gives every sheet the same three guarantees: it may use
/// the full height, it scrolls when it needs to, and it stops widening on a
/// desktop window.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: ContentWidth.form),
    builder: (context) => _SheetBody(child: builder(context)),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.child});

  /// How much of the safe viewport a sheet may fill before it scrolls.
  static const _heightFraction = 0.92;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeHeight = media.size.height - media.viewPadding.vertical;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: safeHeight * _heightFraction),
      child: SingleChildScrollView(
        // Keeps content clear of the keyboard when a sheet hosts a field.
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: child,
      ),
    );
  }
}
