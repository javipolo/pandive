/// Previews a .ddb read-only (dive list) without touching the active
/// DB. The "Use DDB" floating button offers: fill in, import dives or
/// replace the database.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/dives/widgets/month_grouped_dives.dart';
import 'package:pandive/features/settings/screens/import_ddb_dives_screen.dart';
import 'package:pandive/features/settings/screens/fill_from_ddb_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PreviewDdbScreen extends StatefulWidget {
  final String path;
  final Settings settings;
  final DivemateDb db; // active database (for filling in)
  final void Function(String path) onReplace;
  const PreviewDdbScreen({
    super.key,
    required this.path,
    required this.settings,
    required this.db,
    required this.onReplace,
  });

  @override
  State<PreviewDdbScreen> createState() => _PreviewDdbScreenState();
}

class _PreviewDdbScreenState extends State<PreviewDdbScreen> {
  DivemateDb? _preview;
  List<Dive> _dives = const [];
  Set<int> _cave = const {};

  @override
  void initState() {
    super.initState();
    try {
      final db = DivemateDb.open(widget.path, readOnly: true);
      if (db.looksValid) {
        _preview = db;
        _dives = db.listDives();
        _cave = db.diveIdsWithTag('cave');
      } else {
        db.close();
      }
    } catch (_) {/* invalid file */}
  }

  @override
  void dispose() {
    _preview?.close();
    super.dispose();
  }

  Future<void> _useThis() async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.replaceDbConfirm,
        confirmLabel: t.replaceDb)) {
      return;
    }
    widget.onReplace(widget.path);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _importDives() async {
    final src = _preview;
    if (src == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ImportDdbDivesScreen(target: widget.db, source: src)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final ok = _preview != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.previewDdb),
        backgroundColor: cs.error,
        foregroundColor: cs.onError,
      ),
      body: !ok
          ? Center(child: Text(t.invalidDb))
          : _dives.isEmpty
              ? Center(child: Text(t.noResults))
              : MonthGroupedDives(
                  dives: _dives,
                  settings: widget.settings,
                  caveIds: _cave,
                  onOpen: (_) {}),
      floatingActionButton: !ok ? null : _useDdbMenu(t),
    );
  }

  /// "Use DDB" floating button that unfolds the three actions.
  Widget _useDdbMenu(AppLocalizations t) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.group_add_outlined),
          onPressed: () =>
              openFillFromDdb(context, widget.db, sourcePath: widget.path),
          child: Text(t.useDdbFill),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.playlist_add),
          onPressed: _dives.isEmpty ? null : _importDives,
          child: Text(t.useDdbImport),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.swap_horiz),
          onPressed: _useThis,
          child: Text(t.useDdbReplace),
        ),
      ],
      builder: (context, ctrl, _) => FloatingActionButton.extended(
        onPressed: () => ctrl.isOpen ? ctrl.close() : ctrl.open(),
        icon: const Icon(Icons.more_vert),
        label: Text(t.useDdb),
      ),
    );
  }
}
