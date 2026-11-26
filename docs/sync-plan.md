# Plan: phone ↔ PC sync via Google Drive

Status: **layer 1 implemented** (2026-11-24: `sync_logic.dart`,
`sync_controller.dart`, `drive_sync_ops.dart`). Implementation details:
"the other side changed" is measured with the md5 of `sync-logbook.ddb.gz`
(gzip) on Drive (not the revision); the upload is a `VACUUM INTO` snapshot; a
new, empty device adopts Drive without asking. Layer 2 (merge) pending. See
"Recommended proposal" at the end.

## Goal

Use Pandive on the phone and on the PC with the same data. Changes must be
copied from one to the other and, if both are edited at once (even offline),
no data may be corrupted or lost. No server of our own: the exchange goes
through the Google Drive we already use for backups.

## What we already have

- DiveMate tables (Logbook, Place, Buddy, Tank, Divetype…) with `UUID` and
  `Updated` per row → stable identity across devices and a timestamp.
- Soft deletion of dives (`Status=2`): syncs well.
- Drive integration with headless auth, rotating backups (10) and a periodic
  worker.

## What's missing

- `Pandive*` tables (tags, trips, documents, dive types, presets, …) have no
  UUID.
- Hard deletes (`DELETE FROM Buddy/Place/PandiveTag/…`).
- Integer autoincrement `ID`s assigned locally → two simultaneous inserts can
  collide.
- Not every write updates `Updated` (to review).

## Why a version number is not enough

A version (or Drive's `headRevisionId`) answers "has anyone changed the file
since my last sync?". That solves the common case for free (only one side
changed → upload or download the whole file). If **both** changed, it only
detects the conflict; resolving it requires merging.

## Design: per-row three-way merge, Drive as source of truth

1. **Shared file** `pandive-sync.ddb` in the Drive folder (separate from the
   backups).
2. **Local base**: each device keeps a copy of the last version it synced +
   its `headRevisionId`.
3. **Sync**:
   - Drive is still at my base revision → upload mine (if I changed anything).
   - I changed nothing since the base → download Drive's and adopt it.
   - Both changed → three-way merge (base, local, remote), table by table, row
     by row by UUID:
     - Row changed on one side only → that side wins (including hard deletes:
       it was in the base and is gone).
     - Changed on both → per-column merge; if they clash on the same column,
       the most recent `Updated` wins.
     - Deleted on one side and edited on the other → the edit wins (cautious).
     - New row on both sides with the same `ID` → renumber the incoming one and
       rewrite its references (`PlaceID`, `BuddyIDs`, tags, cylinders…). Dive
       numbers recomputed by date.
   - Before uploading, check again that Drive is still at the same revision;
     if someone uploaded in between, merge again. Upload to a temp file and
     replace (never a half-written file).
4. **Safety**: automatic backup before applying any merge (the 10-backup
   rotation already exists).
5. **When**: on opening/returning to the app, a few seconds after editing
   (debounce), manual button and periodic worker. No network, no problem: it
   merges later.
6. **Summary** after sync: "3 changes downloaded, 1 uploaded, 1 conflict
   resolved (view)".

Document images: separately, one file per document in a Drive folder,
compared by name + hash.

## Prerequisite work

- `UUID` column in the `Pandive*` tables (they're ours; doesn't break
  DiveMate). Join tables (`PandiveDiveTag`, `PandiveSiteTag`,
  `PandiveTripBuddy`…) are merged as sets of UUID pairs.
- Every write updates `Updated`.
- Explicit foreign-key map (used by merge and renumbering).
- Merge engine as pure logic over SQLite, tested on the host with temp copies
  (like the current tests).

## Proposed phases

1. Schema prerequisites (UUID in `Pandive*`, `Updated` always, FK map).
2. Three-way merge engine + exhaustive tests (no Drive).
3. Phone ↔ Drive sync (fast-forward + merge + summary), manual button.
4. Automatic triggers (start, debounce, worker).
5. Linux app against the same Drive.

## Discarded

- **Lock file on Drive**: if the phone goes offline holding the lock, the PC
  is blocked; it doesn't solve offline work (boat, island).
- **Operation journal**: finer-grained but much more complex (triggers, replay
  order) and no real advantage for one diver with two devices.

## Open decisions

1. Clash on the same field: most recent wins, or ask?
2. Automatic sync from the start, or manual only at first?
3. Start with phone ↔ Drive and leave the PC until the Linux app is ready?

## Recommended proposal (2026-11-24)

Two layers: first a sync that **never loses data** (no merge), then automatic
merging so the rare case isn't a bother either.

### Layer 1: fast-forward sync + divergence detection

Per-device state (local, not in the DB): `baseRevision` (Drive revision at
the last sync) and `baseStamp` (local `lastWriteUtc` at that moment).

- **Did I change?** local `lastWriteUtc > baseStamp` (exact thanks to the
  triggers: any write counts).
- **Did the other change?** `headRevisionId` of `sync/pandive.ddb` on Drive ≠
  `baseRevision`.

| me | other | action |
|----|-------|--------|
| no | no | nothing |
| yes | no | upload (and recheck the revision right before uploading) |
| no | yes | download and replace the local one (with a backup first) |
| yes | yes | **divergence**: nothing is touched automatically |

On divergence: notice "There are changes on the phone and on this computer"
with *keep this one* / *keep the other one*. The discarded version is not
deleted: it goes to the timestamped backups (recoverable). Layer 2 adds
*merge*.

When: on opening and returning to the app, a few seconds after editing
(debounce), when going to the background, and with a button. Indicator in the
top bar: ✓ synced · ↑ uploading · ↓ downloading · ⚠ divergence · ⌀ offline.

**Simultaneous use notice** (not a lock): each device writes a small
`presence.json` (device + time) to Drive while open. If the other sees a
recent one: "Pandive is open on the phone (2 min ago)". Avoids most
divergences without blocking anyone offline.

Cost: small (reuses backup auth/upload). Guarantee: no edit is lost without
the user deciding so.

### Layer 2: three-way merge

The one in "Design" above (per row/UUID, per column, edit beats delete,
renumber IDs). Needs the schema prerequisites. The merge base is the local
copy saved at the last sync (add it in layer 1 from the start so it is
available).

### Proposed answers to the open decisions

1. Clash on the same field: most recent wins, and it is listed in the summary.
2. Layer 1 automatic from the start (it is safe by design); manual merge
   ("Merge") until layer 2 has many hours of testing.
3. Phone and Linux at once: Google login already works on both.
