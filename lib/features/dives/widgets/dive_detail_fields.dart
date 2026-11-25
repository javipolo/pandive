/// Presentation pieces of the dive detail: compact label/value cell,
/// two-column row and section separator.
library;

import 'package:material_ui/material_ui.dart';

class LabeledValue extends StatelessWidget {
  final String label;
  final String? value;
  const LabeledValue(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          Text((value != null && value!.isNotEmpty) ? value! : '—',
              style: tt.titleMedium),
        ],
      ),
    );
  }
}

/// Two aligned columns (left | right), with configurable ratio.
Widget twoCol(Widget? a, Widget? b, {int leftFlex = 1, int rightFlex = 1}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: a ?? const SizedBox()),
        const SizedBox(width: 16),
        Expanded(flex: rightFlex, child: b ?? const SizedBox()),
      ],
    );

/// Three aligned columns (left | centre | right).
Widget threeCol(Widget? a, Widget? b, Widget? c) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a ?? const SizedBox()),
        const SizedBox(width: 16),
        Expanded(child: b ?? const SizedBox()),
        const SizedBox(width: 16),
        Expanded(child: c ?? const SizedBox()),
      ],
    );

Widget sectionLine() => const Divider(height: 20, thickness: 0.6);
