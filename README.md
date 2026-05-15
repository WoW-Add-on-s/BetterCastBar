# BetterCastBar

A lightweight, customizable replacement for the default player cast bar in World of Warcraft (Retail).

## Features

- Resizable bar (width, height, font size)
- Distinct colors for casts, channels, non-interruptible spells, and failed/interrupted casts
- Spell icon (left or right) with cropped borders
- Spell name and remaining time text
- Safe zone overlay showing the spell-queue / cancel window
- Movable and lockable bar with an in-game options panel
- Saved settings per character via `BetterCastBarDB`

## Installation

1. Copy the `BetterCastBar` folder into `World of Warcraft/_retail_/Interface/AddOns/`.
2. Restart the game or type `/reload` if it is already running.
3. Make sure the addon is enabled in the character selection AddOns menu.

## Usage

Open the options panel from the standard Interface > AddOns menu, or use the slash commands.

### Slash commands

| Command        | Action                                  |
|----------------|-----------------------------------------|
| `/bcb`         | Open the options panel                  |
| `/bcb unlock`  | Unlock the bar so you can drag it       |
| `/bcb lock`    | Lock the bar in place                   |
| `/bcb test`    | Play a 3-second test cast               |
| `/bcb reset`   | Reset all settings to defaults          |

`/bettercastbar` works as an alias for `/bcb`.

## Configuration

Everything is configured from the in-game options panel:

- **Size**: width, height, text size
- **Display**: show/hide spell name, time, icon, icon side, safe zone
- **Colors**: background, cast, channel, non-interruptible, failed, text, safe zone (all with opacity)
- **Reset to defaults**: restores the original look and reloads the UI

## License

Provided as-is for personal use.
