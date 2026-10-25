# Fix Steam Icons

A single-file Windows tool that restores missing icons on Steam game shortcuts.

## The problem

When you reinstall Windows, or move your Steam library to a new PC or external drive, the desktop shortcuts Steam creates often show a blank, generic icon instead of the game's artwork.

This happens because Steam shortcuts are `.url` files, and each one points to an icon stored in Steam's install folder:

```
C:\Program Files (x86)\Steam\steam\games\<hash>.ico
```

On a fresh install, those `.ico` files don't exist yet, so Windows has nothing to display.

## What it does

`Fix-SteamIcons.bat` scans your Steam shortcuts and, for each one with a missing icon:

1. Reads the game's App ID and icon filename from the shortcut
2. Downloads the icon from Steam's CDN
3. Saves it in your Steam install's `steam\games` folder
4. Repoints the shortcut if it was looking at an old drive or location
5. Refreshes the Windows icon cache so the new icons appear

Shortcuts that already have working icons are left alone, so it's safe to run as many times as you like.

### Where it looks

- Your desktop
- The shared (Public) desktop
- The `Steam` folder in your Start Menu (per-user and all-users)

## Usage

1. Download `Fix-SteamIcons.bat`
2. Double-click it
3. Approve the admin prompt. This is required because Steam's icon folder is inside Program Files.
4. Wait for the summary, then press Enter to close

```
Steam folder: C:\Program Files (x86)\Steam
Icon folder:  C:\Program Files (x86)\Steam\steam\games

Fixing Hades (app 1145360)... done
Fixing Stardew Valley (app 413150)... done

----------------------------------------
Fixed:             2
Already had icons: 5
----------------------------------------
```

If some icons still look blank afterward, press **F5** on the desktop or sign out and back in.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (built into Windows)
- Steam installed
- An internet connection

## Troubleshooting

| Issue | Fix |
|---|---|
| Windows SmartScreen blocks it | Click **More info**, then **Run anyway** |
| "Shortcut has no icon info" | Delete the shortcut and recreate it from Steam (right-click the game, then **Manage** > **Add desktop shortcut**) |
| "Icon not found on Steam's servers" | The game may be delisted, or its icon may have changed. Recreating the shortcut from Steam usually fixes this. |
| Fixed shortcuts on the wrong desktop | If you approve the admin prompt with a *different* Windows account, the script will check that account's desktop instead. Run it from an account that is already an administrator. |

## How it works

The `.bat` file is a batch/PowerShell hybrid. The top of the file is a small batch launcher that requests admin rights and then feeds the rest of the file to PowerShell. PowerShell treats the batch section as a comment block. This lets the whole tool ship as one double-clickable file, with no separate `.ps1` file and no execution-policy changes needed.

Icons are downloaded from:

```
https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/<appid>/<hash>.ico
```

with Akamai and the legacy Steam CDN as fallbacks.

## Disclaimer

This is an unofficial tool. It is not affiliated with or endorsed by Valve or Steam. It only reads and edits `.url` shortcut files and downloads public icon images. It doesn't touch your games or your Steam installation otherwise.

## License

MIT
