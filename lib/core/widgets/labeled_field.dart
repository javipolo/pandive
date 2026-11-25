/// Labelled, bordered text field, reused in the forms.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class LabeledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final bool number;
  final bool integer; // digits only (no decimals)
  final bool signed; // allows negatives (e.g. coordinates)

  const LabeledField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.number = false,
    this.integer = false,
    this.signed = false,
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
                ? TextInputType.numberWithOptions(decimal: true, signed: signed)
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
