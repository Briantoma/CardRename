# Card Rename

Menu bar app that renames camera cards after the reel ID found in their clip names, as soon as they are mounted.

| Card | Clips | New name |
| --- | --- | --- |
| Sony XDCAM, ARRI, Canon, DJI Ronin | `D902C001_260916JN.MXF` | `D902` |
| RED | `A003_C001_0916AB_001.R3D` | `A003` |
| Blackmagic | `A007_09161234_C001.braw` | `A007` |
| No reel ID (Sony `C0001.MP4`, DJI, GoPro, Lumix, DCIM) | | `MODEL_YYMMDD`, e.g. `FX3_260915`, confirmed in a dialog |

Only cards still carrying a default name (UNTITLED, NO NAME, NONAME, DJI, editable in Settings) are renamed. A card with more than one reel ID is never renamed, an alert says so. Names are cut to the file system limit (FAT32 11 characters, exFAT 15).

## Menu

- **Rename cards automatically**: on/off switch. The icon is filled when on.
- **Rename cards now**: rename the cards already mounted.
- **Recent renames**: Undo button while the card is mounted.
- **Settings**: default card names, ask for a name when there is no reel ID, open at login, show icon in menu bar.
- **Open log**: `~/Library/Logs/CardRename.log` (same format as `rename_card.sh`).

The same panel opens in a window on first launch, and whenever the app is opened again from Applications. Useful when the menu bar icon is hidden: behind the notch on a full menu bar, switched off in System Settings > Menu Bar, or tucked away by Bartender or Ice.

Each rename posts a notification with an **Undo** button (hover the banner, or set Card Rename to "Alerts" in System Settings > Notifications to keep the button visible). After an undo, the automation leaves that card alone until it is reformatted.

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
