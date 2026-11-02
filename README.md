# Card Rename

Menu bar app that renames camera cards after the reel ID found in their clip names, as soon as they are mounted.

| Card | Clips | New name |
| --- | --- | --- |
| Sony XDCAM, ARRI, Canon, DJI Ronin | `D902C001_260916JN.MXF` | `D902` |
| RED | `A003_C001_0916AB_001.R3D` | `A003` |
| Blackmagic | `A007_09161234_C001.braw` | `A007` |
| No reel ID (Sony `C0001.MP4`, DJI, GoPro, Lumix, DCIM) | | Next labroll, e.g. `A001_GOPRO`, confirmed in a dialog (see Labroll) |

Only cards still carrying a default name (UNTITLED, NO NAME, NONAME, DJI, editable in Settings) are renamed. A card with more than one reel ID is never renamed, an alert says so. Names are cut to the file system limit (FAT32 11 characters, exFAT 15).

## Menu

- **Rename cards automatically**: on/off switch. The icon is filled when on.
- **Rename cards now**: rename the cards already mounted.
- **Labroll…**: opens the Labroll window (below).
- **Recent renames**: Clips (list the card in the Labroll window) and Undo buttons while the card is mounted.
- **Settings**: default card names, ask for a name when there is no reel ID, name cards without reel ID after the labroll, eject the card after renaming, open at login, show icon in menu bar.
- **Open log**: `~/Library/Logs/CardRename.log` (same format as `rename_card.sh`).

The same panel opens in a window on first launch, and whenever the app is opened again from Applications. Useful when the menu bar icon is hidden: behind the notch on a full menu bar, switched off in System Settings > Menu Bar, or tucked away by Bartender or Ice. While this window or the Labroll window is open, Card Rename also shows in the Dock and the app switcher. The panel shows the version (e.g. `v1.1 (2)`).

Each rename posts a notification with an **Undo** button (hover the banner, or set Card Rename to "Alerts" in System Settings > Notifications to keep the button visible). After an undo, the automation leaves that card alone until it is reformatted.

The menu bar item is saved under the name `CardRename`, so menu bar managers (Ice, Bartender) list it as its own item. A manager may file it in its hidden section at first.

## Eject and reinsert after a rename

A renamed card should be ejected and inserted again before offloading:

- Finder, Spotlight and offload apps (Silverstack, ShotPut Pro, Hedge...) may keep the old name or path of the card until it is mounted again.
- Two volumes with the same name cannot share a mount point: if a card named `E003` is already mounted, macOS mounts the next `E003` as `E003 1`, and a copy can end up reading the wrong card. Card Rename warns before giving a card a name that is already mounted.

With **Eject the card after renaming** on, the card is ejected right after the rename and the notification says *Card renamed E003 and ejected. Please remove it and insert it again.* Undo then becomes available in the menu once the card is back.

## Labroll

Cameras without a reel ID (GoPro, DJI, Sony `C0001.MP4`...) get their clips renamed the Labroll Utility way:

```
GX010001.MP4  GX020001.MP4  GX010002.MP4   (shooting order, GoPro chapters kept together)
A001C001_20261102_GOPRO.MP4  A001C002_20261102_GOPRO.MP4  A001C003_20261102_GOPRO.MP4
```

- The card itself is named after the same labroll: `A001_20261102_GOPRO`, shortened to fit the label limit (`A001_261102_GOPRO`, then `A001_GOPRO`, then `A001`). The camera part is the Cam ID field, or the camera found on the card. The labroll counter then moves to `A002`. Turn this off in Settings to get the old `MODEL_YYMMDD` names.
- Once the card is ready (right after the rename, or when it is inserted again if it was ejected), its clips are listed in the **Labroll** window, with their names before and after. Nothing is copied or renamed until you click.
- **Copy + rename**: clips are copied to the destination folder under their new names, each copy read back from disk and checked with xxHash64. A log `A001_YYYY-MM-DD_HHMMSS.log` (old name, new name, hash, Labroll Utility's format) is written next to them. Existing files are never overwritten; Cancel deletes the partial copy, and the same button continues later.
- **Rename only, on the card**: clips are renamed in place. Camera indexes (Sony XML, GoPro LRF/THM) no longer match, so old and new names are kept in `~/Library/Logs/CardRename-clips.log`.
- Clips or folders can also be dropped on the window, or added with **Add clips…**. Order: creation time in the MP4/MOV header, else the file creation date, then GoPro clip and chapter. MP4, MOV, and MXF unless ignored; the date in the names is the day of the copy.

## Build

Command Line Tools are enough, no Xcode.

```bash
./build.sh            # build/Card Rename.app
./build.sh test       # naming rule tests on fake cards
./build.sh install    # copy to /Applications and open
```

The app is signed ad hoc, for this Mac only. First launch: macOS asks to allow notifications and access to removable volumes; both are needed.

## Shell script

`scripts/rename_card.sh` applies the same rules from Terminal or an Automator Quick Action, without the app:

```bash
DRY_RUN=1 bash scripts/rename_card.sh /Volumes/UNTITLED   # show what would happen
bash scripts/rename_card.sh                               # rename every card in /Volumes
bash scripts/rename_card.sh undo                          # give the last renamed card its old name back
```
