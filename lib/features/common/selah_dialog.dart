import 'package:flutter/material.dart';

/// A shared sheet-like presentation that preserves each dialog's route/result
/// lifecycle, including editors that dispose controllers after route completion.
class SelahDialog extends StatelessWidget {
  final Widget? title, content;
  final List<Widget>? actions;
  final EdgeInsets insetPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry contentPadding;
  const SelahDialog(
      {super.key,
      this.title,
      this.content,
      this.actions,
      this.insetPadding =
          const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      this.actionsPadding,
      this.shape,
      this.contentPadding = const EdgeInsets.fromLTRB(24, 8, 24, 24)});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final available = (media.size.height -
            media.viewInsets.bottom -
            media.padding.vertical -
            32)
        .clamp(160.0, 10000.0);
    return Dialog(
      alignment:
          media.size.width < 600 ? Alignment.bottomCenter : Alignment.center,
      insetPadding: insetPadding,
      shape: shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: colors.surface,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: 640, maxHeight: available * .92),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 10),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: colors.outlineVariant,
                            borderRadius: BorderRadius.circular(4)))),
                if (title != null)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
                      child: Row(children: [
                        Expanded(
                            child: DefaultTextStyle(
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge!
                                    .copyWith(fontFamily: 'SourceSerif4'),
                                child: title!)),
                        if (title is! Row)
                          IconButton(
                              tooltip: 'Close dialog',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded)),
                      ])),
                if (content != null)
                  Flexible(
                      child: SingleChildScrollView(
                          padding: contentPadding, child: content!)),
                if (actions != null && actions!.isNotEmpty)
                  Container(
                      padding: actionsPadding ??
                          const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: colors.outlineVariant))),
                      child: OverflowBar(
                          alignment: MainAxisAlignment.end,
                          spacing: 8,
                          overflowSpacing: 8,
                          children: actions!)),
              ])),
    );
  }
}
