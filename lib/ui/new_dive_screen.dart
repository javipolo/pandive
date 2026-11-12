/// Formulario de alta manual de una inmersión nueva.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/divemate_db.dart';
import '../models.dart';

class NewDiveScreen extends StatefulWidget {
  final DivemateDb db;
  const NewDiveScreen({super.key, required this.db});

  @override
  State<NewDiveScreen> createState() => _NewDiveScreenState();
}

class _NewDiveScreenState extends State<NewDiveScreen> {
  final _place = TextEditingController();
  final _country = TextEditingController();
  final _maxDepth = TextEditingController();
  final _avgDepth = TextEditingController();
  final _duration = TextEditingController();
  final _waterTemp = TextEditingController();
  final _airTemp = TextEditingController();
  final _weight = TextEditingController();
  final _buddy = TextEditingController();
  final _diveMaster = TextEditingController();
  final _diveType = TextEditingController();
  final _comments = TextEditingController();
  // Botella opcional
  final _cylSize = TextEditingController();
  final _cylStart = TextEditingController();
  final _cylEnd = TextEditingController();
  final _cylO2 = TextEditingController();

  DateTime _when = DateTime.now();
  int _rating = 0;
  bool _saving = false;
  late final int _number;

  @override
  void initState() {
    super.initState();
    _number = widget.db.nextDiveNumber();
  }

  @override
  void dispose() {
    for (final c in [
      _place, _country, _maxDepth, _avgDepth, _duration, _waterTemp,
      _airTemp, _weight, _buddy, _diveMaster, _diveType, _comments,
      _cylSize, _cylStart, _cylEnd, _cylO2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) {
    final s = c.text.trim().replaceAll(',', '.');
    return s.isEmpty ? null : double.tryParse(s);
  }

  String? _s(TextEditingController c) {
    final s = c.text.trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t?.hour ?? _when.hour,
          t?.minute ?? _when.minute);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      Cylinder? cyl;
      final size = _d(_cylSize);
      final o2 = _d(_cylO2);
      final ps = _d(_cylStart);
      final pe = _d(_cylEnd);
      if (size != null || ps != null || pe != null || o2 != null) {
        cyl = Cylinder(
            size: size, pressureStart: ps, pressureEnd: pe, o2: o2);
      }
      widget.db.createDive(
        dateTime: _when,
        number: _number,
        place: _s(_place),
        country: _s(_country),
        maxDepth: _d(_maxDepth),
        avgDepth: _d(_avgDepth),
        durationMin: _d(_duration),
        waterTemp: _d(_waterTemp),
        airTemp: _d(_airTemp),
        weight: _d(_weight),
        rating: _rating,
        buddy: _s(_buddy),
        diveMaster: _s(_diveMaster),
        diveType: _s(_diveType),
        comments: _s(_comments),
        cylinder: cyl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE d MMM yyyy, HH:mm', 'es');
    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva inmersión #$_number'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(dateFmt.format(_when)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _pickDate,
          ),
          const Divider(),
          _f(_place, 'Sitio'),
          _f(_country, 'País'),
          Row(children: [
            Expanded(child: _f(_maxDepth, 'Prof. máx (m)', num: true)),
            const SizedBox(width: 12),
            Expanded(child: _f(_avgDepth, 'Prof. media (m)', num: true)),
          ]),
          Row(children: [
            Expanded(child: _f(_duration, 'Duración (min)', num: true)),
            const SizedBox(width: 12),
            Expanded(child: _f(_weight, 'Lastre (kg)', num: true)),
          ]),
          Row(children: [
            Expanded(child: _f(_waterTemp, 'Temp. agua (°C)', num: true)),
            const SizedBox(width: 12),
            Expanded(child: _f(_airTemp, 'Temp. aire (°C)', num: true)),
          ]),
          const SizedBox(height: 8),
          _ratingSelector(),
          const SizedBox(height: 8),
          _f(_buddy, 'Compañero'),
          _f(_diveMaster, 'Guía'),
          _f(_diveType, 'Tipo de inmersión'),
          _f(_comments, 'Notas', maxLines: 4),
          const SizedBox(height: 16),
          Text('Botella (opcional)',
              style: Theme.of(context).textTheme.titleMedium),
          Row(children: [
            Expanded(child: _f(_cylSize, 'Litros', num: true)),
            const SizedBox(width: 12),
            Expanded(child: _f(_cylO2, 'O₂ %', num: true)),
          ]),
          Row(children: [
            Expanded(child: _f(_cylStart, 'Presión ini (bar)', num: true)),
            const SizedBox(width: 12),
            Expanded(child: _f(_cylEnd, 'Presión fin (bar)', num: true)),
          ]),
        ],
      ),
    );
  }

  Widget _f(TextEditingController c, String label,
      {bool num = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: num
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _ratingSelector() {
    return Row(
      children: [
        Text('Valoración', style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
        for (var i = 1; i <= 5; i++)
          IconButton(
            icon: Icon(i <= _rating ? Icons.star : Icons.star_border),
            onPressed: () => setState(() => _rating = (_rating == i) ? 0 : i),
          ),
      ],
    );
  }
}
