/// Rellena datos de buceos propios con los de un compañero (ya emparejados):
/// selección estilo lista de buceos + buddy a añadir + confirmación.
library;

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/loading_dialog.dart';
import 'package:pandive/features/settings/logic/enrich_logbook.dart';
import 'package:pandive/features/settings/widgets/fill_dive_checklist.dart';
import 'package:pandive/l10n/app_localizations.dart';
Future<void> openFillFromDdb(BuildContext context, DivemateDb db,
    {String? sourcePath}) async {
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  final t = AppLocalizations.of(context);
  var path = sourcePath;
  if (path == null) {
    final res = await FilePicker.platform.pickFiles(withData: false);
    path = res?.files.single.path;
  }
  if (path == null || !context.mounted) return;
  showLoadingDialog(context, t.readingDdb);
  await WidgetsBinding.instance.endOfFrame;
  try {
    final dir = await getTemporaryDirectory();
    final tmp = File('${dir.path}/source.ddb');
    await File(path).copy(tmp.path);
    final source = DivemateDb.open(tmp.path, readOnly: true);
    if (!source.looksValid) {
      source.close();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(t.invalidDb)));
      return;
    }
    final r = await computeMatches(db, source);
    source.close();
    nav.pop(); // cerrar spinner
    if (r.dives.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(t.noMatches)));
      return;
    }
    nav.push(MaterialPageRoute(
        builder: (_) =>
            FillFromDdbScreen(db: db, dives: r.dives, matches: r.matches)));
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(t.errorLoad('$e'))));
  }
}
class FillFromDdbScreen extends StatefulWidget {
  final DivemateDb db;
  final List<Dive> dives; // buceos propios con coincidencia
  final Map<int, DiveMatch> matches;
  const FillFromDdbScreen(
      {super.key, required this.db, required this.dives, required this.matches});
  @override
  State<FillFromDdbScreen> createState() => _FillFromDdbScreenState();
}
class _FillFromDdbScreenState extends State<FillFromDdbScreen> {
  final _buddy = TextEditingController();
  final _selected = <int>{}; // índices en widget.dives
  @override
  void dispose() {
    _buddy.dispose();
    super.dispose();
  }

  void _toggle(int i) => setState(
      () => _selected.contains(i) ? _selected.remove(i) : _selected.add(i));

  void _toggleGroup(List<int> idx) => setState(() {
        if (idx.every(_selected.contains)) {
          _selected.removeAll(idx);
        } else {
          _selected.addAll(idx);
        }
      });

  void _toggleAll() => setState(() {
        if (_selected.length == widget.dives.length) {
          _selected.clear();
        } else {
          _selected.addAll(List.generate(widget.dives.length, (i) => i));
        }
      });

  Future<void> _apply() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDialog(context, t.fillConfirm(_selected.length),
        confirmLabel: t.fillAction)) {
      return;
    }
    final ids = {for (final i in _selected) widget.dives[i].id};
    final n = applyEnrich(widget.db, widget.matches, ids, _buddy.text);
    if (!mounted) return;
    bumpDataRevision(); // refresca las pestañas (misma DB abierta)
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(t.fillResult(n))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final n = _selected.length;
    return Scaffold(
      appBar: AppBar(title: Text(t.fillFromDdb)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _buddy,
            decoration: InputDecoration(
                labelText: t.buddyToAdd, border: const OutlineInputBorder()),
          ),
        ),
        CheckboxListTile(
          value: n == 0 ? false : (n == widget.dives.length ? true : null),
          tristate: true,
          onChanged: (_) => _toggleAll(),
          title: Text(t.selectAll),
        ),
        const Divider(height: 1),
        Expanded(
          child: FillDiveChecklist(
            dives: widget.dives,
            matches: widget.matches,
            selected: _selected,
            onToggle: _toggle,
            onToggleGroup: _toggleGroup,
          ),
        ),
      ]),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          icon: const Icon(Icons.group_add_outlined),
          label: Text('${t.fillAction} ($n)'),
          onPressed: n == 0 ? null : _apply,
        ),
      ),
    );
  }
}
