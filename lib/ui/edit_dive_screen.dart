/// Formulario de edición de los campos editables de una inmersión.
library;

import 'package:flutter/material.dart';

import '../db/divemate_db.dart';
import '../models.dart';

class EditDiveScreen extends StatefulWidget {
  final DivemateDb db;
  final Dive dive;

  const EditDiveScreen({super.key, required this.db, required this.dive});

  @override
  State<EditDiveScreen> createState() => _EditDiveScreenState();
}

class _EditDiveScreenState extends State<EditDiveScreen> {
  late final TextEditingController _place;
  late final TextEditingController _country;
  late final TextEditingController _buddy;
  late final TextEditingController _diveMaster;
  late final TextEditingController _diveType;
  late final TextEditingController _weight;
  late final TextEditingController _comments;
  late int _rating;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dive;
    _place = TextEditingController(text: d.place ?? '');
    _country = TextEditingController(text: d.country ?? '');
    _buddy = TextEditingController(text: d.buddy ?? '');
    _diveMaster = TextEditingController(text: d.diveMaster ?? '');
    _diveType = TextEditingController(text: d.diveType ?? '');
    _weight =
        TextEditingController(text: d.weight != null ? '${d.weight}' : '');
    _comments = TextEditingController(text: d.comments ?? '');
    _rating = d.rating ?? 0;
  }

  @override
  void dispose() {
    for (final c in [
      _place, _country, _buddy, _diveMaster, _diveType, _weight, _comments,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _textOrNull(TextEditingController c) {
    final s = c.text.trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final weightText = _weight.text.trim().replaceAll(',', '.');
      widget.db.updateDive(widget.dive.id, {
        'Place': _textOrNull(_place),
        'Country': _textOrNull(_country),
        'Buddy': _textOrNull(_buddy),
        'Divemaster': _textOrNull(_diveMaster),
        'Divetype': _textOrNull(_diveType),
        'Comments': _textOrNull(_comments),
        'Rating': _rating,
        'Weight': weightText.isEmpty ? null : double.tryParse(weightText),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dive.number != null
            ? 'Editar #${widget.dive.number}'
            : 'Editar inmersión'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_place, 'Sitio'),
          _field(_country, 'País'),
          const SizedBox(height: 8),
          _ratingSelector(),
          const SizedBox(height: 8),
          _field(_buddy, 'Compañero'),
          _field(_diveMaster, 'Guía'),
          _field(_diveType, 'Tipo de inmersión'),
          _field(_weight, 'Lastre (kg)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
          _field(_comments, 'Notas', maxLines: 5),
          const SizedBox(height: 16),
          Text(
            'Solo se editan estos campos. Profundidad, tiempo y perfil vienen '
            'del ordenador de buceo y no se tocan a mano.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _ratingSelector() {
    return Row(
      children: [
        Text('Valoración', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(width: 12),
        for (var i = 1; i <= 5; i++)
          IconButton(
            icon: Icon(i <= _rating ? Icons.star : Icons.star_border),
            onPressed: () => setState(() => _rating = (_rating == i) ? 0 : i),
          ),
      ],
    );
  }
}
