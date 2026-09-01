import 'package:flutter/material.dart';

/// A section heading: sentence case, no letter-spacing, announced as a
/// heading to screen readers.
///
/// Replaces the `toUpperCase()` + tracked-caps labels (audit mind-in-mind-10,
/// visual-display-15: capitals read slower and letter-spacing removes what
/// is left of word shape) and adds the header semantics they lacked
/// (mind-in-mind-09). [color] defaults to the theme's secondary text colour;
/// the forecast passes its sky ink.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
