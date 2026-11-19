/// Campo de texto con etiqueta y borde, reutilizado en los formularios.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class LabeledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final bool number;
  final bool integer; // solo dígitos (sin decimales)

  const LabeledField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.number = false,
    this.integer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: integer
            ? TextInputType.number
            : number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
        inputFormatters:
            integer ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
