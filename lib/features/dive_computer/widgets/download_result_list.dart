/// Selectable list of dives to import (new + pending). Manages its
/// own selection and lets you choose which to save and tick/untick all.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dive_computer/widgets/downloaded_dive_tile.dart';
import 'package:pandive/l10n/app_localizations.dart';

typedef DownloadItem = ({DownloadedDive dive, bool pending});

class DownloadResultList extends StatefulWidget {
  final List<DownloadItem> items;
  final Set<String> initialSelected; // fingerprints ticked by default
  final int existing; // already in the DB (for the summary)
  final bool saving;
  final ValueChanged<Set<String>> onSave;

  const DownloadResultList({
    super.key,
    required this.items,
    required this.initialSelected,
    required this.existing,
    required this.saving,
    required this.onSave,
  });

  @override
  State<DownloadResultList> createState() => _DownloadResultListState();
}

class _DownloadResultListState extends State<DownloadResultList> {
  late final Set<String> _sel = {...widget.initialSelected};

  void _toggle(String fp) =>
      setState(() => _sel.contains(fp) ? _sel.remove(fp) : _sel.add(fp));

  void _toggleAll() => setState(() {
        final all = _sel.length == widget.items.length;
        _sel.clear();
        if (!all) _sel.addAll(widget.items.map((e) => e.dive.fingerprint));
      });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final items = widget.items;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.allAlreadyInDb(widget.existing),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // Allows saving 0: discards the unchosen ones at once and advances the
        // fingerprint, even if you save none. (Back changes nothing.)
        onPressed: widget.saving ? null : () => widget.onSave(_sel),
        icon: const Icon(Icons.save),
        label: Text(widget.saving ? t.saving : t.saveN(_sel.length)),
      ),
      body: Column(
        children: [
          CheckboxListTile(
            value: _sel.length == items.length,
            tristate: true,
            onChanged: (_) => _toggleAll(),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(t.selectAll),
            subtitle: Text(t.downloadedSummary(
                items.length + widget.existing, items.length, widget.existing)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => DownloadedDiveTile(
                dive: items[i].dive,
                pending: items[i].pending,
                selected: _sel.contains(items[i].dive.fingerprint),
                onChanged: (_) => _toggle(items[i].dive.fingerprint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
