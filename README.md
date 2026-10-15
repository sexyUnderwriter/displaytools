# Display Hot Switcher

Mirror the 22-inch and 27-inch external displays without extending the desktop.

## Requirements

`displayplacer` must be installed via Homebrew. Both the script and the menu
bar app look for it at `/opt/homebrew/bin/displayplacer` (Apple Silicon
Homebrew) first, then `/usr/local/bin/displayplacer` (Intel Homebrew), then
anywhere on `PATH`.

```bash
brew install displayplacer
```

After switching Homebrew installs (for example Intel → Apple Silicon), rebuild
and reinstall the menu bar app so it picks up the new binary location.

## Menu bar app

`app/` contains a thin macOS menu bar wrapper around `setdisplay.sh`. It adds
a display icon to the menu bar; the dropdown lists the four layouts below,
check-marks the one currently active, and applies a layout with a single click
(it runs `setdisplay.sh <layout> --yes` from a copy bundled inside the app).
If a layout fails, the script's output is shown in an alert.

Build it (requires only the Xcode Command Line Tools) and install it to
`~/Applications`:

```bash
cd "/Users/arehart/useful scripts/displaytools/app"
./build.sh --install --open
```

`./build.sh` alone leaves the app in `app/build/`. The build copies
`setdisplay.sh` into the bundle, so rerun it after editing the script.
`--install` also quits any running copy, deletes every other installed copy
(for example a stale one in `/Applications`), and repoints the Login Item at
the new build, so only one version of the app can ever be in use. To have
the app start automatically, add it under System Settings → General → Login
Items.

The app resolves `displayplacer` once and passes the path to `setdisplay.sh`
via the `DISPLAYPLACER` environment variable, so the menu bar app and the
script can never disagree about which binary to run.

## Usage

Run these commands from this directory:

```bash
cd "/Users/arehart/useful scripts/displaytools"
```

Mirror both monitors, optimized for the 22-inch monitor:

```bash
./setdisplay.sh switch-to-22
```

Mirror both monitors, optimized for the 27-inch monitor:

```bash
./setdisplay.sh switch-to-27
```

`mirror-to-22` is an alias for the 22-inch-optimized layout:

```bash
./setdisplay.sh mirror-to-22
```

Restore the extended desktop, with the 27-inch monitor as the primary display
at its native 2560x1440 resolution and the 22-inch monitor as the secondary
display to its right:

```bash
./setdisplay.sh extend-to-27
```

Each command displays the monitor it will optimize for, then requires you to
type `yes`. To use a command in a trusted automation shortcut without the
confirmation prompt, add `--yes`:

```bash
./setdisplay.sh switch-to-22 --yes
./setdisplay.sh switch-to-27 --yes
./setdisplay.sh mirror-to-22 --yes
./setdisplay.sh extend-to-27 --yes
```

## Direct command

To mirror the 27-inch display to the 22-inch display (22-inch stays the main
screen) without the script (substitute `/usr/local/bin/displayplacer` on
Intel Homebrew):

```bash
/opt/homebrew/bin/displayplacer "id:1E19A853-5FD8-412A-885E-F9B67C156241+0B524B77-F683-4945-8600-2E4830D3BC30 res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0"
```

The first id in the `+` set is the main ("Optimize for") screen; the second
id is its mirror. To return to two separate extended displays (this is what
`extend-to-27` runs):

```bash
/opt/homebrew/bin/displayplacer "id:0B524B77-F683-4945-8600-2E4830D3BC30 res:2560x1440 hz:144 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0" "id:1E19A853-5FD8-412A-885E-F9B67C156241 res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(2560,360) degree:0"
```

If the 27-inch display rejects 144 Hz over its current cable, replace
`hz:144` with `hz:60`.

## Safety

Each mirror command is applied as a single atomic displayplacer profile at
1920x1080, the native resolution of the 22-inch monitor, so both screens show
the same image. `extend-to-27` applies both displays' native profiles in one
call. No display is ever disconnected or disabled.

If macOS cannot restore a display, reconnect its cable or switch its physical
input back to this Mac, then rerun the command.

The script cannot change the monitor's physical input port. Use the monitor's
input button, auto-input switching, or a DDC utility configured for that
monitor to show the other computer.

Show the built-in command summary with:

```bash
./setdisplay.sh --help
```