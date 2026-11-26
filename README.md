# Pandive 🐼🤿

A dive logbook for Android and Linux. Download your dives straight from your
dive computer over Bluetooth, keep them in a single file you own, and back it
up to your own Google Drive.

Pandive uses the same database format as **DiveMate** (`.ddb`), so you can open
an existing DiveMate logbook as is: no conversion needed.

## Features

- **Download from your dive computer** over Bluetooth LE: any model supported
  by [libdivecomputer](https://www.libdivecomputer.org/) (tested with
  Shearwater Peregrine/Perdix, Mares Puck 4 and Heinrichs Weikamp OSTC).
- **Full dive detail**: depth and temperature profile, gases, deco, cylinders
  and SAC.
- **Organize**: dive sites (with map), buddies, tags, trips, dive types and
  cylinder presets, search and filters.
- **Statistics** and personal records, overall or for any selection of dives.
- **Gas planner** for a quick "how much gas do I need" check.
- **Documents**: keep your certification cards and insurance with expiry
  reminders.
- **Import** from Subsurface (`.ssrf`), the SSI / MySSI CSV export and other
  DiveMate/Pandive logbooks; **export** to Subsurface, DiveMate (`.ddb`) and
  JSON (sites). See [what each source brings](docs/importing.md).
- **Google Drive backup** (automatic, also in the background) and **sync
  between phone and PC**, without ever silently losing data.
- Large text by default, adjustable. Available in English, Spanish, Catalan,
  Basque and French.
- No photos, no account, no servers: your logbook is a single SQLite file.

## Install

### Android

Download the APK from the [Releases](https://github.com/javipolo/pandive/releases)
page and install it (you may need to allow installing apps from unknown
sources). Android 7.0 or newer.

### Linux

There are no prebuilt packages yet: build it from source following the
[development guide](docs/DEVELOPMENT.md), then `make install-linux`.

Downloading from a dive computer uses the system Bluetooth (BlueZ); no root
needed. Usually no pairing is required. If a model needs it and the
connection fails, pair it once by hand:

```bash
bluetoothctl
[bluetooth]# scan le                   # put the computer in Bluetooth mode
[bluetooth]# pair AA:BB:CC:DD:EE:FF    # enter the PIN shown on the computer
[bluetooth]# trust AA:BB:CC:DD:EE:FF
[bluetooth]# quit
```

## Getting started

1. On first launch Pandive creates an empty logbook. You can instead open an
   existing DiveMate `.ddb` or import a Subsurface file.
2. **Dives → +** → *Dive transfer (computer)* to scan for your dive computer and
   download new dives.
3. **Menu → Backup** to connect your Google account. Backups go to a
   "Pandive Backups" folder; Pandive only sees the files it creates there.
   Turn on *Sync between devices* on each device to share the logbook between
   phone and PC.

> If connecting Google fails on Android with "No stored state" or "User
> cancelled", your default browser (e.g. Brave) is losing the login redirect:
> use Chrome for that one step.

## Contributing

Bug reports and pull requests are welcome. To build Pandive or hack on it, see
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
