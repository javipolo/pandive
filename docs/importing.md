# Importing dives into Pandive

Where you can import from, what each source brings and how to do it.
In every case:

- **Dives are never duplicated.** Dives already in the logbook are skipped, so
  re-importing the same file adds nothing. Dives in the trash don't count as
  "already there".
- **Numbering fixes itself** if automatic numbering is on (Settings → Dive
  numbering): imported dives land in their chronological place.

## Summary

| Source | Where | Profile | Time | Site | Buddies | Duplicates by |
|---|---|---|---|---|---|---|
| Dive computer (Bluetooth) | Dives → **+** → Dive transfer (computer) | ✅ | ✅ | — | — | date + time |
| Subsurface (`.ssrf`) | Tools → Import from Subsurface | ✅ | ✅ | ✅ (with GPS) | ✅ | date + time |
| SSI / MySSI (CSV) | Tools → Import from SSI (CSV) | ❌ | only if filled in | ✅ (no GPS) | ✅ | day + depth + duration (+ time) |
| Another Pandive/DiveMate logbook (`.ddb`) | Open the `.ddb` → Import options | ✅ | ✅ | ✅ | ✅ | date + time |
| Sites (JSON) | Tools → Import sites (JSON) | — | — | ✅ | — | name (+ country) |

## Dive computer (Bluetooth)

**Dives → + button** → *Dive transfer (computer)*. Pick the computer (any
model supported by libdivecomputer), download, and tick which dives to add.
It brings the full profile, temperatures, gases and deco data. This is the
most complete source.

## Subsurface (`.ssrf`)

- **Tools → Import from Subsurface (.ssrf)** adds the dives to the current
  logbook.
- On the start screen (no logbook open), *Import from Subsurface* creates a
  new logbook with them.

It brings date and time, site (with GPS coordinates), notes, buddies, tags,
cylinders (volume, mix and pressures), maximum and average depth, temperature,
dive computer model and profile.

## SSI / MySSI (CSV)

SSI lets you export your digital logbook from its website as a CSV file.

### How to

1. On the MySSI website, open the logbook and export it to **CSV**. Save the
   file on your phone or PC.
2. In Pandive: **side menu → Tools → Import from SSI (CSV)** and pick the
   file.
3. You get the **list of dives in the CSV** to review: new ones in green
   (ticked) and in amber the ones that seem to be in your logbook already
   (unticked; tick them if they aren't, matching is approximate). Untick
   anything you don't want.
4. **Import**: a bar shows progress and when it finishes you're back on the
   dive list, with the new dives.

It works with the CSV in any language. The header comes in your SSI account's
language, but Pandive reads columns by position, not by name.

### What gets imported

| CSV column | In Pandive |
|---|---|
| Dive # | Only to order dives on the same day. The final number comes from Pandive's numbering. |
| Dive site + Country | Dive site (reused if one with that name exists; created otherwise) |
| Date / Time | Date and, if filled in on MySSI, entry time |
| Specialty dive | One tag per specialty ("Nitrox, Deep Diving" → two tags) |
| Duration | Duration |
| Depth | Maximum depth, in metres. Converted if given in feet. |
| Buddy / Instructor / Center | MySSI packs three things here: **the people** (glued together with no separator, "Ana PérezLuis Gil": they are split and each becomes a buddy), **the center** ("POSIDONIA DIVE": a tag) and **the computer** ("Puck4": the Computer field) |
| Dive activity type, Dive type | The value almost every dive has ("Diving", "Recreational dive") is ignored because it adds nothing; the rest ("Deco dive", "Extended Range", "Education") become tags |

Accepted formats: dates like `15. Apr 2026`, `3 dic. 2025`, `15.04.2026` or
`2026-04-15`, with or without time, and with month names in English, Spanish,
Catalan, Basque, French, German, Italian, Portuguese and Dutch. Duration as
`56 min`, `1 h 5 min` or `1:05`. Depth as `21 m (69 ft)` or `69 ft (21 m)`.
Separator `,` or `;`.

### What is NOT imported (not in the CSV)

The SSI CSV is a summary. Even if you fill in more data on MySSI, the export
**does not include**:

- depth or temperature profile (no chart),
- water or air temperature, visibility, current,
- cylinder, gas, pressures or weights,
- notes or comments,
- site GPS coordinates,
- instructor or center signatures.

If you want that data, add it by editing the dive. If you have the profile
elsewhere (the dive computer or Subsurface), import it from there: the SSI
dive will be detected as a duplicate.

### How duplicates are detected

Since the CSV almost never has the time, dives can't be compared by date and
time as with the other sources. A CSV row counts as **already there** if
that day has a dive with:

- similar maximum depth (±3 m), and
- similar duration (±6 min), and
- if the CSV has a time, a similar time (±90 min).

If there are several candidates, the closest one is matched. The margins were
tuned with a real export of 309 dives against a logbook of 732: two divers'
computers differ by 2–3 m and a few minutes, and the MySSI time can be ~1 h
off from the computer's (time zone). This way dives you already downloaded
from the computer aren't duplicated, and re-importing the same CSV adds
nothing.

### Time of dives with no time

Dives with no time get **12:00**, plus 1 minute for each further dive on the
same day, in SSI number order. If you already had another dive with a real
time that day, their order may be wrong: fix the time by editing the dive and
the numbering rearranges itself.

### Known limitations

- If SSI changed the column order, or changed it for some language, the import
  would read the fields wrong. So far it has only been tested with Spanish
  exports.
- Glued names are split where a lowercase letter is followed by an uppercase
  one: a surname like "McDonald" would be split in two. Fix it by editing the
  buddy.
- Telling the center from the computer depends on how MySSI places tabs in
  that cell. If that changes, one of them may end up in the wrong place.
- The SSI dive number is not kept: Pandive uses its own numbering (Settings →
  Dive numbering).
- Two dives on the same day with a nearly identical profile and no time in the
  CSV may both match the one you already had, and not be imported. If one is
  missing, create it by hand.

## Another logbook (Pandive or DiveMate `.ddb`)

Open a `.ddb` file from another app (for example from the file manager or an
attachment, with *Open with… Pandive*). It is previewed read-only, and the
**Import options** button offers:

- **Fill my dives from this logbook**: completes your dives with the profile,
  computer, cylinders and tags of the same dives in a buddy's logbook (useful
  if you dived without a computer). Also in Tools → *Fill dives from a buddy's
  logbook*.
- **Select dives to import**: copies the dives you pick, with profile, site,
  buddies, tags and cylinders. The ones you already have are flagged and
  skipped.
- **Replace my database with this one**: switches to using that file as your
  logbook.

## Sites (JSON)

**Tools → Import sites (JSON)** imports a file exported from Pandive. You can
choose to only update existing sites, or to update them and also add new ones.

To get that file:

- **All sites**: Tools → *Export sites (JSON)*.
- **Only some**: in *Sites*, long-press one to enter selection mode, tick the
  ones you want (or use *Select all*, which ticks the ones visible with the
  current search) and tap the share icon.

On the phone this opens the share sheet; on the PC, a *Save as…* dialog.
