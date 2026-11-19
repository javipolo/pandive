/// Selector de valoración por estrellas (0-5). Tocar la misma estrella la quita.
library;

import 'package:material_ui/material_ui.dart';

class StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String label;

  const StarRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Valoración',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
        for (var i = 1; i <= 5; i++)
          IconButton(
            icon: Icon(i <= value ? Icons.star : Icons.star_border),
            onPressed: () => onChanged(value == i ? 0 : i),
          ),
      ],
    );
  }
}
